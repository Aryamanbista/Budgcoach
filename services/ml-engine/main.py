from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List

app = FastAPI(
    title="Budgcoach ML Engine",
    description="OCR processing, transaction categorisation, and budget forecasting for Budgcoach.",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ---------------------------------------------------------------------------
# Request / Response schemas
# ---------------------------------------------------------------------------

class PredictCategoryRequest(BaseModel):
    raw_text: str


class PredictCategoryResponse(BaseModel):
    category: str
    confidence: float
    is_mock: bool


class DailySpend(BaseModel):
    date: str
    amount: float


class ForecastRequest(BaseModel):
    history: List[DailySpend]


class AIStatus(BaseModel):
    days_logged: int
    required_days: int
    readiness_percentage: float
    active_model: str


class ForecastResponse(BaseModel):
    predicted_spend: float
    budget_breach_warning: bool
    days_until_breach: int
    is_mock: bool
    ai_status: AIStatus


# ---------------------------------------------------------------------------
# Health check
# ---------------------------------------------------------------------------

@app.get("/health")
def health_check():
    return {"status": "ok", "service": "budgcoach-ml-engine"}


# ---------------------------------------------------------------------------
# API Contract — dummy endpoints (unblocks frontend team)
# ---------------------------------------------------------------------------

import os
import re

# Lazy load category classifier
_category_model = None

def get_category_model():
    global _category_model
    if _category_model is None:
        model_path = os.path.join(os.path.dirname(__file__), "models", "category_classifier.pkl")
        if os.path.exists(model_path):
            try:
                import joblib

                _category_model = joblib.load(model_path)
            except (ImportError, OSError, ValueError):
                return None
    return _category_model

@app.post("/api/v1/predict-category", response_model=PredictCategoryResponse)
def predict_category(payload: PredictCategoryRequest):
    """
    Classifies a raw transaction string (e.g. "FT-123-KHALTI-MOMO") into a
    spending category using a Random Forest model trained on labelled Nepali transaction data.
    """
    model = get_category_model()
    if model:

        def clean_text(text):
            text = text.lower()
            text = re.sub(r"\d+", "", text)
            text = re.sub(r"[^\w\s]", "", text)
            return text

        cleaned = clean_text(payload.raw_text)
        prediction = model.predict([cleaned])[0]

        # We can also get confidence by max probability if the pipeline supports it
        try:
            probs = model.predict_proba([cleaned])[0]
            confidence = max(probs)
        except (AttributeError, ValueError):
            confidence = 0.85

        return PredictCategoryResponse(
            category=prediction,
            confidence=confidence,
            is_mock=False,
        )
    else:
        # Fallback if model not trained yet
        return PredictCategoryResponse(
            category="Food & Dining",
            confidence=0.92,
            is_mock=True,
        )


@app.post("/api/v1/forecast", response_model=ForecastResponse)
def forecast_budget(payload: ForecastRequest):
    """
    Forecasts future spending and warns of impending budget breaches based on
    historical daily spends. Implements cold-start fallback logic.
    """
    days_logged = len(payload.history)
    required_days = 30
    readiness_percentage = min(100.0, (days_logged / required_days) * 100.0)
    
    amounts = [max(0.0, item.amount) for item in payload.history]
    recent_average = sum(amounts[-14:]) / min(14, days_logged) if days_logged else 0.0

    active_model = "personal_baseline"
    predicted_spend = recent_average * 30
    is_mock = False

    if 3 <= days_logged < required_days:
        try:
            from statsmodels.tsa.arima.model import ARIMA

            model = ARIMA(amounts, order=(1, 1, 1))
            fitted = model.fit()
            future = fitted.forecast(steps=30)
            predicted_spend = sum(max(0.0, float(value)) for value in future)
            active_model = "arima_baseline"
        except Exception:
            # A deterministic personal baseline remains available if ARIMA cannot
            # be fit (for example, an all-zero or extremely short series).
            predicted_spend = recent_average * 30
    elif days_logged >= required_days:
        try:
            # TensorFlow is intentionally imported only when the LSTM is eligible.
            # This keeps health checks and cold-start forecasts lightweight.
            from inference_service import predict_next_day_spend

            history_data = [
                {"date": item.date, "amount": item.amount}
                for item in payload.history
            ]
            next_day_spend = predict_next_day_spend(history_data)
            # Blend the individual model output with the user's recent pace. This
            # dampens single-day LSTM volatility while preserving personalization.
            blended_daily_spend = (0.65 * next_day_spend) + (0.35 * recent_average)
            predicted_spend = max(0.0, blended_daily_spend) * 30
            active_model = "lstm_network"
        except Exception:
            predicted_spend = recent_average * 30
            active_model = "personal_baseline"
        
    return ForecastResponse(
        predicted_spend=predicted_spend,
        budget_breach_warning=(predicted_spend > 10000.0),
        days_until_breach=5,
        is_mock=is_mock,
        ai_status=AIStatus(
            days_logged=days_logged,
            required_days=required_days,
            readiness_percentage=readiness_percentage,
            active_model=active_model
        )
    )
