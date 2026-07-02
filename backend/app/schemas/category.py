from uuid import UUID
from pydantic import BaseModel, field_validator

VALID_CATEGORIES = {
    'Food and Dining',
    'Transport',
    'Utilities',
    'Entertainment',
    'Shopping',
    'Health',
    'Education',
    'Savings',
    'Income',
    'Festival',
    'Transfer',
    'Other'
}

class CategoryBase(BaseModel):
    name: str

    @field_validator('name')
    @classmethod
    def validate_name(cls, v: str) -> str:
        # Standardize matching (e.g., allow matching 'Food & Dining' as 'Food and Dining')
        normalized = v.replace('&', 'and').strip()
        # Capitalize words to match standard formatting
        title_val = " ".join([w.capitalize() if w.lower() != 'and' else 'and' for w in normalized.split()])
        
        if title_val not in VALID_CATEGORIES:
            raise ValueError(
                f"Category name must match one of the 12 standard domains: {sorted(list(VALID_CATEGORIES))}"
            )
        return title_val

class CategoryCreate(CategoryBase):
    pass

class CategoryOut(CategoryBase):
    id: UUID

    class Config:
        from_attributes = True
