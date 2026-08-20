import io
import zipfile
from pathlib import Path


class InvalidStatementFile(ValueError):
    pass


def validate_statement_file(file_bytes: bytes, filename: str) -> str:
    """Validate file content rather than trusting a user-controlled extension."""
    extension = Path(filename).suffix.lower().lstrip(".")
    if extension == "pdf":
        if not file_bytes.startswith(b"%PDF-"):
            raise InvalidStatementFile("The file content is not a valid PDF.")
    elif extension == "png":
        if not file_bytes.startswith(b"\x89PNG\r\n\x1a\n"):
            raise InvalidStatementFile("The file content is not a valid PNG image.")
    elif extension in {"jpg", "jpeg"}:
        if not (file_bytes.startswith(b"\xff\xd8\xff") and file_bytes.rstrip().endswith(b"\xff\xd9")):
            raise InvalidStatementFile("The file content is not a valid JPEG image.")
    elif extension == "xls":
        if not file_bytes.startswith(b"\xd0\xcf\x11\xe0\xa1\xb1\x1a\xe1"):
            raise InvalidStatementFile("The file content is not a valid XLS workbook.")
    elif extension == "xlsx":
        try:
            with zipfile.ZipFile(io.BytesIO(file_bytes)) as workbook:
                names = workbook.namelist()
                if "[Content_Types].xml" not in names or not any(
                    name.startswith("xl/") for name in names
                ):
                    raise InvalidStatementFile("The file content is not a valid XLSX workbook.")
                if len(names) > 500 or sum(item.file_size for item in workbook.infolist()) > 100 * 1024 * 1024:
                    raise InvalidStatementFile("The XLSX workbook expands beyond the safe processing limit.")
        except zipfile.BadZipFile as error:
            raise InvalidStatementFile("The file content is not a valid XLSX workbook.") from error
    elif extension == "csv":
        if b"\x00" in file_bytes[:8192]:
            raise InvalidStatementFile("The CSV contains binary data.")
        try:
            file_bytes[:65536].decode("utf-8-sig")
        except UnicodeDecodeError as error:
            raise InvalidStatementFile("CSV files must use UTF-8 text encoding.") from error
    else:
        raise InvalidStatementFile("Unsupported statement format.")
    return extension
