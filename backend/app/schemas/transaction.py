from datetime import datetime, date
from decimal import Decimal
from typing import Optional
from uuid import UUID
from pydantic import BaseModel, Field, field_validator, computed_field
from typing import Literal

class TransactionRow(BaseModel):
    date: Optional[str] = None
    description: Optional[str] = None
    debit: Optional[float] = None
    credit: Optional[float] = None
    balance: Optional[float] = None
    raw_text: str
    source_format: Literal["excel", "pdf_text", "pdf_ocr", "image_ocr"]
    confidence: float = 1.0

class TransactionBase(BaseModel):
    account_id: UUID
    category_id: Optional[UUID] = None
    amount: Decimal = Field(..., ge=0)
    type: str  # 'debit' or 'credit'
    date: date
    transaction_date: datetime = Field(default_factory=datetime.now)
    raw_text: Optional[str] = None
    clean_text: Optional[str] = None
    transaction_text: Optional[str] = None
    is_manual_entry: bool = True
    ml_confidence_score: Optional[float] = None

    @field_validator('type')
    @classmethod
    def validate_type(cls, v: str) -> str:
        val = v.lower().strip()
        if val not in {'debit', 'credit'}:
            raise ValueError("Transaction type must be 'debit' or 'credit'")
        return val

class TransactionCreate(TransactionBase):
    pass

class TransactionUpdate(BaseModel):
    account_id: Optional[UUID] = None
    category_id: Optional[UUID] = None
    amount: Optional[Decimal] = Field(None, ge=0)
    type: Optional[str] = None
    date: Optional[date] = None
    transaction_date: Optional[datetime] = None
    raw_text: Optional[str] = None
    clean_text: Optional[str] = None
    transaction_text: Optional[str] = None
    is_manual_entry: Optional[bool] = None
    ml_confidence_score: Optional[float] = None

    @field_validator('type')
    @classmethod
    def validate_type(cls, v: Optional[str]) -> Optional[str]:
        if v is None:
            return v
        val = v.lower().strip()
        if val not in {'debit', 'credit'}:
            raise ValueError("Transaction type must be 'debit' or 'credit'")
        return val

class TransactionOut(TransactionBase):
    id: UUID
    user_id: UUID
    amount: Decimal

    @computed_field
    @property
    def formatted_amount(self) -> str:
        prefix = "-" if self.type == "debit" else "+"
        return f"{prefix} Rs. {self.amount:,.2f}"

    class Config:
        from_attributes = True
