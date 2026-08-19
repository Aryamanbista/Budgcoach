from datetime import date, datetime, timedelta, timezone
from decimal import Decimal
import unittest
from uuid import uuid4

from jose import jwt
from pydantic import ValidationError

from app.core.config import settings
from app.core.security import create_access_token, get_password_hash, verify_password
from app.schemas.budget import BudgetCreate
from app.schemas.category import CategoryCreate
from app.schemas.savings_goal import SavingsGoalOut
from app.schemas.transaction import TransactionCreate, TransactionOut


class PasswordSecurityTests(unittest.TestCase):
    def test_password_hash_round_trip_and_wrong_password(self):
        encoded = get_password_hash("StrongPassword1!")

        self.assertNotEqual(encoded, "StrongPassword1!")
        self.assertTrue(verify_password("StrongPassword1!", encoded))
        self.assertFalse(verify_password("wrong-password", encoded))

    def test_invalid_hash_is_rejected_without_crashing(self):
        self.assertFalse(verify_password("password", "not-a-bcrypt-hash"))

    def test_passwords_over_bcrypt_limit_are_rejected(self):
        with self.assertRaisesRegex(ValueError, "72 UTF-8 bytes"):
            get_password_hash("x" * 73)

    def test_access_token_contains_subject_and_expiry(self):
        token = create_access_token("aryaman@example.com", timedelta(minutes=5))
        payload = jwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=[settings.ALGORITHM],
        )

        self.assertEqual(payload["sub"], "aryaman@example.com")
        expires_at = datetime.fromtimestamp(payload["exp"], tz=timezone.utc)
        self.assertGreater(expires_at, datetime.now(timezone.utc))


class SchemaValidationTests(unittest.TestCase):
    def test_category_normalizes_ampersand_and_case(self):
        category = CategoryCreate(name=" food & dining ")
        self.assertEqual(category.name, "Food and Dining")

    def test_unknown_category_is_rejected(self):
        with self.assertRaises(ValidationError):
            CategoryCreate(name="Cryptocurrency")

    def test_transaction_type_is_normalized(self):
        transaction = TransactionCreate(
            account_id=uuid4(),
            amount=Decimal("125.50"),
            type=" DEBIT ",
            date=date.today(),
        )
        self.assertEqual(transaction.type, "debit")

    def test_negative_transaction_amount_is_rejected(self):
        with self.assertRaises(ValidationError):
            TransactionCreate(
                account_id=uuid4(),
                amount=Decimal("-1"),
                type="debit",
                date=date.today(),
            )

    def test_budget_negative_limit_is_rejected(self):
        with self.assertRaises(ValidationError):
            BudgetCreate(
                category_id=uuid4(),
                limit_amount=Decimal("-100"),
                month_year="2026-08",
            )

    def test_transaction_output_formats_debit_and_credit(self):
        common = {
            "id": uuid4(),
            "user_id": uuid4(),
            "account_id": uuid4(),
            "amount": Decimal("1200.50"),
            "date": date.today(),
        }

        debit = TransactionOut(type="debit", **common)
        credit = TransactionOut(type="credit", **common)

        self.assertEqual(debit.formatted_amount, "- Rs. 1,200.50")
        self.assertEqual(credit.formatted_amount, "+ Rs. 1,200.50")

    def test_savings_goal_reports_achieved_state(self):
        goal = SavingsGoalOut(
            id=uuid4(),
            user_id=uuid4(),
            name="Emergency Fund",
            target_amount=Decimal("50000"),
            current_amount=Decimal("50000"),
            deadline_date=date.today() + timedelta(days=90),
        )

        self.assertEqual(
            goal.monthly_contribution_progress,
            "Goal achieved! Rs. 0.00 needed monthly.",
        )


if __name__ == "__main__":
    unittest.main()
