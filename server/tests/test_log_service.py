from collections.abc import AsyncIterator
from datetime import UTC, datetime, timedelta

import pytest
import pytest_asyncio
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from momen_pair.db.base import Base
from momen_pair.modules.accounts.models import User, UserStatus
from momen_pair.modules.families.models import FamilyMembership
from momen_pair.modules.families.service import (
    create_family,
    create_family_invitation,
    join_family,
    remove_family_member,
)
from momen_pair.modules.logs.models import FamilyLog, LogMedia
from momen_pair.modules.logs.service import (
    CommentNotFoundError,
    FamilyRequiredError,
    IdempotencyConflictError,
    InvalidCursorError,
    LogNotFoundError,
    LogPermissionDeniedError,
    LogVersionConflictError,
    create_comment,
    create_log,
    delete_comment,
    delete_log,
    get_log,
    like_log,
    list_comments,
    list_logs,
    unlike_log,
    update_log,
)


@pytest_asyncio.fixture
async def log_session() -> AsyncIterator[AsyncSession]:
    engine = create_async_engine("sqlite+aiosqlite://")
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
    session_factory = async_sessionmaker(engine, expire_on_commit=False)
    async with session_factory() as session:
        yield session
    await engine.dispose()


@pytest.mark.asyncio
async def test_log_creation_is_idempotent_and_updates_require_current_version(
    log_session: AsyncSession,
) -> None:
    author, member = await _create_family_with_member(log_session)

    created = await create_log(
        log_session,
        author.id,
        "request-0001",
        "First",
        "Subtitle",
        "Body",
    )
    replayed = await create_log(
        log_session,
        author.id,
        "request-0001",
        "First",
        "Subtitle",
        "Body",
    )

    assert replayed.id == created.id
    assert await log_session.scalar(select(func.count()).select_from(FamilyLog)) == 1
    with pytest.raises(IdempotencyConflictError):
        await create_log(
            log_session,
            author.id,
            "request-0001",
            "Changed",
            None,
            "Body",
        )
    with pytest.raises(LogPermissionDeniedError):
        await update_log(
            log_session,
            member.id,
            created.id,
            created.version,
            "Changed",
            None,
            "Body",
        )

    updated = await update_log(
        log_session,
        author.id,
        created.id,
        created.version,
        "Changed",
        None,
        "New body",
    )
    assert updated.version == 2
    assert updated.title == "Changed"
    with pytest.raises(LogVersionConflictError):
        await update_log(
            log_session,
            author.id,
            created.id,
            created.version,
            "Stale",
            None,
            "Body",
        )


@pytest.mark.asyncio
async def test_log_creation_attaches_ordered_pending_media(
    log_session: AsyncSession,
) -> None:
    author, _ = await _create_family_with_member(log_session)
    family_id = await log_session.scalar(
        select(FamilyMembership.family_id).where(FamilyMembership.user_id == author.id)
    )
    assert family_id is not None
    now = datetime.now(UTC)
    media = LogMedia(
        family_id=family_id,
        uploader_user_id=author.id,
        object_key="logs/test/image.webp",
        content_type="image/webp",
        width=1200,
        height=800,
        byte_size=2048,
        sort_order=0,
        created_at=now,
        expires_at=now + timedelta(hours=1),
    )
    log_session.add(media)
    await log_session.commit()

    created = await create_log(
        log_session,
        author.id,
        "request-media-1",
        "With photo",
        None,
        "Body",
        [media.id],
    )

    assert [item.id for item in created.media] == [media.id]
    assert media.log_id == created.id
    assert media.expires_at is None
    with pytest.raises(IdempotencyConflictError):
        await create_log(
            log_session,
            author.id,
            "request-media-1",
            "With photo",
            None,
            "Body",
            [],
        )


