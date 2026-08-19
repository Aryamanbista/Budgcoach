import pandas as pd
import csv
from typing import List
import os

from app.services.extractors.base import BaseExtractor
from app.schemas.transaction import TransactionRow
from app.services.parser_service import normalize_headers

class ExcelExtractor(BaseExtractor):
    def can_handle(self, filename: str) -> bool:
        ext = filename.lower().split('.')[-1]
        return ext in ['xlsx', 'xls', 'csv']

    def extract(self, file_path: str) -> List[TransactionRow]:
        ext = file_path.lower().split('.')[-1]
        
        try:
            if ext == 'xlsx':
                df = pd.read_excel(file_path, engine='openpyxl')
            elif ext == 'xls':
                df = pd.read_excel(file_path, engine='xlrd')
            elif ext == 'csv':
                # Use sniffer to detect delimiter
                with open(file_path, 'r', encoding='utf-8') as f:
                    sample = f.read(2048)
                    try:
                        dialect = csv.Sniffer().sniff(sample)
                        delimiter = dialect.delimiter
                    except Exception:
                        delimiter = ','
                df = pd.read_csv(file_path, sep=delimiter)
            else:
                return []
                
            # Drop empty rows
            df = df.dropna(how='all')
            
            # Map columns
            raw_headers = [str(col) for col in df.columns]
            header_map = normalize_headers(raw_headers)
            
            rows = []
            for index, row in df.iterrows():
                # Convert row to dict for easier access
                row_dict = row.to_dict()
                
                # Extract values using the mapped column names
                date_val = str(row_dict.get(header_map.get('date'), '')) if 'date' in header_map else None
                desc_val = str(row_dict.get(header_map.get('description'), '')) if 'description' in header_map else None
                
                # Helper to parse floats safely
                def parse_float(val):
                    try:
                        if pd.isna(val) or str(val).strip() == '':
                            return None
                        # Remove commas and currency symbols
                        cleaned = str(val).replace(',', '').replace('Rs.', '').replace('NPR', '').strip()
                        return float(cleaned)
                    except ValueError:
                        return None

                debit_val = parse_float(row_dict.get(header_map.get('debit'))) if 'debit' in header_map else None
                credit_val = parse_float(row_dict.get(header_map.get('credit'))) if 'credit' in header_map else None
                balance_val = parse_float(row_dict.get(header_map.get('balance'))) if 'balance' in header_map else None
                
                # Skip rows that don't look like transactions (e.g. metadata rows before the actual table)
                if not date_val and debit_val is None and credit_val is None:
                    continue
                    
                # Reconstruct a raw text for audit purposes
                raw_line = " | ".join([f"{k}: {v}" for k, v in row_dict.items() if pd.notna(v)])
                
                tx_row = TransactionRow(
                    date=date_val,
                    description=desc_val,
                    debit=debit_val,
                    credit=credit_val,
                    balance=balance_val,
                    raw_text=raw_line,
                    source_format="excel",
                    confidence=1.0
                )
                rows.append(tx_row)
                
            return rows
            
        except Exception as e:
            import logging
            logging.getLogger(__name__).error(f"Excel extraction failed: {e}")
            return []
