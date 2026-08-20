from datetime import date
from decimal import Decimal
import unittest
from unittest.mock import AsyncMock, patch
from uuid import UUID

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database import Base, get_db
from app.main import app
from app.models.account import Account
from app.models.budget import Budget
from app.models.category import Category
from app.models.savings_goal import SavingsGoal
from app.models.user import User
from app.models.transaction import Transaction
from app.models.import_batch import ImportBatch
from app.schemas.transaction import TransactionRow


TEST_DATABASE_URL_SYNC = "sqlite:///./test.db"
TEST_DATABASE_URL_ASYNC = "sqlite+aiosqlite:///./test.db"

sync_engine = create_engine(
    TEST_DATABASE_URL_SYNC,
    connect_args={"check_same_thread": False},
)

test_engine = create_async_engine(
    TEST_DATABASE_URL_ASYNC,
    connect_args={"check_same_thread": False},
)

SyncTestingSessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=sync_engine,
)

TestingSessionLocal = async_sessionmaker(
    bind=test_engine,
    class_=AsyncSession,
    autocommit=False,
    autoflush=False,
    expire_on_commit=False,
)


async def override_get_db():
    async with TestingSessionLocal() as db:
        yield db


app.dependency_overrides[get_db] = override_get_db


class BackendApiIntegrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.client = TestClient(app)

    def setUp(self):
        Base.metadata.drop_all(sync_engine)
        Base.metadata.create_all(sync_engine)

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
        db = SyncTestingSessionLocal()
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

        db = SyncTestingSessionLocal()
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

    def test_transaction_batch(self):
        token = self.register_and_login()
        account_id, category_id = self.seed_account_and_category()
        headers = self.auth_headers(token)

        payload = [
            {
                "account_id": account_id,
                "category_id": category_id,
                "amount": "500",
                "type": "debit",
                "date": date.today().isoformat(),
                "raw_text": "Batch debit 1",
            },
            {
                "account_id": account_id,
                "category_id": category_id,
                "amount": "1000",
                "type": "credit",
                "date": date.today().isoformat(),
                "raw_text": "Batch credit 1",
            }
        ]

        response = self.client.post("/api/v1/transactions/batch", headers=headers, json=payload)
        self.assertEqual(response.status_code, 201, response.text)
        self.assertEqual(len(response.json()), 2)

        db = SyncTestingSessionLocal()
        try:
            account = db.get(Account, UUID(account_id))
            # Initial balance is 10000. -500 + 1000 = +500 -> 10500
            self.assertEqual(account.balance, Decimal("10500.00"))
        finally:
            db.close()

    @patch("app.api.upload.process_document", new_callable=AsyncMock)
    def test_statement_import_is_idempotent_across_retries_and_overlaps(
        self,
        mock_process_document,
    ):
        token = self.register_and_login()
        headers = self.auth_headers(token)
        accounts = self.client.get("/api/v1/accounts/", headers=headers)
        self.assertEqual(accounts.status_code, 200, accounts.text)
        account_id = accounts.json()[0]["id"]

        first_rows = [
            TransactionRow(
                date="2026-08-01",
                description="Bhat Bhateni",
                debit=Decimal("1000.00"),
                balance=Decimal("9000.00"),
                raw_text="Bhat Bhateni 1000",
                source_format="excel",
                confidence=0.98,
            ),
            TransactionRow(
                date="2026-08-02",
                description="Salary",
                credit=Decimal("5000.00"),
                balance=Decimal("14000.00"),
                raw_text="Salary 5000",
                source_format="excel",
                confidence=0.99,
            ),
        ]
        mock_process_document.return_value = first_rows
        first_upload = self.client.post(
            "/api/v1/upload-statement",
            headers=headers,
            data={"account_id": account_id},
            files={"file": ("august.csv", b"first statement", "text/csv")},
        )
        self.assertEqual(first_upload.status_code, 200, first_upload.text)
        preview = first_upload.json()
        self.assertEqual(preview["new_count"], 2)
        self.assertEqual(preview["exact_duplicates"], 0)
        self.assertFalse(preview["file_reused"])

        decisions = [
            {
                "row_index": row["row_index"],
                "include": True,
                "date": row["date"],
                "type": row["type"],
                "amount": row["amount"],
                "clean_text": row["clean_text"],
            }
            for row in preview["transactions"]
        ]
        committed = self.client.post(
            f"/api/v1/import-batches/{preview['batch_id']}/commit",
            headers=headers,
            json={"rows": decisions},
        )
        self.assertEqual(committed.status_code, 200, committed.text)
        self.assertEqual(committed.json()["imported_count"], 2)

        repeated_commit = self.client.post(
            f"/api/v1/import-batches/{preview['batch_id']}/commit",
            headers=headers,
            json={"rows": decisions},
        )
        self.assertEqual(repeated_commit.status_code, 200)
        self.assertEqual(repeated_commit.json()["imported_count"], 2)

        repeated_file = self.client.post(
            "/api/v1/upload-statement",
            headers=headers,
            data={"account_id": account_id},
            files={"file": ("august.csv", b"first statement", "text/csv")},
        )
        self.assertEqual(repeated_file.status_code, 200)
        self.assertTrue(repeated_file.json()["file_reused"])
        self.assertEqual(repeated_file.json()["status"], "completed")
        self.assertEqual(mock_process_document.await_count, 1)

        mock_process_document.return_value = [
            first_rows[1],
            TransactionRow(
                date="2026-08-01",
                description="Bhat Bhateni Store",
                debit=Decimal("1000.00"),
                raw_text="Bhat Bhateni Store 1000",
                source_format="excel",
                confidence=0.90,
            ),
            TransactionRow(
                date="2026-08-03",
                description="Internet Bill",
                debit=Decimal("1500.00"),
                balance=Decimal("12500.00"),
                raw_text="Internet Bill 1500",
                source_format="excel",
                confidence=0.97,
            ),
        ]
        overlap_upload = self.client.post(
            "/api/v1/upload-statement",
            headers=headers,
            data={"account_id": account_id},
            files={"file": ("overlap.csv", b"overlapping statement", "text/csv")},
        )
        self.assertEqual(overlap_upload.status_code, 200, overlap_upload.text)
        overlap = overlap_upload.json()
        self.assertEqual(overlap["exact_duplicates"], 1)
        self.assertEqual(overlap["possible_duplicates"], 1)
        self.assertEqual(overlap["new_count"], 1)

        overlap_decisions = [
            {
                "row_index": row["row_index"],
                "include": row["duplicate_status"] == "new",
                "date": row["date"],
                "type": row["type"],
                "amount": row["amount"],
                "clean_text": row["clean_text"],
            }
            for row in overlap["transactions"]
        ]
        overlap_commit = self.client.post(
            f"/api/v1/import-batches/{overlap['batch_id']}/commit",
            headers=headers,
            json={"rows": overlap_decisions},
        )
        self.assertEqual(overlap_commit.status_code, 200, overlap_commit.text)
        self.assertEqual(overlap_commit.json()["imported_count"], 1)

        db = SyncTestingSessionLocal()
        try:
            self.assertEqual(db.query(Transaction).count(), 3)
            self.assertEqual(db.query(ImportBatch).count(), 2)
        finally:
            db.close()

    def test_sms_sync_flow(self):
        token = self.register_and_login()
        account_id, _ = self.seed_account_and_category()
        headers = self.auth_headers(token)

        messages = [
            "Rs. 500 debited from your a/c ... towards POS on 2026-10-25",
            "Rs. 2000 credited to your a/c ... by transfer on 2026-10-25",
            "Rs. 500 debited from your a/c ... towards POS on 2026-10-25" # Duplicate
        ]

        payload = {
            "wallet_type": "esewa",
            "account_id": account_id,
            "messages": messages
        }

        response = self.client.post("/api/v1/transactions/sms-sync", headers=headers, json=payload)
        self.assertEqual(response.status_code, 200, response.text)
        
        data = response.json()
        self.assertEqual(data["total_parsed"], 3)
        self.assertEqual(data["duplicates_found"], 1)
        self.assertEqual(len(data["transactions"]), 3)

        db = SyncTestingSessionLocal()
        try:
            account = db.get(Account, UUID(account_id))
            # We expect 2 non-duplicate tx to be persisted.
            # Initial: 10000. -500 + 2000 = +1500 -> 11500
            self.assertEqual(account.balance, Decimal("11500.00"))
            
            # Verify transactions were saved
            txs = db.query(Transaction).filter_by(account_id=UUID(account_id)).all()
            self.assertEqual(len(txs), 2)
        finally:
            db.close()


if __name__ == "__main__":
    unittest.main()
