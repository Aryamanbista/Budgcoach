import re
import logging
from datetime import datetime, timedelta
from decimal import Decimal
from typing import List, Tuple
from sqlalchemy.orm import Session
from uuid import UUID

from app.models.transaction import Transaction
from app.schemas.upload import ParsedTransactionPreview

logger = logging.getLogger(__name__)

# Basic configurations for regex patterns. 
# In a full production system, these might come from a DB table `parser_configs`.
REGEX_PATTERNS = {
    "esewa": r"(?i)(?P<date>\d{4}[-/]\d{2}[-/]\d{2}[ T]\d{2}:\d{2}:\d{2}).*?(?P<type>debited|credited).*?(?P<amount>\d+\.\d{2})",
    "khalti": r"(?i)(?P<date>\d{4}[-/]\d{2}[-/]\d{2}).*?(?P<type>debited|credited).*?(?P<amount>\d+\.\d{2})",
    "nabil": r"(?i)(?P<date>\d{4}[-/]\d{2}[-/]\d{2}).*?(?P<type>dr|cr)\s+(?P<amount>\d+(?:\.\d{2})?)",
    "sunrise": r"(?i)(?P<date>\d{4}[-/]\d{2}[-/]\d{2}).*?(?P<type>dr|cr)\s+(?P<amount>\d+(?:\.\d{2})?)",
    "himalayan": r"(?i)(?P<date>\d{2}/\d{2}/\d{4}).*?(?P<type>withdrawal|deposit).*?(?P<amount>\d+(?:\.\d{2})?)"
}

def normalize_type(raw_type: str) -> str:
    val = raw_type.lower()
    if val in ['debited', 'dr', 'withdrawal']:
        return 'debit'
    if val in ['credited', 'cr', 'deposit']:
        return 'credit'
    return 'debit'

def parse_date(raw_date: str) -> datetime:
    # Attempt to parse common date formats
    formats = [
        "%Y-%m-%d %H:%M:%S",
        "%Y/%m/%d %H:%M:%S",
        "%Y-%m-%dT%H:%M:%S",
        "%Y-%m-%d",
        "%Y/%m/%d",
        "%d/%m/%Y"
    ]
    for fmt in formats:
        try:
            return datetime.strptime(raw_date, fmt)
        except ValueError:
            continue
    return datetime.now()  # Fallback

def check_duplicate(db: Session, user_id: UUID, account_id: UUID, amount: Decimal, tx_date: datetime) -> bool:
    """
    Idempotency & Duplicate detection layer:
    Checks if a transaction with the same amount, user, and account 
    exists within a 60-second window.
    """
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

def parse_transactions(text: str, wallet_type: str, user_id: UUID, account_id: UUID, db: Session) -> Tuple[List[ParsedTransactionPreview], int]:
    """
    Parses OCR'd text using regex mappings, checks for duplicates, and returns structured data.
    """
    wallet_key = wallet_type.lower()
    pattern_str = REGEX_PATTERNS.get(wallet_key)
    
    if not pattern_str:
        # Fallback to a generic regex if wallet not recognized
        pattern_str = r"(?i)(?P<date>\d{4}-\d{2}-\d{2}).*?(?P<type>dr|cr|debited|credited)\s+(?P<amount>\d+(?:\.\d{2})?)"
        logger.warning(f"Wallet type {wallet_type} unrecognized. Using generic fallback regex.")

    pattern = re.compile(pattern_str)
    
    transactions = []
    duplicates_found = 0
    
    # We can match line by line or find all across the text
    for line in text.split('\n'):
        line = line.strip()
        if not line:
            continue
            
        match = pattern.search(line)
        if match:
            try:
                raw_date = match.group('date')
                raw_type = match.group('type')
                raw_amount = match.group('amount')
                
                tx_date = parse_date(raw_date)
                tx_type = normalize_type(raw_type)
                tx_amount = Decimal(raw_amount)
                
                # Deduplication check
                is_duplicate = check_duplicate(db, user_id, account_id, tx_amount, tx_date)
                if is_duplicate:
                    duplicates_found += 1
                
                preview = ParsedTransactionPreview(
                    date=tx_date.date(),
                    type=tx_type,
                    amount=tx_amount,
                    clean_text=line,
                    is_duplicate=is_duplicate
                )
                transactions.append(preview)
            except Exception as e:
                logger.error(f"Failed to parse line '{line}': {e}")
                continue

    return transactions, duplicates_found
