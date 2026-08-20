"""add persistent personalized nudges

Revision ID: c2d7a9f34e61
Revises: 8b1f6e4a2c90
Create Date: 2026-08-20 19:00:00
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "c2d7a9f34e61"
down_revision: Union[str, None] = "8b1f6e4a2c90"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "nudges",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("nudge_key", sa.String(length=160), nullable=False),
        sa.Column("type", sa.String(length=16), nullable=False),
        sa.Column("title", sa.String(length=160), nullable=False),
        sa.Column("message", sa.String(length=600), nullable=False),
        sa.Column("category", sa.String(length=80), nullable=True),
        sa.Column("action_label", sa.String(length=80), nullable=True),
        sa.Column("action_route", sa.String(length=120), nullable=True),
        sa.Column("priority", sa.Integer(), nullable=False),
        sa.Column("metric_data", sa.JSON(), nullable=False),
        sa.Column(
            "generated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("dismissed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "nudge_key", name="uq_nudge_user_key"),
    )
    op.create_index(op.f("ix_nudges_user_id"), "nudges", ["user_id"], unique=False)


def downgrade() -> None:
    op.drop_index(op.f("ix_nudges_user_id"), table_name="nudges")
    op.drop_table("nudges")
