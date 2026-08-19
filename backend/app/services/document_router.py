import os
import tempfile
import logging
from typing import List

from app.schemas.transaction import TransactionRow
from app.services.extractors.excel_extractor import ExcelExtractor
from app.services.extractors.pdf_text_extractor import PDFTextExtractor
from app.services.extractors.ocr_extractor import OCRExtractor
from app.services.parser_service import reconcile_balances
from app.services.extractors.base import LLMExtractor

logger = logging.getLogger(__name__)

USE_LLM_FALLBACK = False  # Feature flag

async def process_document(file_bytes: bytes, filename: str) -> List[TransactionRow]:
    """
    Routes the document to the appropriate extractor based on extension and content.
    Returns a list of TransactionRow objects.
    """
    ext = filename.lower().split('.')[-1]
    
    # Save to a temporary file since many libraries (pandas, pdfplumber, fitz, cv2) 
    # prefer or require file paths.
    temp_fd, temp_path = tempfile.mkstemp(suffix=f".{ext}")
    try:
        with os.fdopen(temp_fd, 'wb') as f:
            f.write(file_bytes)
            
        rows = []
        
        excel_extractor = ExcelExtractor()
        pdf_extractor = PDFTextExtractor()
        ocr_extractor = OCRExtractor()
        
        # 1. Try Excel Extraction
        if excel_extractor.can_handle(filename):
            rows = excel_extractor.extract(temp_path)
            
        # 2. Try PDF Text Extraction
        elif pdf_extractor.can_handle(filename):
            rows = pdf_extractor.extract(temp_path)
            
            # If PDF text extraction returned nothing, it's likely a scanned PDF
            if not rows and ocr_extractor.can_handle(filename):
                logger.info(f"{filename} appears to be a scanned PDF. Falling back to OCR.")
                rows = ocr_extractor.extract(temp_path)
                
        # 3. Try Image OCR Extraction
        elif ocr_extractor.can_handle(filename):
            rows = ocr_extractor.extract(temp_path)
            
        else:
            raise ValueError(f"Unsupported file format: {ext}")
            
        # Escalation Design (Option B readiness)
        # Check if the extracted rows have broken balances or if nothing was extracted
        if rows:
            failed_indices = reconcile_balances(rows)
            failure_rate = len(failed_indices) / len(rows)
            
            if failure_rate > 0.3:
                logger.warning(f"High reconciliation failure rate ({failure_rate*100:.1f}%).")
                if USE_LLM_FALLBACK:
                    logger.info("Triggering LLMExtractor fallback...")
                    rows = LLMExtractor().extract(temp_path)
        else:
            logger.warning("No rows extracted by primary extractors.")
            if USE_LLM_FALLBACK:
                logger.info("Triggering LLMExtractor fallback...")
                rows = LLMExtractor().extract(temp_path)
                
        return rows
        
    finally:
        # Clean up temporary file
        if os.path.exists(temp_path):
            os.remove(temp_path)
