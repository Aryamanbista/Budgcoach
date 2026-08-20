"""add import batches and transaction fingerprints

Revision ID: 8b1f6e4a2c90
Revises: 75fa9ab691c7
Create Date: 2026-08-20 16:00:00
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "8b1f6e4a2c90"
down_revision: Union[str, None] = "75fa9ab691c7"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "import_batches",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("account_id", sa.UUID(), nullable=False),
        sa.Column("file_hash", sa.String(length=64), nullable=False),
        sa.Column("original_filename", sa.String(length=255), nullable=False),
        sa.Column("parser_version", sa.String(length=32), nullable=False),
        sa.Column("status", sa.String(length=24), nullable=False),
        sa.Column("total_parsed", sa.Integer(), nullable=False),
        sa.Column("new_count", sa.Integer(), nullable=False),
        sa.Column("exact_duplicate_count", sa.Integer(), nullable=False),
        sa.Column("possible_duplicate_count", sa.Integer(), nullable=False),
        sa.Column("validation_error_count", sa.Integer(), nullable=False),
        sa.Column("imported_count", sa.Integer(), nullable=False),
        sa.Column("skipped_count", sa.Integer(), nullable=False),
        sa.Column("parsed_payload", sa.JSON(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["account_id"], ["accounts.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "user_id",
            "account_id",
            "file_hash",
            name="uq_import_batch_user_account_file",
        ),
    )
    op.create_index(
        op.f("ix_import_batches_user_id"),
        "import_batches",
        ["user_id"],
        unique=False,
    )

    op.add_column(
        "transactions",
        sa.Column("fingerprint", sa.String(length=64), nullable=True),
    )
    op.add_column(
        "transactions",
        sa.Column("import_batch_id", sa.UUID(), nullable=True),
    )
    op.add_column(
        "transactions",
        sa.Column("source_row_index", sa.Integer(), nullable=True),
    )
    op.create_foreign_key(
        "fk_transactions_import_batch_id",
        "transactions",
        "import_batches",
        ["import_batch_id"],
        ["id"],
        ondelete="SET NULL",
    )
    op.create_index(
        op.f("ix_transactions_import_batch_id"),
        "transactions",
        ["import_batch_id"],
        unique=False,
    )
    op.create_unique_constraint(
        "uq_transaction_user_account_fingerprint",
        "transactions",
        ["user_id", "account_id", "fingerprint"],
    )


def downgrade() -> None:
    op.drop_constraint(
        "uq_transaction_user_account_fingerprint",
        "transactions",
        type_="unique",
    )
    op.drop_index(
        op.f("ix_transactions_import_batch_id"),
        table_name="transactions",
    )
    op.drop_constraint(
        "fk_transactions_import_batch_id",
        "transactions",
        type_="foreignkey",
    )
    op.drop_column("transactions", "source_row_index")
    op.drop_column("transactions", "import_batch_id")
    op.drop_column("transactions", "fingerprint")
    op.drop_index(op.f("ix_import_batches_user_id"), table_name="import_batches")
    op.drop_table("import_batches")
