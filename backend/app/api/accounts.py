from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from typing import List
from uuid import UUID

from app.api.auth import get_current_user
from app.core.database import get_db
from app.models.user import User
from app.models.account import Account
from pydantic import BaseModel, Field

router = APIRouter()

class AccountCreate(BaseModel):
    wallet_name: str = Field(..., max_length=100)
    balance: float = Field(default=0.0)

class AccountOut(BaseModel):
    id: UUID
    wallet_name: str
    balance: float

    class Config:
        from_attributes = True

@router.get("/", response_model=List[AccountOut])
async def list_accounts(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(select(Account).filter(Account.user_id == current_user.id))
    accounts = result.scalars().all()
    return accounts

@router.post("/", response_model=AccountOut, status_code=status.HTTP_201_CREATED)
async def create_account(
    account_in: AccountCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    new_account = Account(
        user_id=current_user.id,
        wallet_name=account_in.wallet_name,
        balance=account_in.balance
    )
    db.add(new_account)
    await db.commit()
    await db.refresh(new_account)
    return new_account
