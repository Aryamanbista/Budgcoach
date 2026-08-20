"""Seed categories

Revision ID: 75fa9ab691c7
Revises: f44817fcb178
Create Date: 2026-08-20 12:06:53.681335

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
import uuid


# revision identifiers, used by Alembic.
revision: str = '75fa9ab691c7'
down_revision: Union[str, None] = 'f44817fcb178'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Use raw SQL to insert and handle ON CONFLICT
    op.execute(
        """
        INSERT INTO categories (id, name) VALUES
            (gen_random_uuid(), 'Food & Dining'),
            (gen_random_uuid(), 'Transport'),
            (gen_random_uuid(), 'Shopping'),
            (gen_random_uuid(), 'Entertainment'),
            (gen_random_uuid(), 'Health'),
            (gen_random_uuid(), 'Utilities'),
            (gen_random_uuid(), 'Education'),
            (gen_random_uuid(), 'Savings'),
            (gen_random_uuid(), 'Other')
        ON CONFLICT (name) DO NOTHING;
        """
    )


def downgrade() -> None:
    op.execute(
        """
        DELETE FROM categories WHERE name IN (
            'Food & Dining', 'Transport', 'Shopping', 'Entertainment',
            'Health', 'Utilities', 'Education', 'Savings', 'Other'
        );
        """
    )
