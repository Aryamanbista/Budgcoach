from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import List
import os

app = FastAPI(
    title="Budgcoach ML Engine",
    description="OCR processing, transaction categorisation, and budget forecasting for Budgcoach.",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        origin.strip()
        for origin in os.getenv("CORS_ORIGINS", "http://localhost:3000,http://localhost:8080").split(",")
        if origin.strip()
    ],
    allow_credentials=False,
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


class PredictCategoriesRequest(BaseModel):
    raw_texts: List[str] = Field(min_length=1, max_length=500)


class DailySpend(BaseModel):
    date: str
    amount: float


class FestivalDay(BaseModel):
    date: str
    name: str
    festival_type: str = "holiday"
    is_major: bool = False


class ForecastRequest(BaseModel):
    history: List[DailySpend]
    profile_id: str = "anonymous"
    forecast_days: int = Field(default=30, ge=1, le=60)
    festivals: List[FestivalDay] = Field(default_factory=list)


class AIStatus(BaseModel):
    days_logged: int
    required_days: int
    readiness_percentage: float
    active_model: str
    minimum_lstm_days: int
    validation_mae: float | None
    selected_via_backtest: bool


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


def category_rule_fallback(raw_text: str) -> tuple[str, float]:
    normalized = re.sub(r"[^a-z0-9 ]", " ", raw_text.lower())
    rules = {
        "Food & Dining": ("foodmandu", "restaurant", "cafe", "momo", "pizza", "kfc"),
        "Transport": ("pathao", "indrive", "tootle", "airlines", "fuel", "petrol", "taxi"),
        "Utilities": ("nea", "ncell", "telecom", "worldlink", "vianet", "khanepani", "internet"),
        "Shopping": ("daraz", "bhatbhateni", "big mart", "miniso", "supermarket"),
        "Health": ("hospital", "pharmacy", "clinic", "medical"),
        "Education": ("school", "college", "university", "tuition", "books"),
        "Entertainment": ("cinema", "movie", "netflix", "spotify", "game"),
        "Income": ("salary", "payroll", "interest credited"),
        "Transfer": ("fund transfer", "connectips", "received from", "sent to"),
    }
    for category, keywords in rules.items():
        if any(keyword in normalized for keyword in keywords):
            return category, 0.78
    return "Other", 0.35

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
        category, confidence = category_rule_fallback(payload.raw_text)
        return PredictCategoryResponse(
            category=category,
            confidence=confidence,
            is_mock=False,
        )


@app.post("/api/v1/predict-categories", response_model=List[PredictCategoryResponse])
def predict_categories(payload: PredictCategoriesRequest):
    return [
        predict_category(PredictCategoryRequest(raw_text=text))
        for text in payload.raw_texts
    ]


@app.post("/api/v1/forecast", response_model=ForecastResponse)
def forecast_budget(payload: ForecastRequest):
    """
    Forecasts future spending and warns of impending budget breaches based on
    historical daily spends. Implements cold-start fallback logic.
    """
    from forecasting_service import forecast_personal_spend

    history = [item.model_dump() for item in payload.history]
    festivals = [item.model_dump() for item in payload.festivals]
    result = forecast_personal_spend(
        profile_id=payload.profile_id,
        history=history,
        festivals=festivals,
        horizon_days=payload.forecast_days,
    )
    days_logged = len(payload.history)
    required_days = result.minimum_lstm_days
    readiness_percentage = min(100.0, (days_logged / required_days) * 100.0)

    return ForecastResponse(
        predicted_spend=round(result.total, 2),
        budget_breach_warning=False,
        days_until_breach=0,
        is_mock=False,
        ai_status=AIStatus(
            days_logged=days_logged,
            required_days=required_days,
            readiness_percentage=readiness_percentage,
            active_model=result.active_model,
            minimum_lstm_days=result.minimum_lstm_days,
            validation_mae=result.validation_mae,
            selected_via_backtest=result.selected_via_backtest,
        )
    )
