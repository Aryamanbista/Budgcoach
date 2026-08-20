import calendar
import os
from datetime import date, timedelta
from typing import List

import httpx
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.auth import get_current_user
from app.core.database import get_db
from app.models.budget import Budget
from app.models.category import Category
from app.models.transaction import Transaction
from app.models.user import User
from app.services.history_coverage_service import get_history_coverage
from app.services.festival_calendar_service import FestivalEvent, get_festival_events

router = APIRouter()

ML_ENGINE_URL = os.getenv("ML_ENGINE_URL", "http://localhost:8001")
ML_ENGINE_TIMEOUT_SECONDS = float(os.getenv("ML_ENGINE_TIMEOUT_SECONDS", "45"))
REQUIRED_HISTORY_DAYS = 30
HISTORY_WINDOW_DAYS = 365
LSTM_HISTORY_DAYS = 180


class ForecastPoint(BaseModel):
    date: date
    amount: float


class AIStatus(BaseModel):
    days_logged: int
    required_days: int
    readiness_percentage: float
    active_model: str
    learning_message: str
    coverage_status: str
    is_fresh: bool
    training_days_logged: int
    training_required_days: int
    validation_mae: float | None = None
    selected_via_backtest: bool = False


class ForecastResponse(BaseModel):
    predicted_spend: float
    current_month_spend: float
    total_budget: float
    remaining_budget: float
    budget_breach_warning: bool
    days_until_breach: int
    is_mock: bool
    ai_status: AIStatus
    history_used: List[ForecastPoint]
    forecast: List[ForecastPoint]
    upcoming_festivals: List["FestivalForecastEvent"]


class FestivalForecastEvent(BaseModel):
    date: date
    name: str
    festival_type: str
    is_major: bool


def _daily_series(rows, start_date: date, end_date: date) -> list[ForecastPoint]:
    amounts = {row.date: float(row.total_amount) for row in rows}
    points = []
    current = start_date
    while current <= end_date:
        points.append(ForecastPoint(date=current, amount=amounts.get(current, 0.0)))
        current += timedelta(days=1)
    return points


def _weighted_daily_average(points: list[ForecastPoint]) -> float:
    if not points:
        return 0.0

    recent = points[-14:]
    weights = list(range(1, len(recent) + 1))
    weighted_total = sum(
        point.amount * weight for point, weight in zip(recent, weights)
    )
    return weighted_total / sum(weights)


def _cumulative_history(points: list[ForecastPoint]) -> list[ForecastPoint]:
    running_total = 0.0
    cumulative = []
    for point in points:
        running_total += point.amount
        cumulative.append(ForecastPoint(date=point.date, amount=round(running_total, 2)))
    return cumulative


def _future_projection(
    today: date,
    current_spend: float,
    projected_spend: float,
) -> list[ForecastPoint]:
    if current_spend <= 0 and projected_spend <= 0:
        return []

    final_day = calendar.monthrange(today.year, today.month)[1]
    remaining_days = final_day - today.day
    if remaining_days <= 0:
        return []

    remaining_spend = max(0.0, projected_spend - current_spend)
    daily_increment = remaining_spend / remaining_days
    running_total = current_spend
    points = []
    for offset in range(1, remaining_days + 1):
        running_total += daily_increment
        points.append(
            ForecastPoint(
                date=today + timedelta(days=offset),
                amount=round(running_total, 2),
            )
        )
    return points


async def _ml_projection(
    history: list[ForecastPoint],
    horizon_days: int = 30,
    profile_id: str = "anonymous",
) -> tuple[float, str, tuple[FestivalEvent, ...], dict] | None:
    if not history:
        return None
    festivals = await get_festival_events(
        history[0].date,
        date.today() + timedelta(days=horizon_days),
    )
    payload = {
        "history": [point.model_dump(mode="json") for point in history[-365:]],
        "profile_id": profile_id,
        "forecast_days": horizon_days,
        "festivals": [
            {
                "date": event.date.isoformat(),
                "name": event.name,
                "festival_type": event.festival_type,
                "is_major": event.is_major,
            }
            for event in festivals
        ],
    }
    try:
        async with httpx.AsyncClient(timeout=ML_ENGINE_TIMEOUT_SECONDS) as client:
            response = await client.post(
                f"{ML_ENGINE_URL}/api/v1/forecast",
                json=payload,
            )
            response.raise_for_status()
        body = response.json()
        predicted = max(0.0, float(body["predicted_spend"]))
        active_model = body.get("ai_status", {}).get(
            "active_model",
            "lstm_network",
        )
        return predicted, active_model, festivals, body.get("ai_status", {})
    except (httpx.HTTPError, KeyError, TypeError, ValueError):
        return None


