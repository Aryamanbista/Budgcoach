from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, status
from sqlalchemy.orm import Session
from uuid import UUID
import logging

from app.api.auth import get_current_user
from app.core.database import get_db
from app.models.user import User
from app.schemas.upload import UploadResponse
from app.services.ocr_service import process_document
from app.services.parser_service import parse_transactions

logger = logging.getLogger(__name__)

router = APIRouter()

@router.post("/upload-statement", response_model=UploadResponse)
async def upload_statement(
    file: UploadFile = File(...),
    wallet_type: str = Form(...),
    account_id: UUID = Form(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    try:
        # Read file bytes
        file_bytes = await file.read()
        
        # Pass to OCR pipeline
        try:
            raw_text = await process_document(file_bytes, file.filename, wallet_type)
        except Exception as ocr_err:
            logger.error(f"OCR Pipeline failed: {ocr_err}")
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Failed to read text from the provided document. Please try again or enter manually."
            )
            
        # Pass to Parser service
        try:
            transactions, duplicates_found = parse_transactions(
                text=raw_text,
                wallet_type=wallet_type,
                user_id=current_user.id,
                account_id=account_id,
                db=db
            )
        except Exception as parse_err:
            logger.error(f"Parser Pipeline failed: {parse_err}")
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Failed to parse transactions from the document. Please try again or enter manually."
            )
            
        return UploadResponse(
            transactions=transactions,
            total_parsed=len(transactions),
            duplicates_found=duplicates_found
        )
    finally:
        await file.close()
