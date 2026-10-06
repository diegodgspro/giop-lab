import hashlib
import json
import os
import threading
import time
from collections import OrderedDict
from pathlib import Path
from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from giop_ai_contract import IncidentAnalysisContext, AnalysisOutput
from .providers import FixtureProvider, OllamaProvider

PROMPT = (Path(__file__).resolve().parents[1] / 'prompts/incident-analysis-v1.txt').read_text(encoding='utf-8')


def create_app(provider=None):
    configured = os.getenv('AI_PROVIDER', 'ollama')
    if provider is None:
        try:
            if configured == 'fixture' and os.getenv('AI_FIXTURE_ENABLED') == 'true':
                provider = FixtureProvider()
            elif configured == 'ollama':
                provider = OllamaProvider(os.getenv('OLLAMA_URL', 'http://host.docker.internal:11434'), os.getenv('OLLAMA_MODEL', ''))
        except ValueError:
            provider = None
    app = FastAPI(title='GIOP read-only incident analysis', docs_url=None, redoc_url=None, openapi_url=None)
    cache, lock = OrderedDict(), threading.Lock()

    @app.exception_handler(RequestValidationError)
    async def invalid_context(request, exc):
        return JSONResponse(status_code=422, content={'status': 'AI_CONTEXT_INVALID'})

    @app.middleware('http')
    async def bounded_request(request: Request, call_next):
        if request.method == 'POST':
            data = await request.body()
            if len(data) > 32768:
                return JSONResponse(status_code=413, content={'status': 'AI_CONTEXT_INVALID'})
        response = await call_next(request)
        response.headers['Cache-Control'] = 'no-store'
        return response

    @app.get('/health')
    def health():
        return {'status': 'ok', 'read_only': True, 'synthetic': True,
                'provider': provider.name if provider else configured,
                'configured': provider is not None, 'fixture': bool(provider and provider.name == 'fixture')}

    @app.post('/api/v1/analyze')
    def analyze(context: IncidentAnalysisContext):
        canonical = json.dumps(context.model_dump(), sort_keys=True, separators=(',', ':'))
        stable_id = hashlib.sha256((PROMPT + getattr(provider, 'name', configured) + getattr(provider, 'model', '') + canonical).encode()).hexdigest()
        base = {'analysis_id': stable_id, 'read_only': True, 'environment': 'SYNTHETIC LAB',
                'provider': getattr(provider, 'name', configured), 'fixture': bool(provider and provider.name == 'fixture')}
        # One in-flight model call per service; repeated explicit requests share the result.
        with lock:
            if stable_id in cache:
                created, result = cache[stable_id]
                if time.monotonic() - created < 3600:
                    cache.move_to_end(stable_id)
                    return {**result, 'cached': True}
                del cache[stable_id]
            if not any(f.id in ('zabbix_problem', 'pilot_tcp') for f in context.facts):
                return {**base, 'status': 'INSUFFICIENT_EVIDENCE'}
            if provider is None:
                return {**base, 'status': 'AI_UNAVAILABLE'}
            try:
                raw = provider.analyze(context, PROMPT)
            except ValueError:
                return {**base, 'status': 'AI_ANALYSIS_INVALID'}
            except Exception:
                return {**base, 'status': 'AI_UNAVAILABLE'}
            try:
                if not isinstance(raw, str) or len(raw) > 16000:
                    raise ValueError('Invalid response')
                analysis = AnalysisOutput.model_validate_json(raw).verify(context)
            except Exception:
                return {**base, 'status': 'AI_ANALYSIS_INVALID'}
            result = {**base, 'status': 'SUCCESS', 'model': provider.model, 'cached': False,
                      'incident_id': context.incident.ticket_id, 'episode_state': context.integration.state,
                      'ci': context.ci.model_dump(),
                      'analysis': analysis.model_dump(),
                      'observed': [{'id': f.id, 'statement': f.statement, 'source': f.source, 'window': f.window, 'observed_at': f.observed_at} for f in context.facts if f.id in analysis.observed_evidence]}
            cache[stable_id] = (time.monotonic(), result)
            while len(cache) > 128:
                cache.popitem(last=False)
            return result

    @app.get('/api/v1/analysis/{stable_id}')
    def saved(stable_id: str):
        with lock:
            entry = cache.get(stable_id)
            if not entry or time.monotonic() - entry[0] >= 3600:
                return JSONResponse(status_code=404, content={'status': 'ANALYSIS_NOT_FOUND'})
            return {**entry[1], 'cached': True}

    return app


app = create_app()
