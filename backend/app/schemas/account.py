from decimal import Decimal
from typing import Optional
from uuid import UUID
from pydantic import BaseModel, Field, computed_field

class AccountBase(BaseModel):
    wallet_name: str
    balance: Decimal = Field(default=Decimal("0.00"), ge=0)

class AccountCreate(AccountBase):
    pass

class AccountUpdate(BaseModel):
    wallet_name: Optional[str] = None
    balance: Optional[Decimal] = Field(default=None, ge=0)

class AccountOut(AccountBase):
    id: UUID
    user_id: UUID
    balance: Decimal

    @computed_field
    @property
    def formatted_balance(self) -> str:
        return f"Rs. {self.balance:,.2f}"

    class Config:
        from_attributes = True
