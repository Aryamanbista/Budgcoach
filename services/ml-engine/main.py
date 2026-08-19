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

@app.post("/api/v1/predict-category", response_model=PredictCategoryResponse)
def predict_category(payload: PredictCategoryRequest):
    """
    Classifies a raw transaction string (e.g. "FT-123-KHALTI-MOMO") into a
    spending category.

    NOTE: This is a mock implementation.  The production version will use a
    Random Forest model trained on labelled Nepali transaction data.
    """
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
    
    total_spend = sum(item.amount for item in payload.history)
    
    if days_logged < 14:
        active_model = "rule_based"
        if days_logged > 0:
            predicted_spend = (total_spend / days_logged) * 30
        else:
            predicted_spend = 0.0
    elif days_logged < 30:
        active_model = "arima_baseline"
        # Mock ARIMA output
        predicted_spend = (total_spend / days_logged) * 30 * 1.05
    else:
        active_model = "lstm_network"
        # In a full deployment, we load and inference via `lstm_forecaster.keras`
        predicted_spend = 4500.00
        
    return ForecastResponse(
        predicted_spend=predicted_spend,
        budget_breach_warning=(predicted_spend > 10000.0), # Example threshold
        days_until_breach=5,
        is_mock=True,
        ai_status=AIStatus(
            days_logged=days_logged,
            required_days=required_days,
            readiness_percentage=readiness_percentage,
            active_model=active_model
        )
    )
