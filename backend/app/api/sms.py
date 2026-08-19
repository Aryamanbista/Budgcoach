from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from uuid import UUID
import logging
from pydantic import BaseModel
from typing import List

from app.api.auth import get_current_user
from app.core.database import get_db
from app.models.user import User
from app.schemas.upload import UploadResponse
from app.services.parser_service import parse_transactions

logger = logging.getLogger(__name__)

router = APIRouter()

class SmsSyncRequest(BaseModel):
    wallet_type: str
    account_id: UUID
    messages: List[str]

@router.post("/sms-sync", response_model=UploadResponse)
async def sync_sms(
    payload: SmsSyncRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    try:
        # Join all messages with newlines so parse_transactions can iterate line by line
        raw_text = "\n".join(payload.messages)
        
        transactions, duplicates_found = parse_transactions(
            text=raw_text,
            wallet_type=payload.wallet_type,
            user_id=current_user.id,
            account_id=payload.account_id,
            db=db
        )
        
        return UploadResponse(
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
