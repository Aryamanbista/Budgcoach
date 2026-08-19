import pandas as pd
import numpy as np
import os
import joblib
from sklearn.preprocessing import MinMaxScaler
from sklearn.model_selection import TimeSeriesSplit
from tensorflow.keras.models import Sequential, load_model
from tensorflow.keras.layers import LSTM, Dense, Dropout, Bidirectional
from tensorflow.keras.callbacks import EarlyStopping, ModelCheckpoint, ReduceLROnPlateau
from tensorflow.keras.optimizers import Adam
from tensorflow.keras import regularizers

def create_dataset(X, y, time_steps=30):
    Xs, ys = [], []
    for i in range(len(X) - time_steps):
        v = X.iloc[i:(i + time_steps)].values
        Xs.append(v)
        ys.append(y.iloc[i + time_steps])
    return np.array(Xs), np.array(ys)

def feature_engineering(df):
    """
    Industry-standard feature engineering for financial time-series.
    """
    # Create rolling features
    df['rolling_mean_7d'] = df['daily_spend'].rolling(window=7, min_periods=1).mean()
    df['rolling_std_7d'] = df['daily_spend'].rolling(window=7, min_periods=1).std().fillna(0)
    df['rolling_mean_30d'] = df['daily_spend'].rolling(window=30, min_periods=1).mean()
    
    # Lag features
    df['lag_1d'] = df['daily_spend'].shift(1).fillna(0)
    df['lag_7d'] = df['daily_spend'].shift(7).fillna(0)
    
    # Cyclical features for day of week / month to capture seasonality without artificial jumps
    df['day_of_week_sin'] = np.sin(2 * np.pi * df['day_of_week'] / 7)
    df['day_of_week_cos'] = np.cos(2 * np.pi * df['day_of_week'] / 7)
    
    df['day_of_month_sin'] = np.sin(2 * np.pi * df['day_of_month'] / 31)
    df['day_of_month_cos'] = np.cos(2 * np.pi * df['day_of_month'] / 31)
    
    return df

def train_lstm_model(data_path='../data/synthetic_daily_spend.csv', model_save_path='lstm_forecaster.keras', scaler_save_path='scaler.pkl'):
    print(f"Loading data from {data_path}...")
    df = pd.read_csv(data_path)
    df['date'] = pd.to_datetime(df['date'])
    
    # Apply robust feature engineering
    df = feature_engineering(df)
    
    # Define features
    features = [
        'daily_spend', 'is_festival_season',
        'rolling_mean_7d', 'rolling_std_7d', 'rolling_mean_30d',
        'lag_1d', 'lag_7d',
        'day_of_week_sin', 'day_of_week_cos',
        'day_of_month_sin', 'day_of_month_cos'
    ]
    
    # Drop rows with NaN if any (from shifting, though we used fillna)
    data = df[features].dropna().copy()
    
    print("Scaling data...")
    scaler = MinMaxScaler(feature_range=(0, 1))
    data_scaled = pd.DataFrame(scaler.fit_transform(data), columns=features)
    
    # Target is daily_spend
    target = data_scaled['daily_spend']
    
    # Create time-series sequences (30 days look-back)
    time_steps = 30
    X, y = create_dataset(data_scaled, target, time_steps)
    
    # Financial models often use TimeSeriesSplit for validation, but for final training 
    # we usually split chronologically. 85/15 split.
    train_size = int(len(X) * 0.85)
    X_train, X_test = X[:train_size], X[train_size:]
    y_train, y_test = y[:train_size], y[train_size:]
    
    print(f"Training sequences: {X_train.shape[0]}")
    print(f"Validation sequences: {X_test.shape[0]}")
    
    # Build robust LSTM Architecture
    print("Building bidirectional LSTM architecture with L2 regularization...")
    model = Sequential()
    
    # Bidirectional LSTM to capture patterns in both directions (forward and backward context)
    model.add(Bidirectional(LSTM(64, activation='tanh', return_sequences=True, 
                                 kernel_regularizer=regularizers.l2(1e-4)), 
                            input_shape=(X_train.shape[1], X_train.shape[2])))
    model.add(Dropout(0.3))
    
    # Second LSTM layer
    model.add(LSTM(32, activation='tanh', kernel_regularizer=regularizers.l2(1e-4)))
    model.add(Dropout(0.2))
    
    # Dense output
    model.add(Dense(16, activation='relu'))
    model.add(Dense(1)) # Predict next day's scaled spend
    
    # Huber loss is often better for financial data with outliers than simple MSE
    model.compile(optimizer=Adam(learning_rate=0.001), loss='huber', metrics=['mae'])
    
    # Callbacks
    early_stopping = EarlyStopping(monitor='val_loss', patience=15, restore_best_weights=True, verbose=1)
    reduce_lr = ReduceLROnPlateau(monitor='val_loss', factor=0.5, patience=5, min_lr=1e-6, verbose=1)
    checkpoint = ModelCheckpoint(model_save_path, monitor='val_loss', save_best_only=True, verbose=0)
    
    print("Training model (this may take a few minutes)...")
    history = model.fit(
        X_train, y_train,
        epochs=100,
        batch_size=64, # Larger batch size for more stable gradients
        validation_data=(X_test, y_test),
        callbacks=[early_stopping, reduce_lr, checkpoint],
        shuffle=False # NEVER shuffle time series
    )
    
    # Evaluate
    print("Evaluating robust model...")
    # Load best weights saved by checkpoint
    best_model = load_model(model_save_path)
    loss, mae = best_model.evaluate(X_test, y_test, verbose=0)
    print(f"Test Huber Loss: {loss:.5f}, MAE: {mae:.5f}")
    
    # Save the scaler for inference
    joblib.dump(scaler, scaler_save_path)
    print(f"Model saved to {model_save_path}")
    print(f"Scaler saved to {scaler_save_path}")

if __name__ == '__main__':
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    train_lstm_model()
