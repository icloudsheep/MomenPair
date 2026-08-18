from collections.abc import AsyncIterator

import pytest
import pytest_asyncio
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from momen_pair.db.base import Base
from momen_pair.modules.accounts.models import User, UserStatus
from momen_pair.modules.families.models import FamilyInvitation, FamilyRole
from momen_pair.modules.families.service import (
    AlreadyInFamilyError,
    FamilyNotFoundError,
    InvitationInvalidError,
    LastAdminError,
    change_family_member_role,
    create_family,
    create_family_invitation,
    get_current_family,
    join_family,
    leave_family,
    list_family_members,
    remove_family_member,
)


@pytest_asyncio.fixture
async def family_session() -> AsyncIterator[AsyncSession]:
    engine = create_async_engine("sqlite+aiosqlite://")
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
    session_factory = async_sessionmaker(engine, expire_on_commit=False)
    async with session_factory() as session:
        yield session
    await engine.dispose()


@pytest.mark.asyncio
async def test_invitation_is_one_time_and_stores_only_hash(
    family_session: AsyncSession,
) -> None:
    creator, first_member, second_member = await _create_users(
        family_session,
        "Creator",
        "First",
        "Second",
    )
    family = await create_family(family_session, creator.id, "Home")
    created = await create_family_invitation(family_session, creator.id, 24, 1)

    joined = await join_family(family_session, first_member.id, created.code)
    with pytest.raises(InvitationInvalidError):
        await join_family(family_session, second_member.id, created.code)

    stored = await family_session.get(FamilyInvitation, created.invitation.id)
    assert stored is not None
    assert stored.code_hash != created.code
    assert family.id == joined.id
    assert joined.member_count == 2


@pytest.mark.asyncio
async def test_user_cannot_join_or_create_a_second_active_family(
    family_session: AsyncSession,
) -> None:
    creator, other_admin = await _create_users(family_session, "Creator", "Other")
    await create_family(family_session, creator.id, "First home")
    await create_family(family_session, other_admin.id, "Second home")
    invitation = await create_family_invitation(family_session, other_admin.id, 24, 1)

    with pytest.raises(AlreadyInFamilyError):
        await join_family(family_session, creator.id, invitation.code)
    with pytest.raises(AlreadyInFamilyError):
        await create_family(family_session, creator.id, "Third home")


@pytest.mark.asyncio
async def test_last_admin_transfers_role_before_leaving(
    family_session: AsyncSession,
) -> None:
    creator, member = await _create_users(family_session, "Creator", "Member")
    await create_family(family_session, creator.id, "Home")
    invitation = await create_family_invitation(family_session, creator.id, 24, 1)
    await join_family(family_session, member.id, invitation.code)

    with pytest.raises(LastAdminError):
        await leave_family(family_session, creator.id)

    await change_family_member_role(
        family_session,
        creator.id,
        member.id,
        FamilyRole.ADMIN,
    )
    await leave_family(family_session, creator.id)

    with pytest.raises(FamilyNotFoundError):
        await get_current_family(family_session, creator.id)
    remaining_family = await get_current_family(family_session, member.id)
    assert remaining_family.role == FamilyRole.ADMIN
    assert remaining_family.member_count == 1


@pytest.mark.asyncio
async def test_removed_member_immediately_loses_family_access(
    family_session: AsyncSession,
) -> None:
    creator, member = await _create_users(family_session, "Creator", "Member")
    await create_family(family_session, creator.id, "Home")
    invitation = await create_family_invitation(family_session, creator.id, 24, 1)
    await join_family(family_session, member.id, invitation.code)

    await remove_family_member(family_session, creator.id, member.id)

    with pytest.raises(FamilyNotFoundError):
        await get_current_family(family_session, member.id)
    members = await list_family_members(family_session, creator.id)
    assert [item.user_id for item in members] == [creator.id]


async def _create_users(session: AsyncSession, *names: str) -> tuple[User, ...]:
    users = tuple(User(display_name=name, status=UserStatus.ACTIVE.value) for name in names)
    session.add_all(users)
    await session.commit()
    return users
