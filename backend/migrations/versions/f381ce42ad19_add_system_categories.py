"""add income transfer and festival categories

Revision ID: f381ce42ad19
Revises: e927ab61c407
"""
from typing import Sequence, Union

from alembic import op

revision: str = "f381ce42ad19"
down_revision: Union[str, None] = "e927ab61c407"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute(
        """
        INSERT INTO categories (id, name) VALUES
            (gen_random_uuid(), 'Income'),
            (gen_random_uuid(), 'Transfer'),
            (gen_random_uuid(), 'Festival')
        ON CONFLICT (name) DO NOTHING;
        """
    )


def downgrade() -> None:
    op.execute(
        "DELETE FROM categories WHERE name IN ('Income', 'Transfer', 'Festival');"
    )
