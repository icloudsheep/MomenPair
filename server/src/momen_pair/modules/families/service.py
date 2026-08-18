import hashlib
import secrets
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from enum import StrEnum

from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from momen_pair.modules.accounts.models import User
from momen_pair.modules.families.models import (
    Family,
    FamilyInvitation,
    FamilyMembership,
    FamilyRole,
    MembershipStatus,
)


class FamilyServiceError(RuntimeError):
    pass


class FamilyNotFoundError(FamilyServiceError):
    pass


class AlreadyInFamilyError(FamilyServiceError):
    pass


class InvitationInvalidError(FamilyServiceError):
    pass


class FamilyPermissionDeniedError(FamilyServiceError):
    pass


class MemberNotFoundError(FamilyServiceError):
    pass


class LastAdminError(FamilyServiceError):
    pass


class CannotRemoveSelfError(FamilyServiceError):
    pass


class InvitationStatus(StrEnum):
    ACTIVE = "active"
    EXHAUSTED = "exhausted"
    EXPIRED = "expired"
    REVOKED = "revoked"


@dataclass(frozen=True, slots=True)
class FamilyDetails:
    id: str
    name: str
    role: FamilyRole
    member_count: int


@dataclass(frozen=True, slots=True)
class FamilyMemberDetails:
    user_id: str
    display_name: str
    role: FamilyRole
    joined_at: datetime


@dataclass(frozen=True, slots=True)
class InvitationDetails:
    id: str
    expires_at: datetime
    max_uses: int
    used_count: int
    status: InvitationStatus


@dataclass(frozen=True, slots=True)
class CreatedInvitation:
    invitation: InvitationDetails
    code: str


async def get_current_family(session: AsyncSession, user_id: str) -> FamilyDetails:
    statement = (
        select(Family, FamilyMembership)
        .join(FamilyMembership, FamilyMembership.family_id == Family.id)
        .where(
            FamilyMembership.user_id == user_id,
            FamilyMembership.status == MembershipStatus.ACTIVE.value,
        )
    )
    row = (await session.execute(statement)).one_or_none()
    if row is None:
        raise FamilyNotFoundError
    family, membership = row
    member_count, _ = await _family_counts(session, family.id)
    return FamilyDetails(
        id=family.id,
        name=family.name,
        role=FamilyRole(membership.role),
        member_count=member_count,
    )


async def create_family(session: AsyncSession, user_id: str, name: str) -> FamilyDetails:
    await _lock_user(session, user_id)
    if await _find_active_membership(session, user_id) is not None:
        raise AlreadyInFamilyError

    family = Family(name=name, created_by_user_id=user_id)
    session.add(family)
    await session.flush()
    session.add(
        FamilyMembership(
            family_id=family.id,
            user_id=user_id,
            role=FamilyRole.ADMIN.value,
            status=MembershipStatus.ACTIVE.value,
        )
    )
    await session.commit()
    return FamilyDetails(
        id=family.id,
        name=family.name,
        role=FamilyRole.ADMIN,
        member_count=1,
    )


async def join_family(session: AsyncSession, user_id: str, code: str) -> FamilyDetails:
    await _lock_user(session, user_id)
    if await _find_active_membership(session, user_id) is not None:
        raise AlreadyInFamilyError

    statement = (
        select(FamilyInvitation)
        .where(FamilyInvitation.code_hash == _hash_invitation_code(code))
        .with_for_update()
    )
    invitation = (await session.execute(statement)).scalar_one_or_none()
    now = datetime.now(UTC)
    if invitation is None or _invitation_status(invitation, now) != InvitationStatus.ACTIVE:
        raise InvitationInvalidError

    membership_statement = select(FamilyMembership).where(
        FamilyMembership.family_id == invitation.family_id,
        FamilyMembership.user_id == user_id,
    )
    membership = (await session.execute(membership_statement)).scalar_one_or_none()
    if membership is None:
        session.add(
            FamilyMembership(
                family_id=invitation.family_id,
                user_id=user_id,
                role=FamilyRole.MEMBER.value,
                status=MembershipStatus.ACTIVE.value,
            )
        )
    else:
        membership.role = FamilyRole.MEMBER.value
        membership.status = MembershipStatus.ACTIVE.value
        membership.joined_at = now
        membership.ended_at = None
    invitation.used_count += 1
    await session.commit()
    return await get_current_family(session, user_id)


