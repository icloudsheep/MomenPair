"""Create family logs, comments, and likes.

Revision ID: 20260818_0005
Revises: 20260818_0004
Create Date: 2026-08-18 00:00:00
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "20260818_0005"
down_revision: str | Sequence[str] | None = "20260818_0004"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "family_logs",
        sa.Column("family_id", sa.String(length=36), nullable=False),
        sa.Column("author_user_id", sa.String(length=36), nullable=False),
        sa.Column("client_request_id", sa.String(length=64), nullable=False),
        sa.Column("title", sa.String(length=100), nullable=False),
        sa.Column("subtitle", sa.String(length=200), nullable=True),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("visibility", sa.String(length=20), nullable=False),
        sa.Column("status", sa.String(length=20), nullable=False),
        sa.Column("render_protocol_version", sa.Integer(), nullable=False),
        sa.Column("version", sa.Integer(), nullable=False),
        sa.Column("like_count", sa.Integer(), nullable=False),
        sa.Column("comment_count", sa.Integer(), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "visibility IN ('family', 'private')",
            name="ck_family_log_visibility",
        ),
        sa.CheckConstraint(
            "status IN ('published', 'deleted')",
            name="ck_family_log_status",
        ),
        sa.ForeignKeyConstraint(["author_user_id"], ["users.id"]),
        sa.ForeignKeyConstraint(["family_id"], ["families.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "author_user_id",
            "client_request_id",
            name="uq_family_log_author_request",
        ),
    )
    op.create_index(
        "ix_family_logs_family_status_created_id",
        "family_logs",
        ["family_id", "status", "created_at", "id"],
        unique=False,
    )
    op.create_index(
        "ix_family_logs_author_status",
        "family_logs",
        ["author_user_id", "status"],
        unique=False,
    )
    op.create_table(
        "log_comments",
        sa.Column("family_id", sa.String(length=36), nullable=False),
        sa.Column("log_id", sa.String(length=36), nullable=False),
        sa.Column("author_user_id", sa.String(length=36), nullable=False),
        sa.Column("root_comment_id", sa.String(length=36), nullable=True),
        sa.Column("reply_to_comment_id", sa.String(length=36), nullable=True),
        sa.Column("client_request_id", sa.String(length=64), nullable=False),
        sa.Column("title", sa.String(length=100), nullable=True),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("status", sa.String(length=20), nullable=False),
        sa.Column("version", sa.Integer(), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "status IN ('published', 'deleted')",
            name="ck_log_comment_status",
        ),
        sa.ForeignKeyConstraint(["author_user_id"], ["users.id"]),
        sa.ForeignKeyConstraint(["family_id"], ["families.id"]),
        sa.ForeignKeyConstraint(["log_id"], ["family_logs.id"]),
        sa.ForeignKeyConstraint(["reply_to_comment_id"], ["log_comments.id"]),
        sa.ForeignKeyConstraint(["root_comment_id"], ["log_comments.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "author_user_id",
            "client_request_id",
            name="uq_log_comment_author_request",
        ),
    )
    op.create_index(
        "ix_log_comments_log_created_id",
        "log_comments",
        ["log_id", "created_at", "id"],
        unique=False,
    )
    op.create_index(
        "ix_log_comments_family_status",
        "log_comments",
        ["family_id", "status"],
        unique=False,
    )
    op.create_table(
        "log_likes",
        sa.Column("family_id", sa.String(length=36), nullable=False),
        sa.Column("log_id", sa.String(length=36), nullable=False),
        sa.Column("user_id", sa.String(length=36), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.ForeignKeyConstraint(["family_id"], ["families.id"]),
        sa.ForeignKeyConstraint(["log_id"], ["family_logs.id"]),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("log_id", "user_id", name="uq_log_like_log_user"),
    )
    op.create_index(
        "ix_log_likes_family_user",
        "log_likes",
        ["family_id", "user_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_log_likes_family_user", table_name="log_likes")
    op.drop_table("log_likes")
    op.drop_index("ix_log_comments_family_status", table_name="log_comments")
    op.drop_index("ix_log_comments_log_created_id", table_name="log_comments")
    op.drop_table("log_comments")
    op.drop_index("ix_family_logs_author_status", table_name="family_logs")
    op.drop_index("ix_family_logs_family_status_created_id", table_name="family_logs")
    op.drop_table("family_logs")
