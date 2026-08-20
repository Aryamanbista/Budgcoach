import fitz  # PyMuPDF
import pytesseract
import cv2
import numpy as np
import logging
from typing import List, Dict, Any
from collections import defaultdict
import io

from app.services.extractors.base import BaseExtractor
from app.schemas.transaction import TransactionRow
from app.services.parser_service import regex_fallback

logger = logging.getLogger(__name__)

class OCRExtractor(BaseExtractor):
    MAX_PDF_PAGES = 50
    MAX_IMAGE_PIXELS = 50_000_000
    def can_handle(self, filename: str) -> bool:
        ext = filename.lower().split('.')[-1]
        return ext in ['pdf', 'png', 'jpg', 'jpeg']

    def _preprocess_image(self, img_np: np.ndarray) -> np.ndarray:
        """
        Applies OpenCV preprocessing: grayscale, thresholding, denoising.
        """
        # Convert to grayscale if it's color
        if len(img_np.shape) == 3:
            gray = cv2.cvtColor(img_np, cv2.COLOR_BGR2GRAY)
        else:
            gray = img_np
            
        height, width = gray.shape[:2]
        if height * width > self.MAX_IMAGE_PIXELS:
            raise ValueError("Image dimensions exceed the safe OCR limit.")
        if width < 1600:
            scale = min(2.0, 1600 / max(width, 1))
            gray = cv2.resize(gray, None, fx=scale, fy=scale, interpolation=cv2.INTER_CUBIC)

        # Denoise
        denoised = cv2.fastNlMeansDenoising(gray, None, 30, 7, 21)
        
        # Adaptive Thresholding (useful for inconsistent lighting in photos)
        # Using simple Otsu's thresholding for standard documents
        _, thresh = cv2.threshold(denoised, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
        
        return thresh

    def _extract_image_rows(self, processed_img: np.ndarray, source: str) -> List[TransactionRow]:
        best_rows: List[TransactionRow] = []
        best_score = -1.0
        # PSM 6 suits tabular blocks; PSM 11 recovers sparse wallet screenshots.
        for page_segmentation_mode in (6, 11):
            ocr_data = pytesseract.image_to_data(
                processed_img,
                output_type=pytesseract.Output.DICT,
                config=f"--oem 3 --psm {page_segmentation_mode}",
                timeout=30,
            )
            parsed_rows: List[TransactionRow] = []
            for reconstructed in self._cluster_words_to_rows(ocr_data):
                raw_text = reconstructed["raw_text"]
                if len(raw_text.strip()) <= 10:
                    continue
                transaction = regex_fallback(raw_text)
                if transaction:
                    transaction.source_format = source
                    transaction.confidence = min(
                        transaction.confidence,
                        reconstructed["confidence"],
                    )
                    parsed_rows.append(transaction)
            score = len(parsed_rows) + sum(row.confidence for row in parsed_rows)
            if score > best_score:
                best_rows, best_score = parsed_rows, score
        return best_rows

    def _cluster_words_to_rows(self, ocr_data: Dict[str, list]) -> List[Dict[str, Any]]:
        """
        Takes pytesseract.image_to_data dictionary and clusters words into rows
        based on their y-coordinates, preserving x-coordinate order.
        """
        n_boxes = len(ocr_data['text'])
        # Extract valid words with coordinates
        words = []
        for i in range(n_boxes):
            text = ocr_data['text'][i].strip()
            conf = int(ocr_data['conf'][i])
            if text and conf > -1:
                words.append({
                    'text': text,
                    'x': ocr_data['left'][i],
                    'y': ocr_data['top'][i],
                    'w': ocr_data['width'][i],
                    'h': ocr_data['height'][i],
                    'conf': conf
                })
                
        if not words:
            return []

        # Sort by y-coordinate
        words.sort(key=lambda w: w['y'])
        
        # Cluster into rows using a threshold (e.g., half the median height)
        median_h = np.median([w['h'] for w in words])
        y_threshold = median_h * 0.5
        
        rows = []
        current_row = [words[0]]
        
        for w in words[1:]:
            # If the y-diff is small, it belongs to the same row
            if abs(w['y'] - current_row[-1]['y']) < y_threshold:
                current_row.append(w)
            else:
                rows.append(current_row)
                current_row = [w]
        if current_row:
            rows.append(current_row)
            
        # Reconstruct row text and average confidence
        reconstructed_rows = []
        for row in rows:
            # Sort words within the row by x-coordinate to preserve column order
            row.sort(key=lambda w: w['x'])
            row_text = " ".join([w['text'] for w in row])
            avg_conf = sum(w['conf'] for w in row) / len(row) if row else 0
            
            reconstructed_rows.append({
                'raw_text': row_text,
                'confidence': avg_conf / 100.0  # Normalize to 0-1
            })
            
        return reconstructed_rows

    def extract(self, file_path: str) -> List[TransactionRow]:
        rows = []
        ext = file_path.lower().split('.')[-1]
        
        try:
            images = []
            if ext == 'pdf':
                # Rasterize PDF to images using PyMuPDF
                doc = fitz.open(file_path)
                if len(doc) > self.MAX_PDF_PAGES:
                    doc.close()
                    raise ValueError(f"PDF statements are limited to {self.MAX_PDF_PAGES} pages.")
                for page_num in range(len(doc)):
                    page = doc[page_num]
                    # Zoom factor for better OCR resolution (e.g. 300 DPI)
                    zoom = 300 / 72
                    mat = fitz.Matrix(zoom, zoom)
                    pix = page.get_pixmap(matrix=mat)
                    
                    # Convert to numpy array for OpenCV
                    img_np = np.frombuffer(pix.samples, dtype=np.uint8).reshape(pix.h, pix.w, pix.n)
                    # Convert RGB to BGR for OpenCV
                    if pix.n == 3:
                        img_np = cv2.cvtColor(img_np, cv2.COLOR_RGB2BGR)
                    elif pix.n == 4:
                        img_np = cv2.cvtColor(img_np, cv2.COLOR_RGBA2BGR)
                    images.append(img_np)
                doc.close()
            else:
                # Direct image file
                img_np = cv2.imread(file_path)
                if img_np is not None:
                    images.append(img_np)
                    
            for img_np in images:
                processed_img = self._preprocess_image(img_np)
                rows.extend(
                    self._extract_image_rows(
                        processed_img,
                        "pdf_ocr" if ext == "pdf" else "image_ocr",
                    )
                )
                            
        except Exception as e:
            logger.exception("OCRExtractor failed: %s", e)
            raise
            
        return rows