async def list_family_members(
    session: AsyncSession,
    user_id: str,
) -> list[FamilyMemberDetails]:
    membership = await _require_membership(session, user_id)
    statement = (
        select(FamilyMembership, User)
        .join(User, User.id == FamilyMembership.user_id)
        .where(
            FamilyMembership.family_id == membership.family_id,
            FamilyMembership.status == MembershipStatus.ACTIVE.value,
        )
        .order_by(FamilyMembership.joined_at, FamilyMembership.id)
    )
    rows = (await session.execute(statement)).all()
    return [
        FamilyMemberDetails(
            user_id=member.user_id,
            display_name=user.display_name,
            role=FamilyRole(member.role),
            joined_at=member.joined_at,
        )
        for member, user in rows
    ]


async def create_family_invitation(
    session: AsyncSession,
    user_id: str,
    expires_in_hours: int,
    max_uses: int,
) -> CreatedInvitation:
    membership = await _require_admin(session, user_id)
    now = datetime.now(UTC)
    raw_code = secrets.token_urlsafe(24)
    invitation = FamilyInvitation(
        family_id=membership.family_id,
        created_by_user_id=user_id,
        code_hash=_hash_invitation_code(raw_code),
        expires_at=now + timedelta(hours=expires_in_hours),
        max_uses=max_uses,
        used_count=0,
    )
    session.add(invitation)
    await session.commit()
    return CreatedInvitation(
        invitation=_invitation_details(invitation, now),
        code=raw_code,
    )


async def list_family_invitations(
    session: AsyncSession,
    user_id: str,
) -> list[InvitationDetails]:
    membership = await _require_admin(session, user_id)
    statement = (
        select(FamilyInvitation)
        .where(FamilyInvitation.family_id == membership.family_id)
        .order_by(FamilyInvitation.created_at.desc())
    )
    invitations = (await session.execute(statement)).scalars().all()
    now = datetime.now(UTC)
    return [_invitation_details(invitation, now) for invitation in invitations]


async def revoke_family_invitation(
    session: AsyncSession,
    user_id: str,
    invitation_id: str,
) -> None:
    membership = await _require_admin(session, user_id)
    statement = (
        select(FamilyInvitation)
        .where(
            FamilyInvitation.id == invitation_id,
            FamilyInvitation.family_id == membership.family_id,
        )
        .with_for_update()
    )
    invitation = (await session.execute(statement)).scalar_one_or_none()
    if invitation is None:
        raise InvitationInvalidError
    if invitation.revoked_at is None:
        invitation.revoked_at = datetime.now(UTC)
        await session.commit()


async def leave_family(session: AsyncSession, user_id: str) -> None:
    membership = await _require_membership(session, user_id, lock=True)
    member_count, admin_count = await _family_counts(session, membership.family_id)
    if membership.role == FamilyRole.ADMIN.value and admin_count == 1 and member_count > 1:
        raise LastAdminError

    now = datetime.now(UTC)
    membership.status = MembershipStatus.LEFT.value
    membership.ended_at = now
    if member_count == 1:
        await _revoke_family_invitations(session, membership.family_id, now)
    await session.commit()


async def remove_family_member(
    session: AsyncSession,
    actor_user_id: str,
    target_user_id: str,
) -> None:
    actor = await _require_admin(session, actor_user_id)
    if actor_user_id == target_user_id:
        raise CannotRemoveSelfError
    target = await _find_family_member(session, actor.family_id, target_user_id, lock=True)
    if target is None:
        raise MemberNotFoundError
    if target.role == FamilyRole.ADMIN.value:
        _, admin_count = await _family_counts(session, actor.family_id)
        if admin_count == 1:
            raise LastAdminError
    target.status = MembershipStatus.REMOVED.value
    target.ended_at = datetime.now(UTC)
    await session.commit()


async def change_family_member_role(
    session: AsyncSession,
    actor_user_id: str,
    target_user_id: str,
    role: FamilyRole,
) -> FamilyMemberDetails:
    actor = await _require_admin(session, actor_user_id)
    target = await _find_family_member(session, actor.family_id, target_user_id, lock=True)
    if target is None:
        raise MemberNotFoundError
    if target.role == role.value:
        return await _member_details(session, target)
    if target.role == FamilyRole.ADMIN.value and role == FamilyRole.MEMBER:
        _, admin_count = await _family_counts(session, actor.family_id)
        if admin_count == 1:
            raise LastAdminError
    target.role = role.value
    await session.commit()
    return await _member_details(session, target)


