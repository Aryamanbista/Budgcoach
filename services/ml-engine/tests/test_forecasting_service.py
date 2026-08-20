from forecasting_service import forecast_personal_spend


def test_cold_start_uses_only_the_individual_history():
    result = forecast_personal_spend(
        profile_id="user-1",
        history=[
            {"date": "2026-08-01", "amount": 100},
            {"date": "2026-08-02", "amount": 200},
        ],
        festivals=[],
        horizon_days=3,
    )

    assert result.active_model == "personal_baseline"
    assert result.minimum_lstm_days == 180
    assert len(result.future_daily_spend) == 3
    assert all(value > 0 for value in result.future_daily_spend)


def test_live_calendar_flag_adjusts_a_future_festival_day():
    history = [
        {"date": f"2026-08-{day:02d}", "amount": 100}
        for day in range(1, 7)
    ]
    result = forecast_personal_spend(
        profile_id="user-1",
        history=history,
        festivals=[{"date": "2026-08-08", "name": "Festival"}],
        horizon_days=2,
    )

    assert result.future_daily_spend[1] > result.future_daily_spend[0]
