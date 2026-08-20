import uuid

from sqlalchemy import Column, DateTime, ForeignKey, Integer, JSON, String, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.core.database import Base


class Nudge(Base):
    __tablename__ = "nudges"
    __table_args__ = (
        UniqueConstraint("user_id", "nudge_key", name="uq_nudge_user_key"),
    )

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    nudge_key = Column(String(160), nullable=False)
    type = Column(String(16), nullable=False)
    title = Column(String(160), nullable=False)
    message = Column(String(600), nullable=False)
    category = Column(String(80), nullable=True)
    action_label = Column(String(80), nullable=True)
    action_route = Column(String(120), nullable=True)
    priority = Column(Integer, nullable=False, default=0)
    metric_data = Column(JSON, nullable=False, default=dict)
    generated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    expires_at = Column(DateTime(timezone=True), nullable=False)
    dismissed_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    user = relationship("User", lazy="selectin", back_populates="nudges")
