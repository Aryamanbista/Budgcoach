from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from typing import List

from app.core.database import get_db
from app.models.category import Category
from app.schemas.category import CategoryOut

router = APIRouter()

@router.get("/", response_model=List[CategoryOut])
async def list_categories(
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(select(Category))
    categories = result.scalars().all()
    return categories
