from dataclasses import dataclass
from datetime import date, timedelta
import logging

import numpy as np

MINIMUM_PERSONAL_TRAINING_DAYS = 180
logger = logging.getLogger(__name__)

@dataclass(frozen=True)
class ForecastResult:
    future_daily_spend: tuple[float, ...]
    active_model: str
    validation_mae: float | None
    selected_via_backtest: bool
    minimum_lstm_days: int

    @property
    def total(self) -> float:
        return float(sum(self.future_daily_spend))


def _weighted_average(values: list[float], window: int = 14) -> float:
    recent = values[-window:]
    if not recent:
        return 0.0
    weights = np.arange(1, len(recent) + 1, dtype=float)
    return float(np.average(np.asarray(recent), weights=weights))


def _festival_multiplier(
    history: list[dict],
    festival_dates: set[date],
) -> float:
    festival_values = [
        max(0.0, float(item["amount"]))
        for item in history
        if date.fromisoformat(str(item["date"])[:10]) in festival_dates
    ]
    ordinary_values = [
        max(0.0, float(item["amount"]))
        for item in history
        if date.fromisoformat(str(item["date"])[:10]) not in festival_dates
    ]
    if len(festival_values) >= 3 and ordinary_values:
        ordinary = max(1.0, float(np.median(ordinary_values)))
        return min(3.0, max(0.8, float(np.mean(festival_values)) / ordinary))
    return 1.12


def _apply_calendar(
    predictions: np.ndarray,
    last_date: date,
    festival_dates: set[date],
    multiplier: float,
) -> np.ndarray:
    adjusted = np.maximum(0.0, predictions.astype(float))
    for offset in range(len(adjusted)):
        if last_date + timedelta(days=offset + 1) in festival_dates:
            adjusted[offset] *= multiplier
    return adjusted


def _arima_predictions(values: list[float], steps: int) -> np.ndarray:
    from statsmodels.tsa.arima.model import ARIMA

    order = (2, 1, 2) if len(values) >= 60 else (1, 1, 1)
    fitted = ARIMA(values, order=order).fit()
    return np.maximum(0.0, np.asarray(fitted.forecast(steps=steps), dtype=float))


def _backtest_mae(values: list[float], method: str) -> float:
    holdout = min(28, max(7, len(values) // 5))
    train = values[:-holdout]
    actual = np.asarray(values[-holdout:], dtype=float)
    if method == "arima":
        predicted = _arima_predictions(train, holdout)
    else:
        predicted = np.repeat(_weighted_average(train), holdout)
    return float(np.mean(np.abs(actual - predicted)))


def forecast_personal_spend(
    *,
    profile_id: str,
    history: list[dict],
    festivals: list[dict],
    horizon_days: int,
) -> ForecastResult:
    ordered = sorted(history, key=lambda item: str(item["date"]))
    values = [max(0.0, float(item["amount"])) for item in ordered]
    if not values or horizon_days <= 0:
        return ForecastResult((), "personal_baseline", None, False, MINIMUM_PERSONAL_TRAINING_DAYS)

    festival_dates = {
        date.fromisoformat(str(item["date"])[:10]) for item in festivals
    }
    last_date = date.fromisoformat(str(ordered[-1]["date"])[:10])
    multiplier = _festival_multiplier(ordered, festival_dates)
    baseline = _apply_calendar(
        np.repeat(_weighted_average(values), horizon_days),
        last_date,
        festival_dates,
        multiplier,
    )

    if len(values) < 7:
        return ForecastResult(
            tuple(float(value) for value in baseline),
            "personal_baseline",
            None,
            False,
            MINIMUM_PERSONAL_TRAINING_DAYS,
        )

    baseline_mae = _backtest_mae(values, "baseline")
    try:
        arima = _apply_calendar(
            _arima_predictions(values, horizon_days),
            last_date,
            festival_dates,
            multiplier,
        )
        arima_mae = _backtest_mae(values, "arima")
    except Exception:
        logger.exception("ARIMA forecast failed; retaining the personal baseline.")
        arima = baseline
        arima_mae = float("inf")

    selected = arima if arima_mae <= baseline_mae else baseline
    selected_name = "arima_baseline" if arima_mae <= baseline_mae else "personal_baseline"
    selected_mae = min(arima_mae, baseline_mae)

    if len(values) >= MINIMUM_PERSONAL_TRAINING_DAYS:
        try:
            from inference_service import (
                forecast_with_personalized_lstm,
                train_personalized_lstm,
            )

            personal_model = train_personalized_lstm(
                profile_id,
                ordered,
                festival_dates,
            )
            lstm = forecast_with_personalized_lstm(
                personal_model,
                ordered,
                festival_dates,
                horizon_days,
            )
            # LSTM takes over only when its chronological validation error is
            # measurably no worse than the strongest statistical alternative.
            if personal_model.validation_mae <= selected_mae * 1.02:
                selected = np.asarray(lstm, dtype=float)
                selected_name = "lstm_network"
                selected_mae = personal_model.validation_mae
        except Exception:
            logger.exception("Personal LSTM validation failed; retaining the statistical model.")

    return ForecastResult(
        tuple(round(float(value), 2) for value in selected),
        selected_name,
        round(float(selected_mae), 2) if np.isfinite(selected_mae) else None,
        True,
        MINIMUM_PERSONAL_TRAINING_DAYS,
    )
