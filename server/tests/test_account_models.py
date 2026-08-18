from sqlalchemy import CheckConstraint, UniqueConstraint

from momen_pair.modules.accounts.models import (
    AuthSession,
    IdentityProvider,
    LoginIdentity,
    RefreshToken,
)


def test_only_qq_and_wechat_are_login_providers() -> None:
    assert set(IdentityProvider) == {IdentityProvider.QQ, IdentityProvider.WECHAT}


def test_each_user_has_exactly_one_login_identity() -> None:
    unique_constraints = {
        constraint.name: tuple(column.name for column in constraint.columns)
        for constraint in LoginIdentity.__table__.constraints
        if isinstance(constraint, UniqueConstraint)
    }

    assert unique_constraints["uq_login_identity_user_id"] == ("user_id",)
    assert unique_constraints["uq_identity_provider_subject"] == (
        "provider",
        "provider_subject",
    )


def test_database_rejects_unsupported_login_providers() -> None:
    check_constraints = {
        constraint.name: str(constraint.sqltext)
        for constraint in LoginIdentity.__table__.constraints
        if isinstance(constraint, CheckConstraint)
    }

    assert check_constraints["ck_login_identity_supported_provider"] == (
        "provider IN ('wechat', 'qq')"
    )


def test_refresh_tokens_are_unique_and_bound_to_sessions() -> None:
    unique_constraints = {
        constraint.name: tuple(column.name for column in constraint.columns)
        for constraint in RefreshToken.__table__.constraints
        if isinstance(constraint, UniqueConstraint)
    }

    assert unique_constraints["uq_refresh_token_hash"] == ("token_hash",)
    assert AuthSession.__table__.c.user_id.foreign_keys
    assert RefreshToken.__table__.c.session_id.foreign_keys