async def _lock_user(session: AsyncSession, user_id: str) -> None:
    statement = select(User.id).where(User.id == user_id).with_for_update()
    await session.execute(statement)


async def _find_active_membership(
    session: AsyncSession,
    user_id: str,
) -> FamilyMembership | None:
    statement = select(FamilyMembership).where(
        FamilyMembership.user_id == user_id,
        FamilyMembership.status == MembershipStatus.ACTIVE.value,
    )
    return (await session.execute(statement)).scalar_one_or_none()


async def _require_membership(
    session: AsyncSession,
    user_id: str,
    *,
    lock: bool = False,
) -> FamilyMembership:
    statement = select(FamilyMembership).where(
        FamilyMembership.user_id == user_id,
        FamilyMembership.status == MembershipStatus.ACTIVE.value,
    )
    if lock:
        statement = statement.with_for_update()
    membership = (await session.execute(statement)).scalar_one_or_none()
    if membership is None:
        raise FamilyNotFoundError
    return membership


async def _require_admin(session: AsyncSession, user_id: str) -> FamilyMembership:
    membership = await _require_membership(session, user_id)
    if membership.role != FamilyRole.ADMIN.value:
        raise FamilyPermissionDeniedError
    return membership


async def _find_family_member(
    session: AsyncSession,
    family_id: str,
    user_id: str,
    *,
    lock: bool,
) -> FamilyMembership | None:
    statement = select(FamilyMembership).where(
        FamilyMembership.family_id == family_id,
        FamilyMembership.user_id == user_id,
        FamilyMembership.status == MembershipStatus.ACTIVE.value,
    )
    if lock:
        statement = statement.with_for_update()
    return (await session.execute(statement)).scalar_one_or_none()


async def _family_counts(session: AsyncSession, family_id: str) -> tuple[int, int]:
    member_statement = (
        select(func.count())
        .select_from(FamilyMembership)
        .where(
            FamilyMembership.family_id == family_id,
            FamilyMembership.status == MembershipStatus.ACTIVE.value,
        )
    )
    admin_statement = (
        select(func.count())
        .select_from(FamilyMembership)
        .where(
            FamilyMembership.family_id == family_id,
            FamilyMembership.status == MembershipStatus.ACTIVE.value,
            FamilyMembership.role == FamilyRole.ADMIN.value,
        )
    )
    member_count = int((await session.execute(member_statement)).scalar_one())
    admin_count = int((await session.execute(admin_statement)).scalar_one())
    return member_count, admin_count


async def _member_details(
    session: AsyncSession,
    membership: FamilyMembership,
) -> FamilyMemberDetails:
    user = (await session.execute(select(User).where(User.id == membership.user_id))).scalar_one()
    return FamilyMemberDetails(
        user_id=membership.user_id,
        display_name=user.display_name,
        role=FamilyRole(membership.role),
        joined_at=_as_utc(membership.joined_at),
    )


async def _revoke_family_invitations(
    session: AsyncSession,
    family_id: str,
    revoked_at: datetime,
) -> None:
    await session.execute(
        update(FamilyInvitation)
        .where(
            FamilyInvitation.family_id == family_id,
            FamilyInvitation.revoked_at.is_(None),
        )
        .values(revoked_at=revoked_at)
    )


def _hash_invitation_code(code: str) -> str:
    return hashlib.sha256(code.encode()).hexdigest()


def _invitation_details(
    invitation: FamilyInvitation,
    now: datetime,
) -> InvitationDetails:
    return InvitationDetails(
        id=invitation.id,
        expires_at=_as_utc(invitation.expires_at),
        max_uses=invitation.max_uses,
        used_count=invitation.used_count,
        status=_invitation_status(invitation, now),
    )


def _invitation_status(
    invitation: FamilyInvitation,
    now: datetime,
) -> InvitationStatus:
    if invitation.revoked_at is not None:
        return InvitationStatus.REVOKED
    if _as_utc(invitation.expires_at) <= now:
        return InvitationStatus.EXPIRED
    if invitation.used_count >= invitation.max_uses:
        return InvitationStatus.EXHAUSTED
    return InvitationStatus.ACTIVE


def _as_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=UTC)
    return value.astimezone(UTC)
