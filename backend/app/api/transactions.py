from datetime import date
from typing import List, Optional
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from app.api.auth import get_current_user
from app.core.database import get_db
from app.models.user import User
from app.models.account import Account
from app.models.category import Category
from app.models.transaction import Transaction
from app.schemas.transaction import TransactionCreate, TransactionOut

router = APIRouter()

@router.post("/", response_model=TransactionOut, status_code=status.HTTP_201_CREATED)
async def create_transaction(
    payload: TransactionCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    # 1. Validate that the account exists and belongs to the current user
    result = await db.execute(select(Account).filter(
        Account.id == payload.account_id,
        Account.user_id == current_user.id
    ))
    account = result.scalars().first()
    if not account:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Account not found or access denied."
        )
    
    # 2. Validate category if provided
    if payload.category_id:
        result_cat = await db.execute(select(Category).filter(Category.id == payload.category_id))
        category = result_cat.scalars().first()
        if not category:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Category not found."
            )
            
    # 3. Create transaction
    db_tx = Transaction(
        user_id=current_user.id,
        account_id=payload.account_id,
        category_id=payload.category_id,
        amount=payload.amount,
        type=payload.type,
        date=payload.date,
        transaction_date=payload.transaction_date,
        raw_text=payload.raw_text,
        clean_text=payload.clean_text,
        transaction_text=payload.transaction_text,
        is_manual_entry=payload.is_manual_entry,
        ml_confidence_score=payload.ml_confidence_score
    )
    db.add(db_tx)
    
    # 4. Update account balance
    if payload.type == "debit":
        account.balance -= payload.amount
    else:
        account.balance += payload.amount
        
    await db.commit()
    await db.refresh(db_tx)
    return db_tx

@router.get("/", response_model=List[TransactionOut])
async def get_transactions(
    start_date: Optional[date] = Query(None),
    end_date: Optional[date] = Query(None),
    category_id: Optional[UUID] = Query(None),
    limit: int = Query(100, ge=1),
    offset: int = Query(0, ge=0),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    query = select(Transaction).filter(Transaction.user_id == current_user.id)
    
    if start_date:
        query = query.filter(Transaction.date >= start_date)
    if end_date:
        query = query.filter(Transaction.date <= end_date)
    if category_id:
        query = query.filter(Transaction.category_id == category_id)
        
    query = query.order_by(Transaction.date.desc()).offset(offset).limit(limit)
    result = await db.execute(query)
    return result.scalars().all()
