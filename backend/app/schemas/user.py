from datetime import datetime
from typing import Optional
from uuid import UUID
from decimal import Decimal
from pydantic import BaseModel, EmailStr, Field

class UserBase(BaseModel):
    email: EmailStr
    full_name: Optional[str] = None

class UserCreate(UserBase):
    password: str

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class UserOut(UserBase):
    id: UUID
    created_at: datetime
    occupation: Optional[str] = None
    monthly_income: Decimal = Decimal("0")

    class Config:
        from_attributes = True


class UserUpdate(BaseModel):
    full_name: Optional[str] = Field(None, min_length=1, max_length=120)
    occupation: Optional[str] = Field(None, max_length=80)
    monthly_income: Optional[Decimal] = Field(None, ge=0, le=1_000_000_000)

class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    email: Optional[str] = None
