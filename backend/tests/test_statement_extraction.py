from pathlib import Path

import pytest

from app.services.extractors.excel_extractor import ExcelExtractor
from app.services.file_validation_service import (
    InvalidStatementFile,
    validate_statement_file,
)
from app.services.parser_service import regex_fallback


@pytest.mark.parametrize(
    ("line", "kind", "amount"),
    [
        ("2026-08-18 Fonepay QR Himalayan Java DR NPR 1,250.00 Bal 25,000", "debit", 1250),
        ("18/08/2026 NPR 5,500.00 credited Salary payment", "credit", 5500),
        ("18 Aug 2026 eSewa transfer Rs. 750.50 sent successfully", "debit", 750.50),
        ("Khalti refund received 2026/08/18 NPR 300.00", "credit", 300),
    ],
)
def test_regex_fallback_handles_multiple_statement_layouts(line, kind, amount):
    row = regex_fallback(line)
    assert row is not None
    assert (row.debit if kind == "debit" else row.credit) == amount
    assert row.description != "Parsed via Regex Fallback"


def test_csv_extractor_finds_header_after_account_preamble(tmp_path: Path):
    statement = tmp_path / "statement.csv"
    statement.write_text(
        "Account Statement,,,,\n"
        "Account,001234,,,,\n"
        "Transaction Date,Particulars,Withdrawal,Deposit,Balance\n"
        "2026-08-18,Fonepay QR,1250,,25000\n"
        "2026-08-19,Salary,,5500,30500\n",
        encoding="utf-8",
    )
    rows = ExcelExtractor().extract(str(statement))
    assert len(rows) == 2
    assert rows[0].debit == 1250
    assert rows[1].credit == 5500


def test_csv_extractor_supports_amount_and_type_columns(tmp_path: Path):
    statement = tmp_path / "wallet.csv"
    statement.write_text(
        "Date,Merchant,Amount,Transaction Type\n"
        "18/08/2026,NEA,850.00,Paid\n"
        "19/08/2026,Refund,125.00,Received\n",
        encoding="utf-8",
    )
    rows = ExcelExtractor().extract(str(statement))
    assert rows[0].debit == 850
    assert rows[1].credit == 125


def test_file_validation_rejects_extension_spoofing():
    with pytest.raises(InvalidStatementFile):
        validate_statement_file(b"not a real statement", "statement.pdf")


def test_file_validation_accepts_utf8_csv():
    assert validate_statement_file(b"Date,Amount\n2026-08-18,500\n", "statement.csv") == "csv"
