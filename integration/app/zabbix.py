from datetime import datetime
from typing import Literal
from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


class Event(BaseModel):
    model_config = ConfigDict(extra='forbid')
    kind: Literal['PROBLEM', 'RECOVERY']
    event_id: str = Field(pattern=r'^[1-9][0-9]{0,19}$')
    host_id: str = Field(pattern=r'^[1-9][0-9]{0,19}$')
    trigger_id: str = Field(pattern=r'^[1-9][0-9]{0,19}$')
    host: str = Field(min_length=1, max_length=128)
    trigger: str = Field(min_length=1, max_length=256)
    severity: int = Field(ge=0, le=5, strict=True)
    event_time: datetime
    problem_event_id: str | None = Field(default=None, pattern=r'^[1-9][0-9]{0,19}$')

    @field_validator('event_time')
    @classmethod
    def timezone_required(cls, value):
        if value.tzinfo is None:
            raise ValueError('Timezone required')
        return value

    @model_validator(mode='after')
    def correlation(self):
        if self.kind == 'RECOVERY' and (not self.problem_event_id or self.problem_event_id == self.event_id):
            raise ValueError('Recovery requires distinct original problem_event_id')
        if self.kind == 'PROBLEM' and self.problem_event_id is not None:
            raise ValueError('PROBLEM must omit problem_event_id')
        return self
