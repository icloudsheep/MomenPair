"""Create family invitation records.

Revision ID: 20260818_0004
Revises: 20260817_0003
Create Date: 2026-08-18 00:00:00
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "20260818_0004"
down_revision: str | Sequence[str] | None = "20260817_0003"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_index(
        "ix_family_memberships_family_id_status_role",
        "family_memberships",
        ["family_id", "status", "role"],
        unique=False,
    )
    op.create_table(
        "family_invitations",
        sa.Column("family_id", sa.String(length=36), nullable=False),
        sa.Column("created_by_user_id", sa.String(length=36), nullable=False),
        sa.Column("code_hash", sa.String(length=64), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("max_uses", sa.Integer(), nullable=False),
        sa.Column("used_count", sa.Integer(), nullable=False),
        sa.Column("revoked_at", sa.DateTime(timezone=True), nullable=True),
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
        sa.ForeignKeyConstraint(["created_by_user_id"], ["users.id"]),
        sa.ForeignKeyConstraint(["family_id"], ["families.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("code_hash", name="uq_family_invitation_code_hash"),
    )
    op.create_index(
        "ix_family_invitations_family_id_revoked_at",
        "family_invitations",
        ["family_id", "revoked_at"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        "ix_family_invitations_family_id_revoked_at",
        table_name="family_invitations",
    )
    op.drop_table("family_invitations")
    op.drop_index(
        "ix_family_memberships_family_id_status_role",
        table_name="family_memberships",
    )
