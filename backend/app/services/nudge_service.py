import calendar
from dataclasses import dataclass, field
from datetime import date, datetime, time, timedelta, timezone
from decimal import Decimal
from typing import Any, Optional
from uuid import UUID

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.budget import Budget
from app.models.category import Category
from app.models.nudge import Nudge
from app.models.savings_goal import SavingsGoal
from app.models.transaction import Transaction
from app.services.history_coverage_service import get_history_coverage
from app.services.festival_calendar_service import get_festival_events


@dataclass(frozen=True)
class NudgeCandidate:
    key: str
    type: str
    title: str
    message: str
    priority: int
    expires_at: datetime
    category: Optional[str] = None
    action_label: Optional[str] = None
    action_route: Optional[str] = None
    metric_data: dict[str, Any] = field(default_factory=dict)


def _month_expiry(today: date) -> datetime:
    last_day = calendar.monthrange(today.year, today.month)[1]
    return datetime.combine(
        today.replace(day=last_day),
        time.max,
        tzinfo=timezone.utc,
    )


def _week_expiry(today: date) -> datetime:
    days_until_sunday = 6 - today.weekday()
    return datetime.combine(
        today + timedelta(days=days_until_sunday),
        time.max,
        tzinfo=timezone.utc,
    )


def _money(value: Decimal | float) -> str:
    return f"NPR {float(value):,.0f}"


async def _category_spend(
    db: AsyncSession,
    *,
    user_id: UUID,
    start_date: date,
    end_date: date,
) -> dict[UUID, Decimal]:
    result = await db.execute(
        select(
            Transaction.category_id,
            func.sum(Transaction.amount).label("total_amount"),
        )
        .outerjoin(Category, Transaction.category_id == Category.id)
        .where(
            Transaction.user_id == user_id,
            Transaction.type == "debit",
            Transaction.date >= start_date,
            Transaction.date <= end_date,
            or_(Category.id.is_(None), func.lower(Category.name) != "transfer"),
        )
        .group_by(Transaction.category_id)
    )
    return {
        row.category_id: Decimal(row.total_amount or 0)
        for row in result.all()
        if row.category_id is not None
    }


async def _spend_total(
    db: AsyncSession,
    *,
    user_id: UUID,
    start_date: date,
    end_date: date,
) -> Decimal:
    result = await db.execute(
        select(func.sum(Transaction.amount))
        .outerjoin(Category, Transaction.category_id == Category.id)
        .where(
            Transaction.user_id == user_id,
            Transaction.type == "debit",
            Transaction.date >= start_date,
            Transaction.date <= end_date,
            or_(Category.id.is_(None), func.lower(Category.name) != "transfer"),
        )
    )
    return Decimal(result.scalar() or 0)


