"""add verified statement coverage

Revision ID: d81f4b6c209a
Revises: c2d7a9f34e61
Create Date: 2026-08-20 21:00:00
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "d81f4b6c209a"
down_revision: Union[str, None] = "c2d7a9f34e61"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "import_batches",
        sa.Column("coverage_start_date", sa.Date(), nullable=True),
    )
    op.add_column(
        "import_batches",
        sa.Column("coverage_end_date", sa.Date(), nullable=True),
    )
    op.add_column(
        "import_batches",
        sa.Column("coverage_days", sa.Integer(), server_default="0", nullable=False),
    )
    op.add_column(
        "import_batches",
        sa.Column(
            "coverage_verified",
            sa.Boolean(),
            server_default=sa.false(),
            nullable=False,
        ),
    )


def downgrade() -> None:
    op.drop_column("import_batches", "coverage_verified")
    op.drop_column("import_batches", "coverage_days")
    op.drop_column("import_batches", "coverage_end_date")
    op.drop_column("import_batches", "coverage_start_date")
