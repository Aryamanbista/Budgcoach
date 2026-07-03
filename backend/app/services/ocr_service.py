import io
from PIL import Image
from pdf2image import convert_from_bytes
import pytesseract
import logging

logger = logging.getLogger(__name__)

async def process_document(file_bytes: bytes, filename: str, wallet_type: str) -> str:
    """
    Extracts text from a PDF or image file buffer using OCR.
    
    Args:
        file_bytes: The raw bytes of the file.
        filename: Original filename to determine if it's a PDF.
        wallet_type: Target wallet type (can be used to customize PSM in the future).
        
    Returns:
        The extracted and cleaned text string.
    """
    extracted_text = ""
    try:
        # Determine if PDF
        if filename.lower().endswith(".pdf"):
            # Convert PDF to images
            images = convert_from_bytes(file_bytes, dpi=300, fmt="jpeg")
            for img in images:
                # --psm 6 assumes a single uniform block of text, good for tables
                text = pytesseract.image_to_string(img, config="--psm 6")
                extracted_text += text + "\n"
        else:
            # Assume Image (JPEG, PNG, etc.)
            img = Image.open(io.BytesIO(file_bytes))
            # --psm 6 assumes a single uniform block of text
            extracted_text = pytesseract.image_to_string(img, config="--psm 6")
            
        # Basic text cleanup: remove excessive empty lines and leading/trailing spaces
        extracted_text = "\n".join([line.strip() for line in extracted_text.split('\n') if line.strip()])
        return extracted_text
    except Exception as e:
        logger.error(f"OCR processing failed for {filename}: {str(e)}")
        raise e
