from decimal import Decimal
from typing import Optional
from uuid import UUID
from pydantic import BaseModel, Field, computed_field

class BudgetBase(BaseModel):
    category_id: UUID
    limit_amount: Decimal = Field(..., ge=0)
    spent_amount: Decimal = Field(default=Decimal("0.00"), ge=0)
    month_year: str

class BudgetCreate(BudgetBase):
    pass

class BudgetUpdate(BaseModel):
    limit_amount: Optional[Decimal] = Field(None, ge=0)
    spent_amount: Optional[Decimal] = Field(None, ge=0)
    month_year: Optional[str] = None

class BudgetOut(BudgetBase):
    id: UUID
    user_id: UUID
    limit_amount: Decimal
    spent_amount: Decimal

    @computed_field
    @property
    def formatted_limit(self) -> str:
        return f"Rs. {self.limit_amount:,.2f}"

    @computed_field
    @property
    def formatted_spent(self) -> str:
        return f"Rs. {self.spent_amount:,.2f}"

    class Config:
        from_attributes = True