@router.get("/", response_model=ForecastResponse)
async def get_forecast(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    today = date.today()
    history_start = today - timedelta(days=HISTORY_WINDOW_DAYS - 1)

    history_query = (
        select(Transaction.date, func.sum(Transaction.amount).label("total_amount"))
        .outerjoin(Category, Transaction.category_id == Category.id)
        .where(
            Transaction.user_id == current_user.id,
            Transaction.type == "debit",
            Transaction.date >= history_start,
            Transaction.date <= today,
            or_(Category.id.is_(None), func.lower(Category.name) != "transfer"),
        )
        .group_by(Transaction.date)
        .order_by(Transaction.date)
    )
    rows = (await db.execute(history_query)).all()
    coverage = await get_history_coverage(db, user_id=current_user.id, today=today)
    days_logged = min(HISTORY_WINDOW_DAYS, coverage.covered_days)

    series_start = coverage.start_date
    if series_start is None and rows:
        series_start = rows[0].date
    daily_history = (
        _daily_series(rows, max(series_start, history_start), today)
        if series_start is not None
        else []
    )

    month_start = today.replace(day=1)
    month_daily = [point for point in daily_history if point.date >= month_start]
    current_month_spend = round(sum(point.amount for point in month_daily), 2)
    daily_average = _weighted_daily_average(daily_history)
    days_in_month = calendar.monthrange(today.year, today.month)[1]
    baseline_projection = current_month_spend + daily_average * (
        days_in_month - today.day
    )

    active_model = "personal_baseline"
    projected_spend = baseline_projection
    upcoming_festivals: tuple[FestivalEvent, ...] = ()
    model_status: dict = {}
    if days_logged >= 3:
        remaining_days = max(1, days_in_month - today.day)
        ml_result = await _ml_projection(
            daily_history,
            remaining_days,
            str(current_user.id),
        )
        if ml_result is not None:
            ml_projection, active_model, festivals, model_status = ml_result
            projected_spend = max(
                current_month_spend,
                current_month_spend + ml_projection,
            )
            upcoming_festivals = tuple(
                event for event in festivals if today < event.date <= today + timedelta(days=remaining_days)
            )

    projected_spend = round(max(current_month_spend, projected_spend), 2)

    month_key = today.strftime("%Y-%m")
    budget_result = await db.execute(
        select(func.sum(Budget.limit_amount)).where(
            Budget.user_id == current_user.id,
            Budget.month_year == month_key,
        )
    )
    total_budget = round(float(budget_result.scalar() or 0.0), 2)
    remaining_budget = round(max(0.0, total_budget - current_month_spend), 2)
    breach = total_budget > 0 and projected_spend > total_budget

    future = _future_projection(today, current_month_spend, projected_spend)
    days_until_breach = 0
    if breach:
        for index, point in enumerate(future, start=1):
            if point.amount >= total_budget:
                days_until_breach = index
                break

    readiness = min(100.0, (days_logged / REQUIRED_HISTORY_DAYS) * 100.0)
    if readiness < 100:
        learning_message = coverage.message
    elif active_model == "lstm_network":
        learning_message = (
            "Your personal AI forecast is active and improves with every transaction."
        )
    else:
        learning_message = (
            f"Your 30-day baseline is ready. Budgcoach is validating a personal "
            f"AI model as more history arrives; the safer {active_model.replace('_', ' ')} remains active."
        )

    return ForecastResponse(
        predicted_spend=projected_spend,
        current_month_spend=current_month_spend,
        total_budget=total_budget,
        remaining_budget=remaining_budget,
        budget_breach_warning=breach,
        days_until_breach=days_until_breach,
        is_mock=False,
        ai_status=AIStatus(
            days_logged=days_logged,
            required_days=REQUIRED_HISTORY_DAYS,
            readiness_percentage=round(readiness, 1),
            active_model=active_model,
            learning_message=learning_message,
            coverage_status=coverage.status,
            is_fresh=coverage.is_fresh,
            training_days_logged=int(model_status.get("days_logged", len(daily_history))),
            training_required_days=int(model_status.get("minimum_lstm_days", LSTM_HISTORY_DAYS)),
            validation_mae=model_status.get("validation_mae"),
            selected_via_backtest=bool(model_status.get("selected_via_backtest", False)),
        ),
        history_used=_cumulative_history(month_daily),
        forecast=future,
        upcoming_festivals=[
            FestivalForecastEvent(
                date=event.date,
                name=event.name,
                festival_type=event.festival_type,
                is_major=event.is_major,
            )
            for event in upcoming_festivals
        ],
    )
