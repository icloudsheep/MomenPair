from datetime import datetime
from enum import StrEnum

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column

from momen_pair.db.base import Base, TimestampMixin, UuidPrimaryKeyMixin


class ContentVisibility(StrEnum):
    FAMILY = "family"
    PRIVATE = "private"


class ContentStatus(StrEnum):
    PUBLISHED = "published"
    DELETED = "deleted"


class FamilyLog(UuidPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "family_logs"
    __table_args__ = (
        CheckConstraint(
            "visibility IN ('family', 'private')",
            name="ck_family_log_visibility",
        ),
        CheckConstraint(
            "status IN ('published', 'deleted')",
            name="ck_family_log_status",
        ),
        UniqueConstraint(
            "author_user_id",
            "client_request_id",
            name="uq_family_log_author_request",
        ),
        Index(
            "ix_family_logs_family_status_created_id",
            "family_id",
            "status",
            "created_at",
            "id",
        ),
        Index("ix_family_logs_author_status", "author_user_id", "status"),
    )

    family_id: Mapped[str] = mapped_column(ForeignKey("families.id"), nullable=False)
    author_user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), nullable=False)
    client_request_id: Mapped[str] = mapped_column(String(64), nullable=False)
    title: Mapped[str] = mapped_column(String(100), nullable=False)
    subtitle: Mapped[str | None] = mapped_column(String(200))
    body: Mapped[str] = mapped_column(Text, nullable=False)
    visibility: Mapped[str] = mapped_column(
        String(20),
        default=ContentVisibility.FAMILY.value,
        nullable=False,
    )
    status: Mapped[str] = mapped_column(
        String(20),
        default=ContentStatus.PUBLISHED.value,
        nullable=False,
    )
    render_protocol_version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    like_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    comment_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class LogMedia(UuidPrimaryKeyMixin, Base):
    __tablename__ = "log_media"
    __table_args__ = (
        Index("ix_log_media_log_sort", "log_id", "sort_order"),
        Index("ix_log_media_family_uploader", "family_id", "uploader_user_id"),
        Index("ix_log_media_pending_expiry", "log_id", "expires_at"),
    )

    family_id: Mapped[str] = mapped_column(ForeignKey("families.id"), nullable=False)
    uploader_user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), nullable=False)
    log_id: Mapped[str | None] = mapped_column(ForeignKey("family_logs.id"))
    object_key: Mapped[str] = mapped_column(String(255), unique=True, nullable=False)
    content_type: Mapped[str] = mapped_column(String(50), nullable=False)
    width: Mapped[int] = mapped_column(Integer, nullable=False)
    height: Mapped[int] = mapped_column(Integer, nullable=False)
    byte_size: Mapped[int] = mapped_column(Integer, nullable=False)
    sort_order: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class LogComment(UuidPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "log_comments"
    __table_args__ = (
        CheckConstraint(
            "status IN ('published', 'deleted')",
            name="ck_log_comment_status",
        ),
        UniqueConstraint(
            "author_user_id",
            "client_request_id",
            name="uq_log_comment_author_request",
        ),
        Index(
            "ix_log_comments_log_created_id",
            "log_id",
            "created_at",
            "id",
        ),
        Index("ix_log_comments_family_status", "family_id", "status"),
    )

    family_id: Mapped[str] = mapped_column(ForeignKey("families.id"), nullable=False)
    log_id: Mapped[str] = mapped_column(ForeignKey("family_logs.id"), nullable=False)
    author_user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), nullable=False)
    root_comment_id: Mapped[str | None] = mapped_column(ForeignKey("log_comments.id"))
    reply_to_comment_id: Mapped[str | None] = mapped_column(ForeignKey("log_comments.id"))
    client_request_id: Mapped[str] = mapped_column(String(64), nullable=False)
    title: Mapped[str | None] = mapped_column(String(100))
    body: Mapped[str] = mapped_column(Text, nullable=False)
    status: Mapped[str] = mapped_column(
        String(20),
        default=ContentStatus.PUBLISHED.value,
        nullable=False,
    )
    version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class LogLike(UuidPrimaryKeyMixin, Base):
    __tablename__ = "log_likes"
    __table_args__ = (
        UniqueConstraint("log_id", "user_id", name="uq_log_like_log_user"),
        Index("ix_log_likes_family_user", "family_id", "user_id"),
    )

    family_id: Mapped[str] = mapped_column(ForeignKey("families.id"), nullable=False)
    log_id: Mapped[str] = mapped_column(ForeignKey("family_logs.id"), nullable=False)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
