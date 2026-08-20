import datetime
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from app.models.transaction import Transaction
from app.models.budget import Budget
from app.models.savings_goal import SavingsGoal

async def compute_health_score(db: AsyncSession, user_id: str) -> dict:
    """
    Computes a 0-100 financial health score based on:
    1. Savings rate (Income vs Expense) -> 40 points
    2. Budget adherence -> 30 points
    3. Goal progress -> 30 points
    """
    # 1. Savings Rate (last 30 days)
    thirty_days_ago = datetime.datetime.now() - datetime.timedelta(days=30)
    
    stmt = select(Transaction).where(
        Transaction.user_id == user_id,
        Transaction.transaction_date >= thirty_days_ago
    )
    result = await db.execute(stmt)
    txs = result.scalars().all()
    
    total_income = sum(t.amount for t in txs if t.type == "credit")
    total_expense = sum(t.amount for t in txs if t.type == "debit")
    
    savings_score = 0
    if total_income > 0:
        savings_rate = (float(total_income) - float(total_expense)) / float(total_income)
        if savings_rate >= 0.20:
            savings_score = 40
        elif savings_rate > 0:
            savings_score = int((savings_rate / 0.20) * 40)
    else:
        # No income, if also no expense, neutral. If expense, bad.
        if total_expense == 0:
            savings_score = 20
        else:
            savings_score = 0
            
    # 2. Budget adherence
    stmt_budget = select(Budget).where(Budget.user_id == user_id)
    budgets = (await db.execute(stmt_budget)).scalars().all()
    
    budget_score = 0
    if not budgets:
        budget_score = 15 # Neutral if no budgets set
    else:
        adherence_sum = 0
        for b in budgets:
            ratio = float(b.spent) / float(b.amount) if b.amount > 0 else 1.0
            if ratio <= 0.8:
                adherence_sum += 1.0
            elif ratio <= 1.0:
                adherence_sum += 0.5
            else:
                adherence_sum += 0.0
        budget_score = int((adherence_sum / len(budgets)) * 30)
        
    # 3. Goal progress
    stmt_goal = select(SavingsGoal).where(SavingsGoal.user_id == user_id)
    goals = (await db.execute(stmt_goal)).scalars().all()
    
    goal_score = 0
    if not goals:
        goal_score = 15 # Neutral if no goals set
    else:
        progress_sum = 0
        for g in goals:
            ratio = float(g.current_amount) / float(g.target_amount) if g.target_amount > 0 else 0
            # A healthy goal progress depends on deadline, but simple ratio is okay for now
            if ratio >= 0.5:
                progress_sum += 1.0
            elif ratio >= 0.1:
                progress_sum += 0.5
        goal_score = int((progress_sum / len(goals)) * 30)
        
    total_score = savings_score + budget_score + goal_score
    
    return {
        "score": total_score,
        "breakdown": {
            "savings": savings_score,
            "budget": budget_score,
            "goals": goal_score
        }
    }
