import uuid

from sqlalchemy import (
    Boolean,
    Column,
    Date,
    DateTime,
    ForeignKey,
    Integer,
    JSON,
    String,
    UniqueConstraint,
    func,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.core.database import Base


class ImportBatch(Base):
    __tablename__ = "import_batches"
    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "account_id",
            "file_hash",
            name="uq_import_batch_user_account_file",
        ),
    )

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    account_id = Column(
        UUID(as_uuid=True),
        ForeignKey("accounts.id", ondelete="CASCADE"),
        nullable=False,
    )
    file_hash = Column(String(64), nullable=False)
    original_filename = Column(String(255), nullable=False)
    parser_version = Column(String(32), nullable=False, default="1.0")
    status = Column(String(24), nullable=False, default="processing")
    total_parsed = Column(Integer, nullable=False, default=0)
    new_count = Column(Integer, nullable=False, default=0)
    exact_duplicate_count = Column(Integer, nullable=False, default=0)
    possible_duplicate_count = Column(Integer, nullable=False, default=0)
    validation_error_count = Column(Integer, nullable=False, default=0)
    imported_count = Column(Integer, nullable=False, default=0)
    skipped_count = Column(Integer, nullable=False, default=0)
    parsed_payload = Column(JSON, nullable=False, default=list)
    coverage_start_date = Column(Date, nullable=True)
    coverage_end_date = Column(Date, nullable=True)
    coverage_days = Column(Integer, nullable=False, default=0)
    coverage_verified = Column(Boolean, nullable=False, default=False)
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    completed_at = Column(DateTime(timezone=True), nullable=True)

    account = relationship("Account", lazy="selectin")
    transactions = relationship("Transaction", lazy="selectin")
