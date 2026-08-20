import uuid
from sqlalchemy import (
    Boolean,
    Column,
    Date,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    Numeric,
    String,
    UniqueConstraint,
    func,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from app.core.database import Base

class Transaction(Base):
    __tablename__ = "transactions"
    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "account_id",
            "fingerprint",
            name="uq_transaction_user_account_fingerprint",
        ),
    )
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    account_id = Column(UUID(as_uuid=True), ForeignKey("accounts.id", ondelete="CASCADE"), nullable=False)
    category_id = Column(UUID(as_uuid=True), ForeignKey("categories.id", ondelete="SET NULL"), nullable=True)
    
    amount = Column(Numeric(12, 2), nullable=False)
    type = Column(String, nullable=False)  # 'debit' or 'credit'
    
    date = Column(Date, nullable=False)
    transaction_date = Column(DateTime, nullable=False, default=func.now())
    
    raw_text = Column(String, nullable=True)
    clean_text = Column(String, nullable=True)
    transaction_text = Column(String, nullable=True)
    
    is_manual_entry = Column(Boolean, default=True, nullable=False)
    ml_confidence_score = Column(Float, nullable=True)
    fingerprint = Column(String(64), nullable=True)
    import_batch_id = Column(
        UUID(as_uuid=True),
        ForeignKey("import_batches.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    source_row_index = Column(Integer, nullable=True)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    # Relationships
    user = relationship("User", lazy="selectin", back_populates="transactions")
    account = relationship("Account", lazy="selectin", back_populates="transactions")
    category = relationship("Category", lazy="selectin", back_populates="transactions")
    import_batch = relationship("ImportBatch", lazy="selectin", back_populates="transactions")
