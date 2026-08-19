import pandas as pd
import numpy as np
import os
import joblib
from sklearn.preprocessing import MinMaxScaler
from tensorflow.keras.models import Sequential, load_model
from tensorflow.keras.layers import LSTM, Dense, Dropout
from tensorflow.keras.callbacks import EarlyStopping
from tensorflow.keras.optimizers import Adam

def create_dataset(X, y, time_steps=30):
    Xs, ys = [], []
    for i in range(len(X) - time_steps):
        v = X.iloc[i:(i + time_steps)].values
        Xs.append(v)
        ys.append(y.iloc[i + time_steps])
    return np.array(Xs), np.array(ys)

def train_lstm_model(data_path='../data/synthetic_daily_spend.csv', model_save_path='lstm_forecaster.keras', scaler_save_path='scaler.pkl'):
    print(f"Loading data from {data_path}...")
    df = pd.read_csv(data_path)
    df['date'] = pd.to_datetime(df['date'])
    
    # Feature Selection: daily_spend, day_of_week, day_of_month, is_festival_season
    features = ['daily_spend', 'day_of_week', 'day_of_month', 'is_festival_season']
    data = df[features].copy()
    
    print("Scaling data...")
    scaler = MinMaxScaler()
    data_scaled = pd.DataFrame(scaler.fit_transform(data), columns=features)
    
    # We want to predict daily_spend
    target = data_scaled['daily_spend']
    
    # Create time-series dataset
    time_steps = 30
    X, y = create_dataset(data_scaled, target, time_steps)
    
    # Split into train/test (80/20)
    train_size = int(len(X) * 0.8)
    X_train, X_test = X[:train_size], X[train_size:]
    y_train, y_test = y[:train_size], y[train_size:]
    
    print(f"Training data shape: {X_train.shape}")
    print(f"Testing data shape: {X_test.shape}")
    
    # Build LSTM Model
    print("Building LSTM model architecture...")
    model = Sequential()
    model.add(LSTM(64, activation='relu', return_sequences=True, input_shape=(X_train.shape[1], X_train.shape[2])))
    model.add(Dropout(0.2))
    model.add(LSTM(32, activation='relu'))
    model.add(Dense(1))
    
    model.compile(optimizer=Adam(learning_rate=0.001), loss='mse')
    
    # Early stopping
    early_stopping = EarlyStopping(monitor='val_loss', patience=10, restore_best_weights=True)
    
    print("Training model...")
    history = model.fit(
        X_train, y_train,
        epochs=50,
        batch_size=32,
        validation_split=0.1,
        callbacks=[early_stopping],
        shuffle=False
    )
    
    # Evaluate
    print("Evaluating model...")
    loss = model.evaluate(X_test, y_test)
    print(f"Test Loss (MSE): {loss}")
    
    # Calculate MAPE
    y_pred = model.predict(X_test)
    # Inverse transform to get actual values
    # Create dummy array for inverse transform
    dummy_pred = np.zeros((len(y_pred), len(features)))
    dummy_pred[:, 0] = y_pred.flatten()
    y_pred_actual = scaler.inverse_transform(dummy_pred)[:, 0]
    
    dummy_test = np.zeros((len(y_test), len(features)))
    dummy_test[:, 0] = y_test
    y_test_actual = scaler.inverse_transform(dummy_test)[:, 0]
    
    # Avoid division by zero in MAPE
    mask = y_test_actual > 0
    mape = np.mean(np.abs((y_test_actual[mask] - y_pred_actual[mask]) / y_test_actual[mask])) * 100
    print(f"Test MAPE: {mape:.2f}%")
    
    # Save model and scaler
    model.save(model_save_path)
    joblib.dump(scaler, scaler_save_path)
    print(f"Model saved to {model_save_path}")
    print(f"Scaler saved to {scaler_save_path}")

if __name__ == '__main__':
    # Make sure we are in the correct directory when running
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    train_lstm_model()
