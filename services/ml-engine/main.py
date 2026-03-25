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


class ForecastResponse(BaseModel):
    predicted_spend: float
    budget_breach_warning: bool
    days_until_breach: int
    is_mock: bool


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
    historical daily spends.

    NOTE: This is a mock implementation.  The production version will use an
    LSTM time-series model with seasonal nudge generation.
    """
    return ForecastResponse(
        predicted_spend=4500.00,
        budget_breach_warning=True,
        days_until_breach=5,
        is_mock=True,
    )
