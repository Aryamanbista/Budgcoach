import hashlib
import os
from collections import OrderedDict
from dataclasses import dataclass
from datetime import date, timedelta

import joblib
import numpy as np
import pandas as pd

from models.lstm_forecaster import create_dataset, feature_engineering


FEATURES = [
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
LOOKBACK_DAYS = 30
MINIMUM_PERSONAL_TRAINING_DAYS = 180
MAXIMUM_CACHED_MODELS = 16

_base_model = None
_scaler = None
_personal_models: OrderedDict[str, "PersonalModel"] = OrderedDict()


@dataclass
class PersonalModel:
    model: object
    validation_mae: float
    history_signature: str


def load_ml_assets():
    global _base_model, _scaler
    models_dir = os.path.join(os.path.dirname(__file__), "models")
    if _base_model is None:
        from tensorflow.keras.models import load_model

        _base_model = load_model(os.path.join(models_dir, "lstm_forecaster.keras"))
    if _scaler is None:
        _scaler = joblib.load(os.path.join(models_dir, "scaler.pkl"))
    return _base_model, _scaler


def _history_signature(history_data: list[dict]) -> str:
    digest = hashlib.sha256()
    for item in history_data:
        digest.update(f"{item['date']}:{float(item['amount']):.2f}|".encode())
    return digest.hexdigest()


def _feature_frame(
    history_data: list[dict],
    festival_dates: set[date],
) -> pd.DataFrame:
    dataframe = pd.DataFrame(history_data)
    dataframe["date"] = pd.to_datetime(dataframe["date"])
    dataframe = dataframe.sort_values("date").drop_duplicates("date", keep="last")
    dataframe["daily_spend"] = dataframe["amount"].clip(lower=0).astype(float)
    dataframe["day_of_week"] = dataframe["date"].dt.dayofweek
    dataframe["day_of_month"] = dataframe["date"].dt.day
    dataframe["is_festival_season"] = dataframe["date"].dt.date.isin(festival_dates).astype(int)
    return feature_engineering(dataframe).fillna(0)


def _inverse_daily_spend(scaler, scaled_values: np.ndarray) -> np.ndarray:
    inverse_input = np.zeros((len(scaled_values), len(FEATURES)))
    inverse_input[:, 0] = np.asarray(scaled_values).reshape(-1)
    return scaler.inverse_transform(inverse_input)[:, 0]


def train_personalized_lstm(
    profile_id: str,
    history_data: list[dict],
    festival_dates: set[date],
) -> PersonalModel:
    if len(history_data) < MINIMUM_PERSONAL_TRAINING_DAYS:
        raise ValueError(
            f"At least {MINIMUM_PERSONAL_TRAINING_DAYS} daily observations are required."
        )

    signature = _history_signature(history_data)
    cache_key = hashlib.sha256(profile_id.encode()).hexdigest()
    cached = _personal_models.get(cache_key)
    if cached is not None and cached.history_signature == signature:
        _personal_models.move_to_end(cache_key)
        return cached

    from tensorflow.keras.callbacks import EarlyStopping
    from tensorflow.keras.models import clone_model
    from tensorflow.keras.optimizers import Adam

    base_model, scaler = load_ml_assets()
    frame = _feature_frame(history_data, festival_dates)
    scaled = pd.DataFrame(scaler.transform(frame[FEATURES]), columns=FEATURES)
    X, y = create_dataset(scaled, scaled["daily_spend"], LOOKBACK_DAYS)
    if len(X) < 60:
        raise ValueError("Not enough personalized training sequences.")

    validation_size = min(28, max(14, len(X) // 5))
    X_train, X_validation = X[:-validation_size], X[-validation_size:]
    y_train, y_validation = y[:-validation_size], y[-validation_size:]

    model = clone_model(base_model)
    model.set_weights(base_model.get_weights())
    model.compile(optimizer=Adam(learning_rate=0.0002), loss="huber", metrics=["mae"])
    model.fit(
        X_train,
        y_train,
        epochs=12,
        batch_size=32,
        validation_data=(X_validation, y_validation),
        callbacks=[
            EarlyStopping(
                monitor="val_loss",
                patience=3,
                min_delta=0.0001,
                restore_best_weights=True,
            )
        ],
        shuffle=False,
        verbose=0,
    )

    validation_scaled = model.predict(X_validation, verbose=0).reshape(-1)
    validation_predictions = _inverse_daily_spend(scaler, validation_scaled)
    validation_actual = _inverse_daily_spend(scaler, np.asarray(y_validation))
    validation_mae = float(np.mean(np.abs(validation_predictions - validation_actual)))

    result = PersonalModel(model, validation_mae, signature)
    _personal_models[cache_key] = result
    _personal_models.move_to_end(cache_key)
    while len(_personal_models) > MAXIMUM_CACHED_MODELS:
        _personal_models.popitem(last=False)
    return result


def forecast_with_personalized_lstm(
    personal_model: PersonalModel,
    history_data: list[dict],
    festival_dates: set[date],
    horizon_days: int,
) -> list[float]:
    _, scaler = load_ml_assets()
    working = [dict(item) for item in history_data]
    predictions: list[float] = []
    observed = np.asarray([max(0.0, float(item["amount"])) for item in working])
    upper_bound = max(500.0, float(np.percentile(observed, 95)) * 3.0)

    for _ in range(horizon_days):
        next_date = pd.to_datetime(working[-1]["date"]).date() + timedelta(days=1)
        frame = _feature_frame(working, festival_dates)
        sequence = frame[FEATURES].tail(LOOKBACK_DAYS).copy()
        if len(sequence) < LOOKBACK_DAYS:
            raise ValueError("Not enough history for LSTM inference.")
        # The pretrained architecture predicts t+1. Exposing the next day's
        # calendar flag in the final time step lets fine-tuning learn festival uplift.
        sequence.iloc[-1, sequence.columns.get_loc("is_festival_season")] = int(
            next_date in festival_dates
        )
        scaled = scaler.transform(sequence)
        predicted_scaled = personal_model.model.predict(
            np.asarray([scaled]),
            verbose=0,
        )[0, 0]
        predicted = float(_inverse_daily_spend(scaler, np.asarray([predicted_scaled]))[0])
        predicted = min(upper_bound, max(0.0, predicted))
        predictions.append(predicted)
        working.append({"date": next_date.isoformat(), "amount": predicted})
    return predictions
