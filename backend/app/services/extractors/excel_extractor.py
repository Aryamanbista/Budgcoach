import csv
import logging
from pathlib import Path
from typing import List

import pandas as pd

from app.schemas.transaction import TransactionRow
from app.services.extractors.base import BaseExtractor
from app.services.parser_service import (
    normalize_headers,
    parse_money,
    transaction_type_from_text,
)

logger = logging.getLogger(__name__)


class ExcelExtractor(BaseExtractor):
    """Extract transactions from spreadsheets with optional preamble rows."""

    def can_handle(self, filename: str) -> bool:
        return Path(filename).suffix.lower() in {".xlsx", ".xls", ".csv"}

    def _read_unheaded(self, file_path: str) -> pd.DataFrame:
        extension = Path(file_path).suffix.lower()
        if extension == ".xlsx":
            return pd.read_excel(file_path, engine="openpyxl", header=None)
        if extension == ".xls":
            return pd.read_excel(file_path, engine="xlrd", header=None)
        with open(file_path, "r", encoding="utf-8-sig", errors="replace") as stream:
            sample = stream.read(4096)
        try:
            delimiter = csv.Sniffer().sniff(sample).delimiter
        except csv.Error:
            delimiter = ","
        return pd.read_csv(
            file_path,
            sep=delimiter,
            header=None,
            encoding="utf-8-sig",
            on_bad_lines="skip",
        )

    @staticmethod
    def _find_header_row(frame: pd.DataFrame) -> int:
        best_index = 0
        best_score = 0
        for index in range(min(len(frame), 30)):
            headers = [str(value) if pd.notna(value) else "" for value in frame.iloc[index]]
            keys = set(normalize_headers(headers))
            score = len(keys) + (2 if "date" in keys else 0)
            if ("debit" in keys and "credit" in keys) or "amount" in keys:
                score += 2
            if score > best_score:
                best_index, best_score = index, score
        if best_score < 4:
            raise ValueError("Could not identify a transaction header row.")
        return best_index

    def extract(self, file_path: str) -> List[TransactionRow]:
        try:
            raw_frame = self._read_unheaded(file_path).dropna(how="all")
            if raw_frame.empty:
                return []
            header_index = self._find_header_row(raw_frame)
            headers = [
                str(value).strip() if pd.notna(value) else f"column_{column}"
                for column, value in enumerate(raw_frame.iloc[header_index])
            ]
            frame = raw_frame.iloc[header_index + 1 :].copy()
            frame.columns = headers
            frame = frame.dropna(how="all")
            header_map = normalize_headers(headers)

            rows: List[TransactionRow] = []
            for _, record in frame.iterrows():
                values = record.to_dict()
                date_value = values.get(header_map.get("date"))
                description_value = values.get(header_map.get("description"))
                debit = parse_money(values.get(header_map.get("debit")))
                credit = parse_money(values.get(header_map.get("credit")))

                if debit is None and credit is None and "amount" in header_map:
                    amount = parse_money(values.get(header_map["amount"]))
                    transaction_type = transaction_type_from_text(
                        values.get(header_map.get("type"))
                    )
                    if amount is not None and transaction_type == "debit":
                        debit = abs(amount)
                    elif amount is not None and transaction_type == "credit":
                        credit = abs(amount)

                date_text = "" if pd.isna(date_value) else str(date_value).strip()
                description = (
                    "" if pd.isna(description_value) else str(description_value).strip()
                )
                if not date_text and debit is None and credit is None:
                    if description and rows:
                        rows[-1].description = (
                            f"{rows[-1].description or ''} {description}"
                        ).strip()
                    continue
                if not date_text or (debit is None and credit is None):
                    continue

                raw_line = " | ".join(
                    f"{key}: {value}"
                    for key, value in values.items()
                    if pd.notna(value) and str(value).strip()
                )
                rows.append(
                    TransactionRow(
                        date=date_text,
                        description=description,
                        debit=abs(debit) if debit is not None else None,
                        credit=abs(credit) if credit is not None else None,
                        balance=parse_money(values.get(header_map.get("balance"))),
                        raw_text=raw_line,
                        source_format="excel",
                        confidence=0.98,
                    )
                )
            return rows
        except Exception as error:
            logger.exception("Excel extraction failed: %s", error)
            return []
