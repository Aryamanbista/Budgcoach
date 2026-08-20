from pathlib import Path
import sys
import unittest

from fastapi.testclient import TestClient


ML_ENGINE_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ML_ENGINE_DIR))

from main import app  # noqa: E402


class MlEngineContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.client = TestClient(app)

    def test_health_endpoint(self):
        response = self.client.get("/health")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json(),
            {"status": "ok", "service": "budgcoach-ml-engine"},
        )

    def test_category_prediction_contract(self):
        response = self.client.post(
            "/api/v1/predict-category",
            json={"raw_text": "FT-123-KHALTI-MOMO"},
        )
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertIsInstance(body["category"], str)
        self.assertTrue(body["category"])
        self.assertGreaterEqual(body["confidence"], 0)
        self.assertLessEqual(body["confidence"], 1)
        self.assertIsInstance(body["is_mock"], bool)

    def test_batch_category_prediction_preserves_row_order(self):
        response = self.client.post(
            "/api/v1/predict-categories",
            json={"raw_texts": ["Foodmandu order", "NEA bill payment"]},
        )
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(len(response.json()), 2)
        self.assertEqual(response.json()[0]["category"], "Food & Dining")
        self.assertEqual(response.json()[1]["category"], "Utilities")

    def test_forecast_contract(self):
        response = self.client.post(
            "/api/v1/forecast",
            json={
                "history": [
                    {"date": "2026-08-01", "amount": 500},
                    {"date": "2026-08-02", "amount": 750},
                ]
            },
        )
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertGreater(body["predicted_spend"], 0)
        self.assertIsInstance(body["budget_breach_warning"], bool)
        self.assertGreaterEqual(body["days_until_breach"], 0)
        self.assertFalse(body["is_mock"])
        self.assertEqual(body["ai_status"]["required_days"], 180)
        self.assertEqual(body["ai_status"]["active_model"], "personal_baseline")
        self.assertFalse(body["ai_status"]["selected_via_backtest"])

    def test_forecast_rejects_malformed_amount(self):
        response = self.client.post(
            "/api/v1/forecast",
            json={"history": [{"date": "2026-08-01", "amount": "invalid"}]},
        )
        self.assertEqual(response.status_code, 422)


if __name__ == "__main__":
    unittest.main()
