import os
import httpx
from datetime import date, timedelta
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import func
from pydantic import BaseModel

from app.api.auth import get_current_user
from app.core.database import get_db
from app.models.user import User
from app.models.transaction import Transaction
from app.models.budget import Budget

router = APIRouter()

class ForecastResponse(BaseModel):
    predicted_spend: float
    budget_breach_warning: bool
    days_until_breach: int
    is_mock: bool
    ai_status: str
    days_logged: int

ML_ENGINE_URL = os.getenv("ML_ENGINE_URL", "http://localhost:8001")

@router.get("/", response_model=ForecastResponse)
async def get_forecast(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    # 1. Fetch 30-day historical data
    thirty_days_ago = date.today() - timedelta(days=30)
    
    query = select(
        Transaction.date,
        func.sum(Transaction.amount).label("total_amount")
    ).filter(
        Transaction.user_id == current_user.id,
        Transaction.date >= thirty_days_ago
    ).group_by(
        Transaction.date
    ).order_by(
        Transaction.date
    )
    
    result = await db.execute(query)
    rows = result.all()
    
    history_payload = []
    total_spent = 0.0
    for r in rows:
        amount = float(r.total_amount)
        history_payload.append({
            "date": r.date.isoformat(),
            "amount": amount
        })
        total_spent += amount
        
    days_logged = len(history_payload)
    
    # 2. Fetch current month budget
    current_month_str = date.today().strftime("%Y-%m")
    budget_query = select(func.sum(Budget.limit_amount)).filter(
        Budget.user_id == current_user.id,
        Budget.month_year == current_month_str
    )
    budget_result = await db.execute(budget_query)
    total_budget = budget_result.scalar() or 0.0
    
    # 3. Determine fallback / logic
    if days_logged < 14:
        # Rule-based fallback
        daily_avg = (total_spent / days_logged) if days_logged > 0 else 0.0
        predicted_spend = daily_avg * 30
        ai_status = "Insufficient data. Using rule-based fallback."
        is_mock = False
        
        breach = predicted_spend > float(total_budget) if total_budget > 0 else False
        
        return ForecastResponse(
            predicted_spend=predicted_spend,
            budget_breach_warning=breach,
            days_until_breach=0, # Simplified
            is_mock=is_mock,
            ai_status=ai_status,
            days_logged=days_logged
        )
    
    # 4. Request ML engine for prediction
    payload = {"history": history_payload}
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.post(f"{ML_ENGINE_URL}/api/v1/forecast", json=payload)
            response.raise_for_status()
            ml_data = response.json()
            
            predicted = ml_data.get("predicted_spend", 0.0)
            breach = predicted > float(total_budget) if total_budget > 0 else False
            
            return ForecastResponse(
                predicted_spend=predicted,
                budget_breach_warning=breach,
                days_until_breach=ml_data.get("days_until_breach", 0),
                is_mock=ml_data.get("is_mock", False),
                ai_status="LSTM model execution successful.",
                days_logged=days_logged
            )
            
    except httpx.RequestError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Error communicating with ML Engine: {exc}"
        )
