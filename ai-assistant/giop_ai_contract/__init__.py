"""Shared, bounded advisory contract. No infrastructure clients or execution tools."""
import re
from typing import Annotated, Literal
from pydantic import BaseModel, ConfigDict, Field, StringConstraints, AfterValidator, field_validator, model_validator

EventId = Annotated[str, StringConstraints(pattern=r'^[1-9][0-9]{0,19}$')]
FactId = Literal['zabbix_problem', 'pilot_tcp', 'workload_state', 'platform_health', 'current_pilot', 'recovery', 'followup']
RunbookId = Literal['RB-OPS-001', 'RB-OPS-002', 'RB-OPS-003']


def sanitize_text(value, secrets=(), limit=300):
    text = str(value if value is not None else 'UNKNOWN')[:4096]
    for secret in secrets:
        if secret:
            text = text.replace(str(secret), '[REDACTED]')
    text = re.sub(r'(?i)\b(?:bearer|basic)\s+[A-Za-z0-9+/=_\-.]+', '[REDACTED]', text)
    text = re.sub(r'(?i)\b(?:password|passwd|authorization|client_secret|api[_ -]?token|access[_ -]?token|oauth[_ -]?secret|secret)\s*[:=]\s*[^\s,;]+', '[REDACTED]', text)
    text = re.sub(r'''(?i)\b[A-Za-z0-9_]*(?:password|passwd|secret|token|client_id|authorization)[A-Za-z0-9_]*\s*[:=]\s*(?:"[^"]*"|'[^']*'|[^\s,;]+)''', '[REDACTED]', text)
    text = re.sub(r'\b(?:gh[pousr]_[A-Za-z0-9]{20,}|AKIA[A-Z0-9]{16}|eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)\b', '[REDACTED]', text)
    text = re.sub(r'[\x00-\x1f\x7f]', ' ', text).strip()
    return (text or 'UNKNOWN')[:limit]


Text = Annotated[str, StringConstraints(min_length=1, max_length=300), AfterValidator(sanitize_text)]


class StrictModel(BaseModel):
    model_config = ConfigDict(extra='forbid', allow_inf_nan=False)

    @field_validator('*', mode='after')
    @classmethod
    def sanitize_strings(cls, value):
        if isinstance(value, str):
            return sanitize_text(value, limit=max(len(value), 1))
        return value


class Incident(StrictModel):
    ticket_id: int = Field(gt=0, strict=True)
    title: Text
    status: Text
    priority: Text
    synthetic: Literal[True]


class Zabbix(StrictModel):
    problem_event_id: EventId
    recovery_event_id: EventId | None
    host_id: Literal['10683']
    host: Literal['GUA-LAB-SRV-WEB-001']
    trigger_id: Literal['25228']
    trigger: Text
    severity: int | None = Field(default=None, ge=0, le=5, strict=True)
    problem_time: Text
    recovery_time: Text | None


class CI(StrictModel):
    ci_uid: Literal['urn:uuid:9e68f0af-8b55-4b0e-95e4-07dc02a7f6cb']
    computer_id: Literal[1]
    asset_name: Literal['GUA-LAB-SRV-WEB-001']
    location: Text | None = None
    mapping_basis: Literal['Frozen Phase 3 logical pilot mapping'] = 'Frozen Phase 3 logical pilot mapping'


class Episode(StrictModel):
    state: Literal['PROBLEM_OPEN', 'RECOVERED_PENDING_OPERATOR_VALIDATION', 'OPERATOR_RECONCILIATION_REQUIRED', 'TICKET_CREATE_PENDING', 'FOLLOWUP_CREATE_PENDING']
    mode: Literal['live']
    event_id: EventId
    ticket_id: int = Field(gt=0, strict=True)
    recovery_event_id: EventId | None
    followup_id: int | None = Field(default=None, gt=0, strict=True)


class Evidence(StrictModel):
    id: FactId
    value: Literal['problem', 'failed', 'passed', 'stopped', 'running', 'healthy', 'unknown', 'recovered', 'confirmed']
    source: Literal['Zabbix', 'Integration', 'RB-OPS-002']
    window: Literal['historical incident', 'current snapshot']
    observed_at: Text | None = None

    @model_validator(mode='after')
    def compatible(self):
        pairs = {'zabbix_problem': ('problem',), 'pilot_tcp': ('failed', 'passed'),
                 'workload_state': ('stopped', 'running'), 'platform_health': ('healthy', 'unknown'),
                 'current_pilot': ('passed', 'failed'), 'recovery': ('recovered',), 'followup': ('confirmed',)}
        if self.value not in pairs[self.id]:
            raise ValueError('Incompatible evidence value')
        return self

    @property
    def statement(self):
        return {'zabbix_problem': 'Zabbix Problem recorded for the approved pilot',
                'pilot_tcp': 'Pilot TCP check failed' if self.value == 'failed' else 'Pilot TCP check passed',
                'workload_state': 'Synthetic web workload stopped' if self.value == 'stopped' else 'Synthetic web workload running',
                'platform_health': 'Other checked GIOP platform services healthy' if self.value == 'healthy' else 'Other platform service health unknown',
                'current_pilot': 'Current pilot trigger OK' if self.value == 'passed' else 'Current pilot trigger reports a Problem',
                'recovery': 'Integration correlated a Recovery',
                'followup': 'Integration references a GLPI Recovery follow-up'}[self.id]