async def build_personalized_nudges(
    db: AsyncSession,
    *,
    user_id: UUID,
    today: Optional[date] = None,
) -> list[NudgeCandidate]:
    today = today or date.today()
    now = datetime.now(timezone.utc)
    month_start = today.replace(day=1)
    month_key = today.strftime("%Y-%m")
    month_days = calendar.monthrange(today.year, today.month)[1]
    elapsed_ratio = today.day / month_days
    month_expiry = _month_expiry(today)
    candidates: list[NudgeCandidate] = []

    budget_result = await db.execute(
        select(Budget).where(
            Budget.user_id == user_id,
            Budget.month_year == month_key,
        )
    )
    budgets = budget_result.scalars().all()
    spending = await _category_spend(
        db,
        user_id=user_id,
        start_date=month_start,
        end_date=today,
    )

    on_track_count = 0
    for budget in budgets:
        category_name = budget.category.name if budget.category else "this category"
        if category_name.lower() in {"income", "transfer", "savings"}:
            continue

        limit_amount = Decimal(budget.limit_amount)
        if limit_amount <= 0:
            continue
        spent = spending.get(budget.category_id, Decimal("0"))
        usage = float(spent / limit_amount)
        projected = float(spent) / elapsed_ratio if elapsed_ratio > 0 else float(spent)
        metrics = {
            "spent": round(float(spent), 2),
            "limit": round(float(limit_amount), 2),
            "usage_percentage": round(usage * 100, 1),
            "projected_spend": round(projected, 2),
        }

        if spent >= limit_amount:
            candidates.append(
                NudgeCandidate(
                    key=f"budget-exceeded:{budget.id}:{month_key}",
                    type="critical",
                    title=f"{category_name} budget exceeded",
                    message=(
                        f"You have spent {_money(spent)} against a {_money(limit_amount)} "
                        "limit. Pause non-essential spending in this category."
                    ),
                    priority=100,
                    expires_at=month_expiry,
                    category=category_name,
                    action_label="Review budget",
                    action_route="/home/budget",
                    metric_data=metrics,
                )
            )
        elif usage >= 0.80:
            candidates.append(
                NudgeCandidate(
                    key=f"budget-warning:{budget.id}:{month_key}",
                    type="warning",
                    title=f"{category_name} budget is nearly used",
                    message=(
                        f"{usage * 100:.0f}% is already used, leaving "
                        f"{_money(limit_amount - spent)} for the rest of the month."
                    ),
                    priority=80,
                    expires_at=month_expiry,
                    category=category_name,
                    action_label="View transactions",
                    action_route="/home/transactions",
                    metric_data=metrics,
                )
            )
        elif today.day >= 3 and projected > float(limit_amount) * 1.05:
            candidates.append(
                NudgeCandidate(
                    key=f"budget-pace:{budget.id}:{month_key}",
                    type="warning",
                    title=f"{category_name} spending is ahead of pace",
                    message=(
                        f"At your current pace, spending may reach {_money(projected)} "
                        f"against a {_money(limit_amount)} limit."
                    ),
                    priority=70,
                    expires_at=month_expiry,
                    category=category_name,
                    action_label="Review budget",
                    action_route="/home/budget",
                    metric_data=metrics,
                )
            )
        elif today.day >= 10 and usage <= elapsed_ratio * 0.85:
            on_track_count += 1

    if on_track_count > 0:
        candidates.append(
            NudgeCandidate(
                key=f"budgets-on-track:{month_key}",
                type="success",
                title="Your budgets are on track",
                message=(
                    f"You are comfortably on pace in {on_track_count} "
                    f"categor{'y' if on_track_count == 1 else 'ies'}. Keep it going."
                ),
                priority=20,
                expires_at=month_expiry,
                action_label="View budgets",
                action_route="/home/budget",
                metric_data={"on_track_categories": on_track_count},
            )
        )

    current_week_start = today - timedelta(days=6)
    comparison_start = today - timedelta(days=34)
    comparison_end = today - timedelta(days=7)
    current_week_spend = await _spend_total(
        db,
        user_id=user_id,
        start_date=current_week_start,
        end_date=today,
    )
    comparison_spend = await _spend_total(
        db,
        user_id=user_id,
        start_date=comparison_start,
        end_date=comparison_end,
    )
    average_week = comparison_spend / Decimal("4")
    week_key = f"{today.isocalendar().year}-W{today.isocalendar().week:02d}"
    if average_week > 0:
        change = float((current_week_spend - average_week) / average_week)
        weekly_metrics = {
            "current_week_spend": round(float(current_week_spend), 2),
            "historical_weekly_average": round(float(average_week), 2),
            "change_percentage": round(change * 100, 1),
        }
        if change >= 0.25 and current_week_spend - average_week >= Decimal("500"):
            candidates.append(
                NudgeCandidate(
                    key=f"weekly-spike:{week_key}",
                    type="warning",
                    title="Spending is higher than your usual week",
                    message=(
                        f"You spent {_money(current_week_spend)} in the last 7 days, "
                        f"{change * 100:.0f}% above your recent weekly average."
                    ),
                    priority=75,
                    expires_at=_week_expiry(today),
                    action_label="See what changed",
                    action_route="/home/transactions",
                    metric_data=weekly_metrics,
                )
            )
        elif change <= -0.15:
            candidates.append(
                NudgeCandidate(
                    key=f"weekly-improvement:{week_key}",
                    type="success",
                    title="You spent less than usual this week",
                    message=(
                        f"Your last 7 days were {abs(change) * 100:.0f}% below your "
                        "recent weekly average."
                    ),
                    priority=25,
                    expires_at=_week_expiry(today),
                    metric_data=weekly_metrics,
                )
            )

    goals_result = await db.execute(
        select(SavingsGoal).where(SavingsGoal.user_id == user_id)
    )
    for goal in goals_result.scalars().all():
        target = Decimal(goal.target_amount)
        current = Decimal(goal.current_amount)
        if target <= 0:
            continue
        progress = min(1.0, float(current / target))
        goal_metrics = {
            "current_amount": round(float(current), 2),
            "target_amount": round(float(target), 2),
            "progress_percentage": round(progress * 100, 1),
            "days_remaining": (goal.deadline_date - today).days,
        }

        if current >= target:
            candidates.append(
                NudgeCandidate(
                    key=f"goal-achieved:{goal.id}",
                    type="success",
                    title=f"{goal.name} achieved",
                    message=(
                        f"You reached your {_money(target)} target. Celebrate the progress "
                        "and choose your next savings goal."
                    ),
                    priority=40,
                    expires_at=now + timedelta(days=30),
                    action_label="View goal",
                    action_route=f"/savings/{goal.id}",
                    metric_data=goal_metrics,
                )
            )
            continue

        days_remaining = (goal.deadline_date - today).days
        if days_remaining < 0:
            candidates.append(
                NudgeCandidate(
                    key=f"goal-overdue:{goal.id}:{today.strftime('%Y-%m')}",
                    type="critical",
                    title=f"{goal.name} needs a new plan",
                    message=(
                        f"The deadline has passed with {_money(target - current)} remaining. "
                        "Adjust the deadline or contribution amount."
                    ),
                    priority=85,
                    expires_at=month_expiry,
                    action_label="Update goal",
                    action_route=f"/savings/{goal.id}",
                    metric_data=goal_metrics,
                )
            )
        elif days_remaining <= 30:
            weekly_needed = float(target - current) / max(1.0, days_remaining / 7)
            candidates.append(
                NudgeCandidate(
                    key=f"goal-deadline:{goal.id}:{today.strftime('%Y-%m')}",
                    type="info",
                    title=f"{goal.name} deadline is approaching",
                    message=(
                        f"Save about {_money(weekly_needed)} per week to cover the "
                        f"remaining {_money(target - current)}."
                    ),
                    priority=45,
                    expires_at=min(month_expiry, datetime.combine(
                        goal.deadline_date,
                        time.max,
                        tzinfo=timezone.utc,
                    )),
                    action_label="View goal",
                    action_route=f"/savings/{goal.id}",
                    metric_data=goal_metrics,
                )
            )

    coverage = await get_history_coverage(db, user_id=user_id, today=today)
    if not coverage.minimum_met or not coverage.is_fresh:
        candidates.append(
            NudgeCandidate(
                key=(
                    f"data-readiness:{month_key}:{coverage.status}:"
                    f"{coverage.covered_days // 5}:{coverage.is_fresh}"
                ),
                type="info",
                title=(
                    "Refresh your transaction history"
                    if coverage.minimum_met
                    else "Help Budgcoach learn your spending"
                ),
                message=coverage.message,
                priority=35,
                expires_at=month_expiry,
                action_label="Upload statement",
                action_route="/home/upload",
                metric_data={
                    "days_logged": coverage.covered_days,
                    "required_days": coverage.required_days,
                    "readiness_percentage": coverage.readiness_percentage,
                    "coverage_status": coverage.status,
                    "is_fresh": coverage.is_fresh,
                },
            )
        )

    upcoming_events = await get_festival_events(today, today + timedelta(days=21))
    major_event = next(
        (event for event in upcoming_events if event.is_major and event.date >= today),
        None,
    )
    if major_event is not None:
        days_until = (major_event.date - today).days
        candidates.append(
            NudgeCandidate(
                key=f"festival-plan:{major_event.festival_type}:{major_event.date.isoformat()}",
                type="info",
                title=f"Plan ahead for {major_event.name}",
                message=(
                    f"{major_event.name} is in {days_until} day{'s' if days_until != 1 else ''}. "
                    "Your forecast includes this festival window; set or review category budgets now."
                ),
                priority=50,
                expires_at=datetime.combine(
                    major_event.date,
                    time.max,
                    tzinfo=timezone.utc,
                ),
                action_label="Review forecast",
                action_route="/home/forecast",
                metric_data={
                    "festival": major_event.name,
                    "festival_date": major_event.date.isoformat(),
                    "days_until": days_until,
                },
            )
        )

    if not candidates:
        candidates.append(
            NudgeCandidate(
                key=f"all-clear:{today.isoformat()}",
                type="success",
                title="You are on track today",
                message="No unusual spending or budget pressure needs your attention.",
                priority=10,
                expires_at=datetime.combine(today, time.max, tzinfo=timezone.utc),
                metric_data={},
            )
        )

    return sorted(candidates, key=lambda candidate: candidate.priority, reverse=True)[:12]


async def persist_candidates(
    db: AsyncSession,
    *,
    user_id: UUID,
    candidates: list[NudgeCandidate],
) -> list[Nudge]:
    keys = [candidate.key for candidate in candidates]
    existing_result = await db.execute(
        select(Nudge).where(
            Nudge.user_id == user_id,
            Nudge.nudge_key.in_(keys),
        )
    )
    existing = {nudge.nudge_key: nudge for nudge in existing_result.scalars().all()}
    generated_at = datetime.now(timezone.utc)
    rows = []

    for candidate in candidates:
        row = existing.get(candidate.key)
        if row is None:
            row = Nudge(user_id=user_id, nudge_key=candidate.key)
            db.add(row)
            row.generated_at = generated_at
        elif row.dismissed_at is None:
            row.generated_at = generated_at
        row.type = candidate.type
        row.title = candidate.title
        row.message = candidate.message
        row.category = candidate.category
        row.action_label = candidate.action_label
        row.action_route = candidate.action_route
        row.priority = candidate.priority
        row.metric_data = candidate.metric_data
        row.expires_at = candidate.expires_at
        rows.append(row)

    await db.commit()
    return rows
