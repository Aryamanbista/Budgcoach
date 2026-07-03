from typing import List
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.api.auth import get_current_user
from app.core.database import get_db
from app.models.user import User
from app.models.savings_goal import SavingsGoal
from app.schemas.savings_goal import SavingsGoalCreate, SavingsGoalUpdate, SavingsGoalOut

router = APIRouter()

@router.post("/", response_model=SavingsGoalOut, status_code=status.HTTP_201_CREATED)
def create_goal(
    payload: SavingsGoalCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    db_goal = SavingsGoal(
        user_id=current_user.id,
        name=payload.name,
        target_amount=payload.target_amount,
        current_amount=payload.current_amount,
        deadline_date=payload.deadline_date
    )
    db.add(db_goal)
    db.commit()
    db.refresh(db_goal)
    return db_goal

@router.get("/", response_model=List[SavingsGoalOut])
def get_goals(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    return db.query(SavingsGoal).filter(SavingsGoal.user_id == current_user.id).all()

@router.patch("/{goal_id}", response_model=SavingsGoalOut)
def update_goal(
    goal_id: UUID,
    payload: SavingsGoalUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    db_goal = db.query(SavingsGoal).filter(
        SavingsGoal.id == goal_id,
        SavingsGoal.user_id == current_user.id
    ).first()
    if not db_goal:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Savings goal not found or access denied."
        )
        
    if payload.name is not None:
        db_goal.name = payload.name
    if payload.target_amount is not None:
        db_goal.target_amount = payload.target_amount
    if payload.current_amount is not None:
        db_goal.current_amount = payload.current_amount
    if payload.deadline_date is not None:
        db_goal.deadline_date = payload.deadline_date
        
    db.commit()
    db.refresh(db_goal)
    return db_goal
