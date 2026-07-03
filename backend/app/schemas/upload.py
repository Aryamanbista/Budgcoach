from datetime import date
from decimal import Decimal
from typing import List, Optional
from pydantic import BaseModel, Field

class ParsedTransactionPreview(BaseModel):
    date: date
    type: str  # 'debit' or 'credit'
    amount: Decimal = Field(..., ge=0)
    clean_text: Optional[str] = None
    is_duplicate: bool = False

class UploadResponse(BaseModel):
    transactions: List[ParsedTransactionPreview]
    total_parsed: int
    duplicates_found: int
