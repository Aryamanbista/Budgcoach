"""add persistent user financial profile

Revision ID: e927ab61c407
Revises: d81f4b6c209a
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "e927ab61c407"
down_revision: Union[str, None] = "d81f4b6c209a"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("users", sa.Column("occupation", sa.String(), nullable=True))
    op.add_column(
        "users",
        sa.Column("monthly_income", sa.Numeric(14, 2), nullable=False, server_default="0"),
    )
    op.alter_column("users", "monthly_income", server_default=None)


def downgrade() -> None:
    op.drop_column("users", "monthly_income")
    op.drop_column("users", "occupation")
