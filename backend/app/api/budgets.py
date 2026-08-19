from typing import List, Optional
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from app.api.auth import get_current_user
from app.core.database import get_db
from app.models.user import User
from app.models.category import Category
from app.models.budget import Budget
from app.schemas.budget import BudgetCreate, BudgetUpdate, BudgetOut

router = APIRouter()

@router.post("/", response_model=BudgetOut, status_code=status.HTTP_201_CREATED)
async def create_budget(
    payload: BudgetCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    # 1. Validate category exists
    result_cat = await db.execute(select(Category).filter(Category.id == payload.category_id))
    category = result_cat.scalars().first()
    if not category:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Category not found."
        )
        
    # 2. Check if a budget already exists for this category, month_year and user
    result_ex = await db.execute(select(Budget).filter(
        Budget.user_id == current_user.id,
        Budget.category_id == payload.category_id,
        Budget.month_year == payload.month_year
    ))
    existing_budget = result_ex.scalars().first()
    if existing_budget:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="A budget for this category and month/year already exists."
        )
        
    db_budget = Budget(
        user_id=current_user.id,
        category_id=payload.category_id,
        limit_amount=payload.limit_amount,
        spent_amount=payload.spent_amount,
        month_year=payload.month_year
    )
    db.add(db_budget)
    await db.commit()
    await db.refresh(db_budget)
    return db_budget

@router.get("/", response_model=List[BudgetOut])
async def get_budgets(
    month_year: Optional[str] = Query(None),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    query = select(Budget).filter(Budget.user_id == current_user.id)
    if month_year:
        query = query.filter(Budget.month_year == month_year)
    result = await db.execute(query)
    return result.scalars().all()

@router.patch("/{budget_id}", response_model=BudgetOut)
async def update_budget(
    budget_id: UUID,
    payload: BudgetUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(select(Budget).filter(
        Budget.id == budget_id,
        Budget.user_id == current_user.id
    ))
    db_budget = result.scalars().first()
    if not db_budget:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Budget not found or access denied."
        )
        
    if payload.limit_amount is not None:
        db_budget.limit_amount = payload.limit_amount
    if payload.spent_amount is not None:
        db_budget.spent_amount = payload.spent_amount
    if payload.month_year is not None:
        db_budget.month_year = payload.month_year
        
    await db.commit()
    await db.refresh(db_budget)
    return db_budget
