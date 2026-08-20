import pdfplumber
import logging
from typing import List

from app.services.extractors.base import BaseExtractor
from app.schemas.transaction import TransactionRow
from app.services.parser_service import normalize_headers, parse_money, regex_fallback

logger = logging.getLogger(__name__)

class PDFTextExtractor(BaseExtractor):
    def can_handle(self, filename: str) -> bool:
        return filename.lower().endswith('.pdf')

    def extract(self, file_path: str) -> List[TransactionRow]:
        rows = []
        has_usable_text = False
        
        try:
            with pdfplumber.open(file_path) as pdf:
                for page in pdf.pages:
                    # Strategy 1: Table Extraction (best for grid-aligned data)
                    table_settings = {
                        "vertical_strategy": "text", 
                        "horizontal_strategy": "text"
                    }
                    tables = page.extract_tables(table_settings)
                    
                    if tables and len(tables) > 0 and len(tables[0]) > 1:
                        has_usable_text = True
                        for table in tables:
                            rows.extend(self._parse_table(table))
                        continue # If tables succeed, skip text extraction for this page
                        
                    # Strategy 2: Text Extraction + line splitting
                    text = page.extract_text()
                    if text and len(text.strip()) > 50:
                        has_usable_text = True
                        rows.extend(self._parse_text_lines(text))
        except Exception as e:
            logger.error(f"PDFTextExtractor failed: {e}")
            
        # If we didn't find any usable text, we assume it's a scanned PDF.
        # Returning an empty list here will trigger the OCRExtractor fallback in the router.
        if not has_usable_text:
            return []
            
        return rows
        
    def _parse_table(self, table: List[List[str]]) -> List[TransactionRow]:
        rows = []
        if not table:
            return rows
            
        header_index = 0
        raw_headers = []
        header_map = {}
        for index, candidate in enumerate(table[:10]):
            candidate_headers = [str(col).strip() if col else "" for col in candidate]
            candidate_map = normalize_headers(candidate_headers)
            if "date" in candidate_map and (
                ("debit" in candidate_map and "credit" in candidate_map)
                or "amount" in candidate_map
            ):
                header_index = index
                raw_headers = candidate_headers
                header_map = candidate_map
                break
        if not header_map:
            return rows

        last_tx = None
        for row in table[header_index + 1:]:
            row_dict = {raw_headers[i]: (row[i] if i < len(row) else "") for i in range(len(raw_headers))}
            
            date_val = str(row_dict.get(header_map.get('date'), '')) if 'date' in header_map else None
            desc_val = str(row_dict.get(header_map.get('description'), '')) if 'description' in header_map else None
            
            debit_val = parse_money(row_dict.get(header_map.get('debit'))) if 'debit' in header_map else None
            credit_val = parse_money(row_dict.get(header_map.get('credit'))) if 'credit' in header_map else None
            balance_val = parse_money(row_dict.get(header_map.get('balance'))) if 'balance' in header_map else None
            
            if not date_val and debit_val is None and credit_val is None:
                # This is likely a continuation of the description from the previous row
                if desc_val and last_tx:
                    if last_tx.description:
                        last_tx.description += " " + desc_val.strip()
                    else:
                        last_tx.description = desc_val.strip()
                continue
                
            raw_line = " | ".join([f"{k}: {v}" for k, v in row_dict.items() if v])
            
            tx_row = TransactionRow(
                date=date_val,
                description=desc_val.strip() if desc_val else "",
                debit=debit_val,
                credit=credit_val,
                balance=balance_val,
                raw_text=raw_line,
                source_format="pdf_text",
                confidence=1.0
            )
            last_tx = tx_row
            rows.append(tx_row)
            
        return rows
        
    def _parse_text_lines(self, text: str) -> List[TransactionRow]:
        rows = []
        for line in text.split('\n'):
            line = line.strip()
            if not line:
                continue
            
            # Rely on parser_service.regex_fallback since plain text lines lose column alignment
            tx_row = regex_fallback(line)
            if tx_row:
                tx_row.source_format = "pdf_text"
                tx_row.confidence = 0.9 # High confidence because it's native text, not OCR
                rows.append(tx_row)
                
        return rows
