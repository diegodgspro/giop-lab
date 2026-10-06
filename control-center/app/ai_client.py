"""Computation-only AI client; isolated from the existing read-source aggregation."""
import os
import re
from urllib.parse import urlsplit
import httpx
from giop_ai_contract import AnalysisOutput, sanitize_text


class AIClient:
    def __init__(self, transport=None):
        self.transport = transport
        self.url = os.getenv('CC_AI_URL', 'http://ai-assistant:8092')

    def analyze(self, context):
        try:
            url = urlsplit(self.url)
            if url.scheme != 'http' or url.hostname not in ('ai-assistant', '127.0.0.1', 'localhost') or url.port != 8092 or url.username or url.password or url.query or url.fragment or url.path not in ('', '/'):
                raise ValueError('Only the internal AI computation endpoint is permitted')
            with httpx.Client(timeout=50, trust_env=False, follow_redirects=False, transport=self.transport) as client:
                with client.stream('POST', self.url.rstrip('/') + '/api/v1/analyze', json=context.model_dump()) as response:
                    response.raise_for_status()
                    payload = bytearray()
                    for chunk in response.iter_bytes():
                        payload.extend(chunk)
                        if len(payload) > 32768:
                            return {'status': 'AI_ANALYSIS_INVALID'}
                    import json
                    data = json.loads(payload)
        except Exception:
            return {'status': 'AI_UNAVAILABLE'}
        if not isinstance(data, dict):
            return {'status': 'AI_ANALYSIS_INVALID'}
        if data.get('status') in ('AI_UNAVAILABLE', 'AI_ANALYSIS_INVALID', 'INSUFFICIENT_EVIDENCE', 'AI_CONTEXT_INVALID'):
            return {'status': data['status']}
        try:
            analysis = AnalysisOutput.model_validate(data['analysis']).verify(context)
            if data['status'] != 'SUCCESS' or data['incident_id'] != context.incident.ticket_id or data.get('provider') not in ('fixture', 'ollama') or not re.fullmatch('[0-9a-f]{64}', data['analysis_id']):
                raise ValueError('Unrelated or invalid analysis envelope')
            # Only projected envelope fields and locally reconstituted observations are returned.
            return {'status': 'SUCCESS', 'analysis_id': data['analysis_id'], 'incident_id': context.incident.ticket_id,
                    'episode_state': context.integration.state, 'analysis': analysis.model_dump(),
                    'provider': data['provider'], 'fixture': data['provider'] == 'fixture', 'model': sanitize_text(data.get('model', 'UNKNOWN')),
                    'cached': bool(data.get('cached')), 'environment': 'SYNTHETIC LAB', 'read_only': True,
                    'diagnostics_execution': context.diagnostics.execution_id if context.diagnostics else None,
                    'ci': context.ci.model_dump(),
                    'observed': [{'id': f.id, 'statement': f.statement, 'source': f.source, 'window': f.window, 'observed_at': f.observed_at} for f in context.facts if f.id in analysis.observed_evidence]}
        except Exception:
            return {'status': 'AI_ANALYSIS_INVALID'}