class Diagnostics(StrictModel):
    execution_id: Annotated[str, StringConstraints(pattern=r'^\d{8}T\d{9}Z-[0-9a-f]{8}$')]
    collected_at: Text
    ticket_id: int = Field(gt=0, strict=True)
    event_id: EventId
    evidence: list[Evidence] = Field(max_length=3)

    @model_validator(mode='after')
    def projected_only(self):
        if any(f.id not in ('pilot_tcp', 'workload_state', 'platform_health') or f.source != 'RB-OPS-002' or f.window != 'historical incident' for f in self.evidence):
            raise ValueError('Unapproved diagnostic projection')
        return self


class Runbook(StrictModel):
    id: RunbookId
    purpose: Text
    risk: Literal['low', 'medium', 'high']
    prerequisites: list[Text] = Field(min_length=1, max_length=4)
    operator_approval_required: Literal[True] = True


RUNBOOKS = [
    Runbook(id='RB-OPS-001', purpose='Read-only service health assessment', risk='low', prerequisites=['Local synthetic LAB', 'Review current service evidence']),
    Runbook(id='RB-OPS-002', purpose='Read-only sanitized incident diagnostics', risk='low', prerequisites=['Approved pilot identity', 'Review diagnostic timestamps']),
    Runbook(id='RB-OPS-003', purpose='Controlled recovery of only synthetic web-workload; plan by default', risk='low', prerequisites=['Explicit operator approval outside AI', 'Identity and LIVE Integration preconditions', 'Historical recommendation is not authorization for a new action']),
]


class IncidentAnalysisContext(StrictModel):
    version: Literal['1'] = '1'
    environment: Literal['SYNTHETIC LAB']
    incident: Incident
    zabbix: Zabbix
    ci: CI
    integration: Episode
    diagnostics: Diagnostics | None
    evidence: list[Evidence] = Field(max_length=7)
    runbooks: list[Runbook] = Field(min_length=1, max_length=3)

    @model_validator(mode='after')
    def correlated(self):
        e, z = self.integration, self.zabbix
        if (e.ticket_id, e.event_id, e.recovery_event_id) != (self.incident.ticket_id, z.problem_event_id, z.recovery_event_id):
            raise ValueError('Context correlation mismatch')
        if self.diagnostics and (self.diagnostics.ticket_id, self.diagnostics.event_id) != (e.ticket_id, e.event_id):
            raise ValueError('Diagnostics do not belong to the incident')
        facts = self.evidence + (self.diagnostics.evidence if self.diagnostics else [])
        if len({f.id for f in facts}) != len(facts):
            raise ValueError('Duplicate evidence identity')
        canonical = {r.id: r.model_dump() for r in RUNBOOKS}
        if len({r.id for r in self.runbooks}) != len(self.runbooks) or any(r.model_dump() != canonical[r.id] for r in self.runbooks):
            raise ValueError('Unapproved runbook definition')
        return self

    @property
    def facts(self):
        return self.evidence + (self.diagnostics.evidence if self.diagnostics else [])


Confidence = Annotated[float, Field(ge=0, le=1, strict=True)]


class Cause(StrictModel):
    classification: Literal['INFERRED']
    cause: Text
    confidence: Confidence
    evidence: list[FactId] = Field(min_length=1, max_length=5)


class Recommendation(StrictModel):
    id: RunbookId
    reason: Text
    risk: Literal['low', 'medium', 'high']
    operator_approval_required: Literal[True]


class AnalysisOutput(StrictModel):
    summary: Text
    affected_service: Literal['web-workload']
    observed_evidence: list[FactId] = Field(min_length=1, max_length=10)
    probable_causes: list[Cause] = Field(max_length=4)
    recommended_checks: list[Text] = Field(min_length=1, max_length=6)
    recommended_runbook: Recommendation
    missing_information: list[Text] = Field(min_length=1, max_length=6)
    operator_notes: Text
    overall_confidence: Confidence

    def verify(self, context):
        supplied = {f.id for f in context.facts}
        refs = self.observed_evidence + [ref for cause in self.probable_causes for ref in cause.evidence]
        if not set(refs) <= supplied:
            raise ValueError('Unsupplied evidence reference')
        runbook = next((r for r in context.runbooks if r.id == self.recommended_runbook.id), None)
        if not runbook or runbook.risk != self.recommended_runbook.risk:
            raise ValueError('Unsupplied runbook or risk')
        # The contract is advisory. Reject executable snippets or tool requests, even though
        # the service has no command runner, infrastructure client or tool dispatcher.
        import json
        text = json.dumps(self.model_dump())
        if re.search(r'(?i)```|\b(?:powershell|docker|curl|invoke-restmethod|invoke-expression)\s|https?://|authorization\s*[:=]', text):
            raise ValueError('Executable instructions are outside the advisory contract')
        return self
