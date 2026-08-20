import os

import joblib
import numpy as np
import pandas as pd
from tensorflow.keras.models import load_model

from models.lstm_forecaster import feature_engineering

_model = None
_scaler = None


def load_ml_assets():
    global _model, _scaler
    models_dir = os.path.join(os.path.dirname(__file__), "models")
    if _model is None:
        _model = load_model(os.path.join(models_dir, "lstm_forecaster.keras"))
    if _scaler is None:
        _scaler = joblib.load(os.path.join(models_dir, "scaler.pkl"))
    return _model, _scaler


def predict_next_day_spend(history_data: list) -> float:
    """Predict the next daily spend from at least 30 daily observations."""
    model, scaler = load_ml_assets()

    dataframe = pd.DataFrame(history_data)
    dataframe["date"] = pd.to_datetime(dataframe["date"])
    dataframe["daily_spend"] = dataframe["amount"]
    dataframe["day_of_week"] = dataframe["date"].dt.dayofweek
    dataframe["day_of_month"] = dataframe["date"].dt.day
    dataframe["is_festival_season"] = 0
    dataframe = feature_engineering(dataframe)

    features = [
        "daily_spend",
        "is_festival_season",
        "rolling_mean_7d",
        "rolling_std_7d",
        "rolling_mean_30d",
        "lag_1d",
        "lag_7d",
        "day_of_week_sin",
        "day_of_week_cos",
        "day_of_month_sin",
        "day_of_month_cos",
    ]
    dataframe = dataframe.fillna(0)
    inference_data = dataframe[features].tail(30).copy()
    if len(inference_data) < 30:
        raise ValueError("Not enough data to predict with LSTM")

    scaled_data = scaler.transform(inference_data)
    prediction_scaled = model.predict(np.array([scaled_data]), verbose=0)

    inverse_input = np.zeros((1, len(features)))
    inverse_input[0, 0] = prediction_scaled[0, 0]
    prediction = scaler.inverse_transform(inverse_input)[0, 0]
    return max(0.0, float(prediction))
