from datetime import date as Date
from decimal import Decimal
from typing import List, Literal, Optional
from uuid import UUID

from pydantic import BaseModel, Field, model_validator


DuplicateStatus = Literal["new", "exact", "possible", "invalid"]


class ParsedTransactionPreview(BaseModel):
    row_index: int = Field(..., ge=0)
    date: Optional[Date] = None
    type: Literal["debit", "credit"]
    amount: Decimal = Field(..., ge=0)
    clean_text: str
    running_balance: Optional[Decimal] = None
    confidence: float = Field(default=1.0, ge=0, le=1)
    fingerprint: Optional[str] = None
    duplicate_status: DuplicateStatus = "new"
    duplicate_of: Optional[UUID] = None
    validation_messages: List[str] = Field(default_factory=list)
    suggested_category: str = "Other"
    category_confidence: float = Field(default=0.0, ge=0, le=1)


class UploadResponse(BaseModel):
    batch_id: UUID
    account_id: UUID
    status: str
    file_reused: bool = False
    transactions: List[ParsedTransactionPreview]
    total_parsed: int
    new_count: int
    exact_duplicates: int
    possible_duplicates: int
    validation_errors: int
    coverage_start_date: Optional[Date] = None
    coverage_end_date: Optional[Date] = None
    coverage_days: int = 0


class HistoryCoverageResponse(BaseModel):
    status: Literal["verified", "estimated", "none"]
    start_date: Optional[Date] = None
    end_date: Optional[Date] = None
    covered_days: int
    required_days: int
    readiness_percentage: float
    minimum_met: bool
    missing_days: int
    is_fresh: bool
    message: str


class ImportRowDecision(BaseModel):
    row_index: int = Field(..., ge=0)
    include: bool = True
    date: Optional[Date] = None
    type: Literal["debit", "credit"]
    amount: Decimal = Field(..., ge=0)
    clean_text: str = Field(..., max_length=500)
    category_name: Optional[str] = Field(default=None, max_length=100)

    @model_validator(mode="after")
    def validate_included_row(self):
        if self.include:
            if self.date is None:
                raise ValueError("Included rows require a valid date.")
            if self.amount <= 0:
                raise ValueError("Included rows require a positive amount.")
            if not self.clean_text.strip():
                raise ValueError("Included rows require a description.")
        return self


class CommitImportRequest(BaseModel):
    rows: List[ImportRowDecision]


class CommitImportResponse(BaseModel):
    batch_id: UUID
    status: str
    imported_count: int
    duplicates_skipped: int
    excluded_count: int
    history_coverage: HistoryCoverageResponse
