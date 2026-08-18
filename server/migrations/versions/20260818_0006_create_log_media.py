"""Create private image attachments for family logs.

Revision ID: 20260818_0006
Revises: 20260818_0005
Create Date: 2026-08-18 00:00:00
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "20260818_0006"
down_revision: str | Sequence[str] | None = "20260818_0005"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "log_media",
        sa.Column("family_id", sa.String(length=36), nullable=False),
        sa.Column("uploader_user_id", sa.String(length=36), nullable=False),
        sa.Column("log_id", sa.String(length=36), nullable=True),
        sa.Column("object_key", sa.String(length=255), nullable=False),
        sa.Column("content_type", sa.String(length=50), nullable=False),
        sa.Column("width", sa.Integer(), nullable=False),
        sa.Column("height", sa.Integer(), nullable=False),
        sa.Column("byte_size", sa.Integer(), nullable=False),
        sa.Column("sort_order", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.ForeignKeyConstraint(["family_id"], ["families.id"]),
        sa.ForeignKeyConstraint(["log_id"], ["family_logs.id"]),
        sa.ForeignKeyConstraint(["uploader_user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("object_key"),
    )
    op.create_index("ix_log_media_log_sort", "log_media", ["log_id", "sort_order"])
    op.create_index(
        "ix_log_media_family_uploader",
        "log_media",
        ["family_id", "uploader_user_id"],
    )
    op.create_index(
        "ix_log_media_pending_expiry",
        "log_media",
        ["log_id", "expires_at"],
    )


def downgrade() -> None:
    op.drop_index("ix_log_media_pending_expiry", table_name="log_media")
    op.drop_index("ix_log_media_family_uploader", table_name="log_media")
    op.drop_index("ix_log_media_log_sort", table_name="log_media")
    op.drop_table("log_media")
