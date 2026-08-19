from typing import List, Protocol
from app.schemas.transaction import TransactionRow

class BaseExtractor(Protocol):
    def can_handle(self, filename: str) -> bool:
        ...

    def extract(self, file_path: str) -> List[TransactionRow]:
        ...

class LLMExtractor(BaseExtractor):
    """Stub for future use. Not implemented in this phase."""
    def can_handle(self, filename: str) -> bool:
        return True
        
    def extract(self, file_path: str) -> List[TransactionRow]:
        # To be implemented when Option B is enabled
        return []
