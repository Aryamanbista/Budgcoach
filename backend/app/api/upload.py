from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, status
from sqlalchemy.orm import Session
from uuid import UUID
import logging
from datetime import datetime
from decimal import Decimal

from app.api.auth import get_current_user
from app.core.database import get_db
from app.models.user import User
from app.schemas.upload import UploadResponse, ParsedTransactionPreview
from app.services.document_router import process_document
from app.services.parser_service import check_duplicate

logger = logging.getLogger(__name__)

router = APIRouter()

def parse_date_fallback(date_str: str) -> datetime:
    if not date_str:
        return datetime.now()
    formats = [
        "%Y-%m-%d %H:%M:%S", "%Y/%m/%d %H:%M:%S", "%Y-%m-%dT%H:%M:%S",
        "%Y-%m-%d", "%Y/%m/%d", "%d/%m/%Y", "%m/%d/%Y"
    ]
    for fmt in formats:
        try:
            return datetime.strptime(date_str, fmt)
        except ValueError:
            continue
    return datetime.now()

@router.post("/upload-statement", response_model=UploadResponse)
async def upload_statement(
    file: UploadFile = File(...),
    wallet_type: str = Form(...),
    account_id: UUID = Form(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    try:
        file_bytes = await file.read()
        
        try:
            # Route through the multi-format pipeline
            extracted_rows = await process_document(file_bytes, file.filename)
        except Exception as router_err:
            logger.error(f"Document processing failed: {router_err}")
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Failed to process the document format: {str(router_err)}"
            )
            
        transactions = []
        duplicates_found = 0
        
        for row in extracted_rows:
            tx_date = parse_date_fallback(row.date)
            tx_type = "credit" if (row.credit and row.credit > 0) else "debit"
            tx_amount = Decimal(str(row.credit or row.debit or 0.0))
            
            is_duplicate = check_duplicate(db, current_user.id, account_id, tx_amount, tx_date)
            if is_duplicate:
                duplicates_found += 1
                
            preview = ParsedTransactionPreview(
                date=tx_date.date(),
                type=tx_type,
                amount=tx_amount,
                clean_text=row.description or row.raw_text,
                is_duplicate=is_duplicate
            )
            transactions.append(preview)
            
        return UploadResponse(
            transactions=transactions,
            total_parsed=len(transactions),
            duplicates_found=duplicates_found
        )
    finally:
        await file.close()
