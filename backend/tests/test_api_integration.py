from datetime import date
from decimal import Decimal
import unittest
from uuid import UUID

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database import Base, get_db
from app.main import app
from app.models.account import Account
from app.models.category import Category
from app.models.user import User


TEST_DATABASE_URL = "sqlite://"
test_engine = create_engine(
    TEST_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=test_engine,
)


def override_get_db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


app.dependency_overrides[get_db] = override_get_db


class BackendApiIntegrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.client = TestClient(app)

    def setUp(self):
        Base.metadata.drop_all(test_engine)
        Base.metadata.create_all(test_engine)

    def tearDown(self):
        app.dependency_overrides[get_db] = override_get_db

    def register_and_login(self, email="aryaman@example.com"):
        registration = self.client.post(
            "/api/v1/register",
            json={
                "email": email,
                "password": "StrongPassword1!",
                "full_name": "Aryaman Bista",
            },
        )
        self.assertEqual(registration.status_code, 201, registration.text)

        login = self.client.post(
            "/api/v1/login",
            json={"email": email, "password": "StrongPassword1!"},
        )
        self.assertEqual(login.status_code, 200, login.text)
        return login.json()["access_token"]

    @staticmethod
    def auth_headers(token):
        return {"Authorization": f"Bearer {token}"}

    def seed_account_and_category(self, email="aryaman@example.com"):
        db = TestingSessionLocal()
        try:
            user = db.query(User).filter(User.email == email).one()
            account = Account(
                user_id=user.id,
                wallet_name="eSewa",
                balance=Decimal("10000.00"),
            )
            category = Category(name="Food and Dining")
            db.add_all([account, category])
            db.commit()
            db.refresh(account)
            db.refresh(category)
            return str(account.id), str(category.id)
        finally:
            db.close()

    def test_health_check(self):
        response = self.client.get("/health")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["status"], "healthy")

    def test_registration_duplicate_and_login_failure_paths(self):
        token = self.register_and_login()
        self.assertTrue(token)

        duplicate = self.client.post(
            "/api/v1/register",
            json={
                "email": "aryaman@example.com",
                "password": "StrongPassword1!",
                "full_name": "Aryaman Bista",
            },
        )
        self.assertEqual(duplicate.status_code, 400)

        invalid_login = self.client.post(
            "/api/v1/login",
            json={"email": "aryaman@example.com", "password": "wrong"},
        )
        self.assertEqual(invalid_login.status_code, 401)

    def test_protected_endpoint_rejects_missing_token(self):
        response = self.client.get("/api/v1/transactions/")
        self.assertEqual(response.status_code, 401)

    def test_transaction_flow_updates_balance_and_lists_user_data(self):
        token = self.register_and_login()
        account_id, category_id = self.seed_account_and_category()

        created = self.client.post(
            "/api/v1/transactions/",
            headers=self.auth_headers(token),
            json={
                "account_id": account_id,
                "category_id": category_id,
                "amount": "1200.00",
                "type": "debit",
                "date": date.today().isoformat(),
                "transaction_text": "Bhat Bhateni Supermarket",
                "is_manual_entry": True,
            },
        )
        self.assertEqual(created.status_code, 201, created.text)
        self.assertEqual(created.json()["formatted_amount"], "- Rs. 1,200.00")

        listed = self.client.get(
            "/api/v1/transactions/",
            headers=self.auth_headers(token),
        )
        self.assertEqual(listed.status_code, 200)
        self.assertEqual(len(listed.json()), 1)

        db = TestingSessionLocal()
        try:
            account = db.get(Account, UUID(account_id))
            self.assertEqual(account.balance, Decimal("8800.00"))
        finally:
            db.close()

    def test_transaction_rejects_account_not_owned_by_user(self):
        token = self.register_and_login()
        _, category_id = self.seed_account_and_category()

        response = self.client.post(
            "/api/v1/transactions/",
            headers=self.auth_headers(token),
            json={
                "account_id": "00000000-0000-0000-0000-000000000001",
                "category_id": category_id,
                "amount": "100",
                "type": "debit",
                "date": date.today().isoformat(),
            },
        )
        self.assertEqual(response.status_code, 404)

    def test_budget_create_duplicate_update_and_filter_flow(self):
        token = self.register_and_login()
        _, category_id = self.seed_account_and_category()
        headers = self.auth_headers(token)
        payload = {
            "category_id": category_id,
            "limit_amount": "8000",
            "spent_amount": "1200",
            "month_year": "2026-08",
        }

        created = self.client.post("/api/v1/budgets/", headers=headers, json=payload)
        self.assertEqual(created.status_code, 201, created.text)
        budget_id = created.json()["id"]

        duplicate = self.client.post("/api/v1/budgets/", headers=headers, json=payload)
        self.assertEqual(duplicate.status_code, 400)

        updated = self.client.patch(
            f"/api/v1/budgets/{budget_id}",
            headers=headers,
            json={"limit_amount": "9000"},
        )
        self.assertEqual(updated.status_code, 200, updated.text)
        self.assertEqual(updated.json()["formatted_limit"], "Rs. 9,000.00")

        listed = self.client.get(
            "/api/v1/budgets/?month_year=2026-08",
            headers=headers,
        )
        self.assertEqual(len(listed.json()), 1)

    def test_savings_goal_create_update_and_list_flow(self):
        token = self.register_and_login()
        headers = self.auth_headers(token)

        created = self.client.post(
            "/api/v1/goals/",
            headers=headers,
            json={
                "name": "Emergency Fund",
                "target_amount": "50000",
                "current_amount": "15000",
                "deadline_date": "2027-12-31",
            },
        )
        self.assertEqual(created.status_code, 201, created.text)
        goal_id = created.json()["id"]

        updated = self.client.patch(
            f"/api/v1/goals/{goal_id}",
            headers=headers,
            json={"current_amount": "20000"},
        )
        self.assertEqual(updated.status_code, 200, updated.text)
        self.assertEqual(updated.json()["formatted_current"], "Rs. 20,000.00")

        listed = self.client.get("/api/v1/goals/", headers=headers)
        self.assertEqual(listed.status_code, 200)
        self.assertEqual(len(listed.json()), 1)


if __name__ == "__main__":
    unittest.main()
