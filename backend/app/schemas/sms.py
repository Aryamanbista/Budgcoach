from datetime import date as Date
from decimal import Decimal
from typing import List, Literal, Optional

from pydantic import BaseModel, Field


class SmsTransactionPreview(BaseModel):
    row_index: int = Field(..., ge=0)
    date: Date
    type: Literal["debit", "credit"]
    amount: Decimal = Field(..., gt=0)
    clean_text: str
    is_duplicate: bool = False
    fingerprint: Optional[str] = None


class SmsSyncResponse(BaseModel):
    transactions: List[SmsTransactionPreview]
    total_parsed: int
    duplicates_found: int
