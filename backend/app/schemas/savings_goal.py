from datetime import date
from decimal import Decimal
from typing import Optional
from uuid import UUID
from pydantic import BaseModel, Field, computed_field

class SavingsGoalBase(BaseModel):
    name: str
    target_amount: Decimal = Field(..., ge=0)
    current_amount: Decimal = Field(default=Decimal("0.00"), ge=0)
    deadline_date: date

class SavingsGoalCreate(SavingsGoalBase):
    pass

class SavingsGoalUpdate(BaseModel):
    name: Optional[str] = None
    target_amount: Optional[Decimal] = Field(None, ge=0)
    current_amount: Optional[Decimal] = Field(None, ge=0)
    deadline_date: Optional[date] = None

class SavingsGoalOut(SavingsGoalBase):
    id: UUID
    user_id: UUID
    target_amount: Decimal
    current_amount: Decimal
    deadline_date: date

    @computed_field
    @property
    def formatted_target(self) -> str:
        return f"Rs. {self.target_amount:,.2f}"

    @computed_field
    @property
    def formatted_current(self) -> str:
        return f"Rs. {self.current_amount:,.2f}"

    @computed_field
    @property
    def monthly_contribution_progress(self) -> str:
        if self.current_amount >= self.target_amount:
            return "Goal achieved! Rs. 0.00 needed monthly."
        
        today = date.today()
        # Calculate months remaining
        months_remaining = (self.deadline_date.year - today.year) * 12 + (self.deadline_date.month - today.month)
        if months_remaining <= 0:
            months_remaining = 1
            
        remaining_amount = self.target_amount - self.current_amount
        monthly_needed = remaining_amount / Decimal(months_remaining)
        
        return f"Rs. {monthly_needed:,.2f}/month needed for the next {months_remaining} month(s) to reach Rs. {self.target_amount:,.2f}"

    class Config:
        from_attributes = True
