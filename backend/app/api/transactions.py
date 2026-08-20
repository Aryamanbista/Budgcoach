import csv
import io
from datetime import date
from typing import List, Optional
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
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


def _safe_csv_cell(value: object) -> str:
    text = str(value or "")
    return f"'{text}" if text.startswith(("=", "+", "-", "@")) else text


@router.get("/export.csv", response_class=Response)
async def export_transactions_csv(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Transaction, Account.wallet_name, Category.name)
        .join(Account, Transaction.account_id == Account.id)
        .outerjoin(Category, Transaction.category_id == Category.id)
        .where(Transaction.user_id == current_user.id)
        .order_by(Transaction.date.desc(), Transaction.created_at.desc())
    )
    stream = io.StringIO(newline="")
    writer = csv.writer(stream)
    writer.writerow(["Date", "Type", "Amount NPR", "Description", "Category", "Account"])
    for transaction, account_name, category_name in result.all():
        writer.writerow(
            [
                transaction.date.isoformat(),
                transaction.type,
                transaction.amount,
                _safe_csv_cell(transaction.clean_text or transaction.transaction_text),
                _safe_csv_cell(category_name),
                _safe_csv_cell(account_name),
            ]
        )
    filename = f"budgcoach-transactions-{date.today().isoformat()}.csv"
    return Response(
        content="\ufeff" + stream.getvalue(),
        media_type="text/csv; charset=utf-8",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )

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

@router.post("/batch", response_model=List[TransactionOut], status_code=status.HTTP_201_CREATED)
async def create_transactions_batch(
    payload: List[TransactionCreate],
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    if not payload:
        return []

    # Every row must target one account owned by the authenticated user.
    account_id = payload[0].account_id
    if any(item.account_id != account_id for item in payload):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="All batch transactions must use the same account.",
        )
    result = await db.execute(select(Account).filter(
        Account.id == account_id,
        Account.user_id == current_user.id
    ))
    account = result.scalars().first()
    if not account:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Account not found or access denied.",
        )

    category_ids = {item.category_id for item in payload if item.category_id is not None}
    if category_ids:
        category_result = await db.execute(
            select(Category.id).where(Category.id.in_(category_ids))
        )
        found_categories = set(category_result.scalars().all())
        if found_categories != category_ids:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="One or more categories were not found.",
            )

    from decimal import Decimal
    db_transactions = []
    net_balance_change = Decimal("0.0")

    for tx_payload in payload:
        db_tx = Transaction(
            user_id=current_user.id,
            account_id=tx_payload.account_id,
            category_id=tx_payload.category_id,
            amount=tx_payload.amount,
            type=tx_payload.type,
            date=tx_payload.date,
            transaction_date=tx_payload.transaction_date,
            raw_text=tx_payload.raw_text,
            clean_text=tx_payload.clean_text,
            transaction_text=tx_payload.transaction_text,
            is_manual_entry=tx_payload.is_manual_entry,
            ml_confidence_score=tx_payload.ml_confidence_score
        )
        db.add(db_tx)
        db_transactions.append(db_tx)

        if tx_payload.type == "debit":
            net_balance_change -= tx_payload.amount
        else:
            net_balance_change += tx_payload.amount

    # Update account balance in one go
    account.balance += net_balance_change
    
    await db.commit()
    for tx in db_transactions:
        await db.refresh(tx)
        
    return db_transactions

@router.get("/", response_model=List[TransactionOut])
async def get_transactions(
    start_date: Optional[date] = Query(None),
    end_date: Optional[date] = Query(None),
    category_id: Optional[UUID] = Query(None),
    limit: int = Query(100, ge=1, le=500),
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
