from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from uuid import UUID
import logging
from pydantic import BaseModel
from typing import List

from app.api.auth import get_current_user
from app.core.database import get_db
from app.models.user import User
from app.models.account import Account
from app.models.transaction import Transaction
from app.schemas.sms import SmsSyncResponse
from app.services.parser_service import parse_transactions
from sqlalchemy.future import select

logger = logging.getLogger(__name__)

router = APIRouter()

class SmsSyncRequest(BaseModel):
    wallet_type: str
    account_id: UUID
    messages: List[str]

@router.post("/sms-sync", response_model=SmsSyncResponse)
async def sync_sms(
    payload: SmsSyncRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    try:
        # Join all messages with newlines so parse_transactions can iterate line by line
        raw_text = "\n".join(payload.messages)
        
        transactions, duplicates_found = await parse_transactions(
            text=raw_text,
            wallet_type=payload.wallet_type,
            user_id=current_user.id,
            account_id=payload.account_id,
            db=db
        )
        
        # 1. Require an account owned by the authenticated user.
        result = await db.execute(select(Account).filter(
            Account.id == payload.account_id,
            Account.user_id == current_user.id
        ))
        account = result.scalars().first()
        if not account:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Account not found or access denied.",
            )

        from decimal import Decimal
        # 2. Persist new transactions & update balance
        net_balance_change = Decimal("0.0")
        db_transactions = []
        
        for tx in transactions:
            if tx.is_duplicate:
                continue
                
            db_tx = Transaction(
                user_id=current_user.id,
                account_id=account.id,
                amount=tx.amount,
                type=tx.type,
                date=tx.date,
                raw_text=tx.clean_text,
                transaction_text=tx.clean_text,
                clean_text=tx.clean_text,
                is_manual_entry=False,
                fingerprint=tx.fingerprint,
            )
            db.add(db_tx)
            db_transactions.append(db_tx)
            
            if tx.type == "debit":
                net_balance_change -= tx.amount
            else:
                net_balance_change += tx.amount
                
        account.balance += net_balance_change
        await db.commit()

        return SmsSyncResponse(
            transactions=transactions,
            total_parsed=len(transactions),
            duplicates_found=duplicates_found
        )
    except Exception as parse_err:
        logger.error(f"SMS Parser failed: {parse_err}")
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Failed to parse transactions from the provided SMS messages."
        )
