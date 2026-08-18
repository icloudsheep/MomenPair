from datetime import datetime
from enum import StrEnum

from sqlalchemy import DateTime, ForeignKey, Index, Integer, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from momen_pair.db.base import Base, TimestampMixin, UuidPrimaryKeyMixin


class FamilyRole(StrEnum):
    ADMIN = "admin"
    MEMBER = "member"


class MembershipStatus(StrEnum):
    ACTIVE = "active"
    LEFT = "left"
    REMOVED = "removed"


class Family(UuidPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "families"

    name: Mapped[str] = mapped_column(String(80), nullable=False)
    created_by_user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), nullable=False)


class FamilyMembership(UuidPrimaryKeyMixin, Base):
    __tablename__ = "family_memberships"
    __table_args__ = (
        UniqueConstraint("family_id", "user_id", name="uq_family_membership"),
        Index("ix_family_memberships_user_id_status", "user_id", "status"),
        Index(
            "ix_family_memberships_family_id_status_role",
            "family_id",
            "status",
            "role",
        ),
    )

    family_id: Mapped[str] = mapped_column(ForeignKey("families.id"), nullable=False)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), nullable=False)
    role: Mapped[str] = mapped_column(String(20), default=FamilyRole.MEMBER, nullable=False)
    status: Mapped[str] = mapped_column(
        String(20),
        default=MembershipStatus.ACTIVE,
        nullable=False,
    )
    joined_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    ended_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class FamilyInvitation(UuidPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "family_invitations"
    __table_args__ = (
        UniqueConstraint("code_hash", name="uq_family_invitation_code_hash"),
        Index(
            "ix_family_invitations_family_id_revoked_at",
            "family_id",
            "revoked_at",
        ),
    )

    family_id: Mapped[str] = mapped_column(ForeignKey("families.id"), nullable=False)
    created_by_user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), nullable=False)
    code_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    max_uses: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    used_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