@pytest.mark.asyncio
async def test_log_list_uses_cursor_and_soft_delete_hides_content(
    log_session: AsyncSession,
) -> None:
    author, _ = await _create_family_with_member(log_session)
    created = [
        await create_log(
            log_session,
            author.id,
            f"request-000{index}",
            f"Log {index}",
            None,
            "Body",
        )
        for index in range(1, 4)
    ]

    first_page = await list_logs(log_session, author.id, None, 2)
    assert len(first_page.items) == 2
    assert first_page.next_cursor is not None
    second_page = await list_logs(log_session, author.id, first_page.next_cursor, 2)
    assert len(second_page.items) == 1
    assert {item.id for item in first_page.items + second_page.items} == {
        item.id for item in created
    }
    with pytest.raises(InvalidCursorError):
        await list_logs(log_session, author.id, "not-a-cursor", 2)

    target = created[0]
    await delete_log(log_session, author.id, target.id, target.version)
    with pytest.raises(LogNotFoundError):
        await get_log(log_session, author.id, target.id)
    with pytest.raises(IdempotencyConflictError):
        await create_log(
            log_session,
            author.id,
            "request-0001",
            "Log 1",
            None,
            "Body",
        )


@pytest.mark.asyncio
async def test_likes_comments_and_replies_are_idempotent_and_two_level(
    log_session: AsyncSession,
) -> None:
    author, member = await _create_family_with_member(log_session)
    log = await create_log(
        log_session,
        author.id,
        "request-log1",
        "Family day",
        None,
        "Body",
    )

    first_like = await like_log(log_session, member.id, log.id)
    replayed_like = await like_log(log_session, member.id, log.id)
    assert first_like.like_count == replayed_like.like_count == 1
    assert (await unlike_log(log_session, member.id, log.id)).like_count == 0
    assert (await unlike_log(log_session, member.id, log.id)).like_count == 0

    root = await create_comment(
        log_session,
        member.id,
        log.id,
        "comment-0001",
        "Question",
        "Looks great",
        None,
    )
    replayed = await create_comment(
        log_session,
        member.id,
        log.id,
        "comment-0001",
        "Question",
        "Looks great",
        None,
    )
    reply = await create_comment(
        log_session,
        author.id,
        log.id,
        "comment-0002",
        None,
        "Thank you",
        root.id,
    )
    nested_reply = await create_comment(
        log_session,
        member.id,
        log.id,
        "comment-0003",
        None,
        "You are welcome",
        reply.id,
    )
    assert replayed.id == root.id
    assert reply.root_comment_id == root.id
    assert nested_reply.root_comment_id == root.id

    await delete_comment(log_session, member.id, log.id, root.id, root.version)
    comments = await list_comments(log_session, author.id, log.id)
    deleted_root = next(item for item in comments if item.id == root.id)
    assert deleted_root.deleted is True
    assert deleted_root.body is None
    assert len(comments) == 3


@pytest.mark.asyncio
async def test_log_access_follows_current_family_membership(
    log_session: AsyncSession,
) -> None:
    author, member = await _create_family_with_member(log_session)
    outsider = await _create_user(log_session, "Outsider")
    await create_family(log_session, outsider.id, "Other home")
    log = await create_log(
        log_session,
        author.id,
        "request-log1",
        "Private family moment",
        None,
        "Body",
    )

    with pytest.raises(LogNotFoundError):
        await get_log(log_session, outsider.id, log.id)

    other_log = await create_log(
        log_session,
        outsider.id,
        "request-log2",
        "Other family",
        None,
        "Body",
    )
    with pytest.raises(CommentNotFoundError):
        await create_comment(
            log_session,
            member.id,
            log.id,
            "comment-0001",
            None,
            "Reply",
            (
                await create_comment(
                    log_session,
                    outsider.id,
                    other_log.id,
                    "comment-0002",
                    None,
                    "Other",
                    None,
                )
            ).id,
        )

    await remove_family_member(log_session, author.id, member.id)
    with pytest.raises(FamilyRequiredError):
        await list_logs(log_session, member.id, None, 20)


async def _create_family_with_member(session: AsyncSession) -> tuple[User, User]:
    author = await _create_user(session, "Author")
    member = await _create_user(session, "Member")
    await create_family(session, author.id, "Home")
    invitation = await create_family_invitation(session, author.id, 24, 1)
    await join_family(session, member.id, invitation.code)
    return author, member


async def _create_user(session: AsyncSession, name: str) -> User:
    user = User(display_name=name, status=UserStatus.ACTIVE.value)
    session.add(user)
    await session.commit()
    return user
