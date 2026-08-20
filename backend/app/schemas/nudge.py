from datetime import datetime
from typing import Any, Optional
from uuid import UUID

from pydantic import BaseModel, ConfigDict, computed_field


class NudgeOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    type: str
    title: str
    message: str
    category: Optional[str] = None
    action_label: Optional[str] = None
    action_route: Optional[str] = None
    priority: int
    metric_data: dict[str, Any]
    generated_at: datetime
    expires_at: datetime
    dismissed_at: Optional[datetime] = None

    @computed_field
    @property
    def is_dismissed(self) -> bool:
        return self.dismissed_at is not None
