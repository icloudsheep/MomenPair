from datetime import datetime
from enum import StrEnum

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Index, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from momen_pair.db.base import Base, TimestampMixin, UuidPrimaryKeyMixin


class UserStatus(StrEnum):
    ACTIVE = "active"
    DISABLED = "disabled"
    DELETED = "deleted"


class IdentityProvider(StrEnum):
    WECHAT = "wechat"
    QQ = "qq"


class User(UuidPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "users"

    display_name: Mapped[str] = mapped_column(String(30), nullable=False)
    avatar_object_key: Mapped[str | None] = mapped_column(String(512))
    status: Mapped[str] = mapped_column(String(20), default=UserStatus.ACTIVE, nullable=False)


class LoginIdentity(UuidPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "login_identities"
    __table_args__ = (
        CheckConstraint(
            "provider IN ('wechat', 'qq')",
            name="ck_login_identity_supported_provider",
        ),
        UniqueConstraint("user_id", name="uq_login_identity_user_id"),
        UniqueConstraint("provider", "provider_subject", name="uq_identity_provider_subject"),
    )

    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), nullable=False)
    provider: Mapped[str] = mapped_column(String(20), nullable=False)
    provider_subject: Mapped[str] = mapped_column(String(191), nullable=False)


class AuthSession(UuidPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "auth_sessions"
    __table_args__ = (Index("ix_auth_sessions_user_id_revoked_at", "user_id", "revoked_at"),)

    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), nullable=False)
    device_id: Mapped[str] = mapped_column(String(128), nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class RefreshToken(UuidPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "refresh_tokens"
    __table_args__ = (
        UniqueConstraint("token_hash", name="uq_refresh_token_hash"),
        Index("ix_refresh_tokens_session_id", "session_id"),
    )

    session_id: Mapped[str] = mapped_column(ForeignKey("auth_sessions.id"), nullable=False)
    token_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
