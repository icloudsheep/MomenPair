"""Constrain login identities to independent QQ or WeChat accounts.

Revision ID: 20260817_0002
Revises: 20260817_0001
Create Date: 2026-08-17 00:00:00
"""

from collections.abc import Sequence

from alembic import op

revision: str = "20260817_0002"
down_revision: str | Sequence[str] | None = "20260817_0001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_check_constraint(
        "ck_login_identity_supported_provider",
        "login_identities",
        "provider IN ('wechat', 'qq')",
    )
    op.create_unique_constraint(
        "uq_login_identity_user_id",
        "login_identities",
        ["user_id"],
    )
    op.drop_index("ix_login_identities_user_id", table_name="login_identities")


def downgrade() -> None:
    op.create_index(
        "ix_login_identities_user_id",
        "login_identities",
        ["user_id"],
        unique=False,
    )
    op.drop_constraint(
        "uq_login_identity_user_id",
        "login_identities",
        type_="unique",
    )
    op.drop_constraint(
        "ck_login_identity_supported_provider",
        "login_identities",
        type_="check",
    )
