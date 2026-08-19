import uuid
from sqlalchemy import Column, String, DateTime, Numeric, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from app.core.database import Base

class User(Base):
    __tablename__ = "users"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    name = Column(String, nullable=False, default="")
    full_name = Column(String, nullable=True)
    financial_score = Column(Numeric(5, 2), default=0.00)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    # Relationships
    accounts = relationship("Account", lazy="selectin", back_populates="user", cascade="all, delete-orphan")
    transactions = relationship("Transaction", lazy="selectin", back_populates="user", cascade="all, delete-orphan")
    budgets = relationship("Budget", lazy="selectin", back_populates="user", cascade="all, delete-orphan")
    savings_goals = relationship("SavingsGoal", lazy="selectin", back_populates="user", cascade="all, delete-orphan")
