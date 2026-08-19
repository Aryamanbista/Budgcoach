import re
import logging
from typing import List, Dict, Any, Optional

from app.schemas.transaction import TransactionRow

logger = logging.getLogger(__name__)

HEADER_ALIASES = {
    "date":        ["date", "txn date", "value date", "posting date", "transaction date"],
    "description": ["description", "narration", "particulars", "details", "remarks"],
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

def check_duplicate(db, user_id, account_id, amount, tx_date) -> bool:
    """
    Idempotency & Duplicate detection layer:
    Checks if a transaction with the same amount, user, and account 
    exists within a 60-second window.
    """
    from app.models.transaction import Transaction
    from datetime import timedelta
    
    window_start = tx_date - timedelta(seconds=60)
    window_end = tx_date + timedelta(seconds=60)
    
    existing = db.query(Transaction).filter(
        Transaction.user_id == user_id,
        Transaction.account_id == account_id,
        Transaction.amount == amount,
        Transaction.transaction_date >= window_start,
        Transaction.transaction_date <= window_end
    ).first()
    
    return existing is not None
