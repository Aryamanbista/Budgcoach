import re
import logging
from decimal import Decimal, InvalidOperation
from typing import List, Dict, Any, Optional

from app.schemas.transaction import TransactionRow

logger = logging.getLogger(__name__)

HEADER_ALIASES = {
    "date": ["date", "txn date", "value date", "posting date", "transaction date", "ansaction date"],
    "description": ["description", "narration", "particulars", "details", "remarks", "transaction details", "merchant", "escription"],
    "debit": ["debit", "withdrawal", "withdrawals", "dr", "debit amount", "paid out"],
    "credit": ["credit", "deposit", "deposits", "cr", "credit amount", "paid in"],
    "amount": ["amount", "transaction amount", "txn amount"],
    "type": ["type", "transaction type", "txn type", "dr/cr", "debit/credit"],
    "balance": ["balance", "closing balance", "running balance", "available balance"],
}

DATE_PATTERN = re.compile(
    r"(?<!\d)(?:\d{4}[-/.]\d{1,2}[-/.]\d{1,2}|\d{1,2}[-/.]\d{1,2}[-/.]\d{2,4}|\d{1,2}\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{2,4})(?!\d)",
    re.IGNORECASE,
)
TYPE_PATTERN = re.compile(
    r"\b(?P<type>dr|cr|debit(?:ed)?|credit(?:ed)?|withdraw(?:al|n)?|deposit(?:ed)?|sent|received|paid|purchase|refund(?:ed)?|cash\s+out|cash\s+in)\b",
    re.IGNORECASE,
)
MONEY_PATTERN = re.compile(
    r"(?<![\w./-])(?:NPR|NRs?\.?|Rs\.?)?\s*(?P<amount>\(?-?\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?\)?|-?\d+(?:\.\d{1,2})?)(?![\w./-])",
    re.IGNORECASE,
)

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
            normalized = re.sub(r"\s+", " ", raw.lower().replace("\n", " ")).strip(" :._-")
            if normalized in aliases or any(
                len(alias) >= 5 and alias in normalized for alias in aliases
            ):
                mapping[standard_key] = raw
                break
    return mapping


def parse_money(value: Any) -> Optional[float]:
    """Parse common NPR statement amounts without accepting arbitrary text."""
    if value is None:
        return None
    text = str(value).strip()
    if not text or text.lower() in {"nan", "none", "-", "--"}:
        return None
    negative = text.startswith("(") and text.endswith(")")
    cleaned = re.sub(r"(?i)\b(?:npr|nrs|rs)\.?\b", "", text)
    cleaned = cleaned.replace(",", "").replace(" ", "").strip("()")
    cleaned = re.sub(r"(?i)(?:dr|cr)$", "", cleaned)
    try:
        amount = Decimal(cleaned)
    except (InvalidOperation, ValueError):
        return None
    return float(-amount if negative else amount)


def transaction_type_from_text(value: Any) -> Optional[str]:
    match = TYPE_PATTERN.search(str(value or ""))
    if not match:
        return None
    token = re.sub(r"\s+", " ", match.group("type").lower())
    if token in {"cr", "credit", "credited", "deposit", "deposited", "received", "refund", "refunded", "cash in"}:
        return "credit"
    return "debit"

def regex_fallback(raw_text: str) -> Optional[TransactionRow]:
    """
    Used only when structured extraction completely fails (e.g., OCR fallback).
    Tries a generic regex to pull date, amount, and type.
    """
    date_match = DATE_PATTERN.search(raw_text)
    type_match = TYPE_PATTERN.search(raw_text)
    if not date_match or not type_match:
        return None

    candidates = []
    for money_match in MONEY_PATTERN.finditer(raw_text):
        # Dates contain number-like fragments; ignore anything overlapping the date.
        if money_match.start() < date_match.end() and money_match.end() > date_match.start():
            continue
        amount = parse_money(money_match.group("amount"))
        if amount is None or amount == 0:
            continue
        distance = min(
            abs(money_match.start() - type_match.end()),
            abs(type_match.start() - money_match.end()),
        )
        has_currency = bool(re.search(r"(?i)(?:NPR|NRs?\.?|Rs\.?)", money_match.group(0)))
        candidates.append((0 if has_currency else 1, distance, money_match, abs(amount)))
    if not candidates:
        return None
    _, _, amount_match, amount = min(candidates, key=lambda item: (item[0], item[1]))

    date_str = date_match.group(0)
    transaction_type = transaction_type_from_text(type_match.group(0))
    if transaction_type is None:
        return None

    description = raw_text
    for match in sorted([date_match, type_match, amount_match], key=lambda item: item.start(), reverse=True):
        description = description[:match.start()] + " " + description[match.end():]
    description = re.sub(r"\s+", " ", description).strip(" |-:") or "Imported transaction"
    
    row = TransactionRow(
        date=date_str,
        description=description[:300],
        raw_text=raw_text,
        source_format="image_ocr",
        confidence=0.5
    )
    
    if transaction_type == "debit":
        row.debit = amount
    else:
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
        r"(?i)(?:rs\.?|npr|nrs\.?)\s*(?P<amount>\d[\d,]*(?:\.\d{1,2})?)\s+(?P<type>debited|credited|sent|received|paid|withdrawn|deposited).*?(?P<date>\d{4}[-/]\d{1,2}[-/]\d{1,2}|\d{1,2}[-/]\d{1,2}[-/]\d{2,4}|\d{1,2}[- ](?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*[- ]\d{2,4})"
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
            amount = float(amount_str.replace(",", ""))
        except ValueError:
            continue
            
        is_debit = type_str in ['debited', 'sent', 'paid', 'withdrawn']
        tx_type = "debit" if is_debit else "credit"
        
        # Simple date parsing
        try:
            # Try YYYY-MM-DD
            if len(date_str) == 10 and date_str[4] in ['-', '/']:
                tx_date = datetime.strptime(date_str.replace('/', '-'), "%Y-%m-%d")
            elif len(date_str) >= 8 and date_str[2] in ['-', '/'] and date_str[5] in ['-', '/']:
                numeric_format = "%d-%m-%Y" if len(date_str) == 10 else "%d-%m-%y"
                tx_date = datetime.strptime(date_str.replace('/', '-'), numeric_format)
            else:
                tx_date = datetime.strptime(date_str.replace("-", " "), "%d %b %y")
        except ValueError:
            logger.warning("SMS Parser: invalid transaction date: %s", date_str)
            continue
            
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
