import pandas as pd
import numpy as np
import datetime
import os

# Set random seed for reproducibility
np.random.seed(42)

def generate_synthetic_data(start_date="2024-01-01", end_date="2025-12-31"):
    # Generate date range
    dates = pd.date_range(start=start_date, end=end_date, freq='D')
    df = pd.DataFrame({'date': dates})
    
    # 1. Base Daily Spend (Gamma distribution is good for spending data, right-skewed)
    # Shape and scale based on typical student/young adult spending
    shape, scale = 2.0, 500.0  # Mean = shape * scale = 1000 NPR/day
    df['daily_spend'] = np.random.gamma(shape, scale, len(df))
    
    # 2. Add Weekly Patterns (higher spend on weekends: Friday/Saturday in Nepal)
    df['day_of_week'] = df['date'].dt.dayofweek
    # In Nepal, Friday evening and Saturday are weekends. day_of_week: 4 is Friday, 5 is Saturday
    weekend_multiplier = np.where(df['day_of_week'].isin([4, 5]), 1.5, 1.0)
    df['daily_spend'] *= weekend_multiplier
    
    # 3. Add Monthly Patterns (Salary/Pocket money start of month = higher spend)
    df['day_of_month'] = df['date'].dt.day
    # Days 1-5 get a 1.3x multiplier
    month_start_multiplier = np.where(df['day_of_month'] <= 5, 1.3, 1.0)
    df['daily_spend'] *= month_start_multiplier
    
    # 4. Integrate Lunar Calendar Spikes (Dashain & Tihar)
    # 2024: Dashain ~Oct 3 - 16, Tihar ~Oct 30 - Nov 3
    # 2025: Dashain ~Sep 22 - Oct 6, Tihar ~Oct 20 - Oct 24
    
    festival_ranges = [
        (pd.to_datetime('2024-10-03'), pd.to_datetime('2024-10-16')), # Dashain 24
        (pd.to_datetime('2024-10-30'), pd.to_datetime('2024-11-03')), # Tihar 24
        (pd.to_datetime('2025-09-22'), pd.to_datetime('2025-10-06')), # Dashain 25
        (pd.to_datetime('2025-10-20'), pd.to_datetime('2025-10-24')), # Tihar 25
    ]
    
    df['is_festival_season'] = 0
    for start, end in festival_ranges:
        mask = (df['date'] >= start) & (df['date'] <= end)
        df.loc[mask, 'is_festival_season'] = 1
        
        # Festival spike: 2.5x to 4x normal spending
        spike_multiplier = np.random.uniform(2.5, 4.0, sum(mask))
        df.loc[mask, 'daily_spend'] *= spike_multiplier
        
    # Round off to 2 decimal places
    df['daily_spend'] = df['daily_spend'].round(2)
    
    # Create directory if it doesn't exist
    os.makedirs('data', exist_ok=True)
    
    # Save to CSV
    output_path = 'data/synthetic_daily_spend.csv'
    df.to_csv(output_path, index=False)
    print(f"Successfully generated {len(df)} records and saved to {output_path}")

if __name__ == "__main__":
    generate_synthetic_data()
