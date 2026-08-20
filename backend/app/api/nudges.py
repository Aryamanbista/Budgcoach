from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
import datetime
from app.api.auth import get_current_user
from app.core.database import get_db
from app.models.user import User
from app.models.transaction import Transaction
from app.models.budget import Budget
from app.models.savings_goal import SavingsGoal

router = APIRouter()

@router.get("/")
async def get_nudges(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Returns algorithmic nudges based on recent activity.
    """
    nudges = []
    
    # 1. Budget Overspend Nudge
    stmt_budget = select(Budget).where(Budget.user_id == current_user.id)
    budgets = (await db.execute(stmt_budget)).scalars().all()
    
    for b in budgets:
        if b.amount > 0 and b.spent >= b.amount:
            nudges.append({
                "type": "warning",
                "title": f"Budget Exceeded",
                "message": f"You've exceeded your budget for {b.category.name if b.category else 'a category'}."
            })
        elif b.amount > 0 and b.spent >= b.amount * 0.8:
            nudges.append({
                "type": "alert",
                "title": f"Approaching Budget Limit",
                "message": f"You've spent 80% of your budget for {b.category.name if b.category else 'a category'}."
            })
            
    # 2. Positive Reinforcement (Savings Goal)
    stmt_goal = select(SavingsGoal).where(SavingsGoal.user_id == current_user.id)
    goals = (await db.execute(stmt_goal)).scalars().all()
    
    for g in goals:
        if g.current_amount >= g.target_amount:
            nudges.append({
                "type": "success",
                "title": "Goal Achieved!",
                "message": f"Congratulations! You reached your goal: {g.name}."
            })
            
    # 3. Weekly Spike Nudge
    seven_days_ago = datetime.datetime.now() - datetime.timedelta(days=7)
    stmt_tx = select(func.sum(Transaction.amount)).where(
        Transaction.user_id == current_user.id,
        Transaction.type == "debit",
        Transaction.transaction_date >= seven_days_ago
    )
    weekly_spend = (await db.execute(stmt_tx)).scalar() or 0
    
    if weekly_spend > 20000: # Arbitrary high spend threshold
        nudges.append({
            "type": "info",
            "title": "High Weekly Spend",
            "message": f"You've spent {weekly_spend} this week. Consider reviewing your transactions."
        })
        
    # Default nudge if none triggered
    if not nudges:
        nudges.append({
            "type": "info",
            "title": "On Track",
            "message": "Your finances look stable. Keep up the good work!"
        })
        
    return nudges
