import re
import logging
from typing import List, Dict, Any, Optional

from app.schemas.transaction import TransactionRow

logger = logging.getLogger(__name__)

HEADER_ALIASES = {
    "date":        ["date", "txn date", "value date", "posting date", "transaction date", "ansaction date"],
    "description": ["description", "narration", "particulars", "details", "remarks", "escription"],
    "debit":       ["debit", "withdrawal", "dr", "debit amount"],
    "credit":      ["credit", "deposit", "cr", "credit amount"],
    "balance":     ["balance", "closing balance", "running balance"],
}

def normalize_headers(raw_headers: List[str]) -> Dict[str, str]:
    """
    Maps raw column headers from Excel/PDF to standard keys.
    Returns a dict mapping the standard key (e.g. 'debit') to the raw header string.
    """
    mapping = {}
    for standard_key, aliases in HEADER_ALIASES.items():
        for raw in raw_headers:
            if not raw or not isinstance(raw, str):
                continue
            if raw.lower().strip() in aliases:
                mapping[standard_key] = raw
                break
    return mapping

def regex_fallback(raw_text: str) -> Optional[TransactionRow]:
    """
    Used only when structured extraction completely fails (e.g., OCR fallback).
    Tries a generic regex to pull date, amount, and type.
    """
    generic_pattern = re.compile(
        r"(?i)(?P<date>\d{2,4}[-/]\d{2}[-/]\d{2,4}).*?(?P<type>dr|cr|debited|credited|withdrawal|deposit)\s+(?P<amount>\d+(?:\.\d{2})?)"
    )
    match = generic_pattern.search(raw_text)
    if not match:
        return None
        
    date_str = match.group('date')
    tx_type = match.group('type').lower()
    amount = float(match.group('amount'))
    
    row = TransactionRow(
        date=date_str,
        description="Parsed via Regex Fallback",
        raw_text=raw_text,
        source_format="image_ocr",
        confidence=0.5
    )
    
    if tx_type in ['debited', 'dr', 'withdrawal']:
        row.debit = amount
    elif tx_type in ['credited', 'cr', 'deposit']:
        row.credit = amount
        
    return row

def reconcile_balances(rows: List[TransactionRow]) -> List[int]:
    """
    Sanity check to catch parsing errors (swapped columns, missed rows).
    Returns indices of rows where prev_balance ± amount != next_balance.
    """
    failed_indices = []
    # Sort chronologically if possible, or assume already sorted. 
    # For a simple check, we iterate assuming rows are sequential.
    for i in range(len(rows) - 1):
        curr = rows[i]
        nxt = rows[i+1]
        
        if curr.balance is not None and nxt.balance is not None:
            # We don't know the exact order (asc/desc), so check both possibilities
            amt = (curr.credit or 0.0) - (curr.debit or 0.0)
            next_amt = (nxt.credit or 0.0) - (nxt.debit or 0.0)
            
            # If ascending: curr.balance + next_amt = nxt.balance
            # If descending: nxt.balance + amt = curr.balance
            diff_asc = abs((curr.balance + next_amt) - nxt.balance)
            diff_desc = abs((nxt.balance + amt) - curr.balance)
            
            # Allow minor floating point rounding differences
            if diff_asc > 0.05 and diff_desc > 0.05:
                failed_indices.append(i)
                
    return failed_indices

async def check_duplicate(db, user_id, account_id, amount, tx_date) -> bool:
    """
    Idempotency & Duplicate detection layer:
    Checks if a transaction with the same amount, user, account, and date exists.
    """
    from sqlalchemy import select
    from app.models.transaction import Transaction
    
    stmt = select(Transaction).where(
        Transaction.user_id == user_id,
        Transaction.account_id == account_id,
        Transaction.amount == amount,
        Transaction.date == tx_date.date()
    )
    result = await db.execute(stmt)
    existing = result.scalars().first()
    
    return existing is not None

async def parse_transactions(text: str, wallet_type: str, user_id: str, account_id: str, db: Any) -> tuple[List[Any], int]:
    """
    Parses SMS text into transaction previews.
    Splits by newline and attempts to match a regex for each line.
    """
    from app.schemas.sms import SmsTransactionPreview
    from app.services.import_service import (
        build_transaction_fingerprint,
        classify_duplicate,
    )
    from datetime import datetime
    
    transactions = []
    duplicates_found = 0
    
    # Generic wallet pattern: e.g. "Rs. 500 debited from eSewa on 2023-10-25"
    # Or Khalti: "Rs. 200 credited to Khalti on 2023-10-26"
    # This regex is simplified for the demo but captures amount, type, date.
    pattern = re.compile(
        r"(?i)(?:rs\.?|npr)\s*(?P<amount>\d+(?:\.\d{2})?)\s+(?P<type>debited|credited|sent|received|paid).*?(?P<date>\d{4}[-/]\d{2}[-/]\d{2}|\d{2}[-/]\d{2}[-/]\d{4})"
    )
    
    seen_in_batch = set() # To track intra-batch duplicates
    
    lines = text.strip().split('\n')
    for idx, line in enumerate(lines):
        line = line.strip()
        if not line:
            continue
            
        match = pattern.search(line)
        if not match:
            logger.debug(f"SMS Parser: No match for line: {line}")
            continue
            
        amount_str = match.group('amount')
        type_str = match.group('type').lower()
        date_str = match.group('date')
        
        try:
            amount = float(amount_str)
        except ValueError:
            continue
            
        is_debit = type_str in ['debited', 'sent', 'paid']
        tx_type = "debit" if is_debit else "credit"
        
        # Simple date parsing
        try:
            # Try YYYY-MM-DD
            if len(date_str) == 10 and date_str[4] in ['-', '/']:
                tx_date = datetime.strptime(date_str.replace('/', '-'), "%Y-%m-%d")
            else:
                tx_date = datetime.strptime(date_str.replace('/', '-'), "%d-%m-%Y")
        except ValueError:
            tx_date = datetime.now() # Fallback
            
        # For SMS, we use the raw line as the description
        description = line[:100] # Truncate if too long
        
        fingerprint = build_transaction_fingerprint(
            account_id,
            tx_date.date(),
            amount,
            tx_type,
            description,
        )
        is_dup_in_batch = fingerprint in seen_in_batch
        seen_in_batch.add(fingerprint)
        duplicate_status, _ = await classify_duplicate(
            db,
            user_id=user_id,
            account_id=account_id,
            transaction_date=tx_date.date(),
            amount=amount,
            transaction_type=tx_type,
            description=description,
            fingerprint=fingerprint,
        )
        is_dup = is_dup_in_batch or duplicate_status == "exact"
        if is_dup:
            duplicates_found += 1
            
        transactions.append(
            SmsTransactionPreview(
                row_index=idx,
                date=tx_date.date(),
                clean_text=description,
                amount=amount,
                type=tx_type,
                is_duplicate=is_dup,
                fingerprint=fingerprint,
            )
        )
        
    return transactions, duplicates_found
