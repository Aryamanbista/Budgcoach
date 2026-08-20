from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.api.auth import get_current_user
from app.core.database import get_db
from app.models.user import User
from app.services.health_score_service import compute_health_score

router = APIRouter()

@router.get("/")
async def get_health_score(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Returns the user's financial health score.
    """
    score_data = await compute_health_score(db, current_user.id)
    return score_data
