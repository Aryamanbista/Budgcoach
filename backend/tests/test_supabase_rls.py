from pathlib import Path
import re
import unittest


MIGRATION_PATH = (
    Path(__file__).resolve().parents[2]
    / "supabase"
    / "migrations"
    / "001_initial_schema.sql"
)


class SupabaseRowLevelSecurityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sql = MIGRATION_PATH.read_text(encoding="utf-8")

    def test_user_owned_tables_enable_row_level_security(self):
        for table in ("accounts", "transactions", "budgets"):
            with self.subTest(table=table):
                self.assertIn(
                    f"ALTER TABLE public.{table} ENABLE ROW LEVEL SECURITY;",
                    self.sql,
                )

    def test_each_user_owned_table_has_all_crud_policies(self):
        for table in ("accounts", "transactions", "budgets"):
            for operation in ("select", "insert", "update", "delete"):
                with self.subTest(table=table, operation=operation):
                    self.assertRegex(
                        self.sql,
                        rf"CREATE POLICY {table}_{operation} ON public\.{table}",
                    )

    def test_policies_scope_records_to_authenticated_user(self):
        references = re.findall(r"auth\.uid\(\) = user_id", self.sql)
        self.assertGreaterEqual(len(references), 12)


if __name__ == "__main__":
    unittest.main()
