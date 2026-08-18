import base64
import json
from dataclasses import dataclass
from datetime import UTC, datetime

from sqlalchemy import and_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from momen_pair.modules.accounts.models import User
from momen_pair.modules.families.models import FamilyMembership, MembershipStatus
from momen_pair.modules.logs.models import (
    ContentStatus,
    ContentVisibility,
    FamilyLog,
    LogComment,
    LogLike,
    LogMedia,
)


class LogServiceError(RuntimeError):
    pass


class FamilyRequiredError(LogServiceError):
    pass


class LogNotFoundError(LogServiceError):
    pass


class LogPermissionDeniedError(LogServiceError):
    pass


class LogVersionConflictError(LogServiceError):
    pass


class InvalidCursorError(LogServiceError):
    pass


class IdempotencyConflictError(LogServiceError):
    pass


class CommentNotFoundError(LogServiceError):
    pass


@dataclass(frozen=True, slots=True)
class LogMediaDetails:
    id: str
    content_type: str
    width: int
    height: int
    byte_size: int


@dataclass(frozen=True, slots=True)
class LogDetails:
    id: str
    author_user_id: str
    author_display_name: str
    title: str
    subtitle: str | None
    body: str
    version: int
    like_count: int
    comment_count: int
    liked_by_me: bool
    media: list[LogMediaDetails]
    created_at: datetime
    updated_at: datetime


@dataclass(frozen=True, slots=True)
class LogPage:
    items: list[LogDetails]
    next_cursor: str | None


@dataclass(frozen=True, slots=True)
class ReactionDetails:
    liked: bool
    like_count: int


@dataclass(frozen=True, slots=True)
class CommentDetails:
    id: str
    author_user_id: str
    author_display_name: str
    root_comment_id: str | None
    reply_to_comment_id: str | None
    title: str | None
    body: str | None
    version: int
    deleted: bool
    created_at: datetime
    updated_at: datetime


async def create_log(
    session: AsyncSession,
    user_id: str,
    client_request_id: str,
    title: str,
    subtitle: str | None,
    body: str,
    media_ids: list[str] | None = None,
) -> LogDetails:
    family_id = await _require_family_id(session, user_id, lock=True)
    existing = await _find_log_by_request(session, user_id, client_request_id)
    if existing is not None:
        existing_media = await _media_by_log_ids(session, [existing.id])
        existing_media_ids = [item.id for item in existing_media.get(existing.id, [])]
        if (
            existing.family_id != family_id
            or existing.status != ContentStatus.PUBLISHED.value
            or (existing.title, existing.subtitle, existing.body) != (title, subtitle, body)
            or (media_ids is not None and existing_media_ids != media_ids)
        ):
            raise IdempotencyConflictError
        await session.commit()
        return await _log_details(session, existing, user_id)

    now = datetime.now(UTC)
    log = FamilyLog(
        family_id=family_id,
        author_user_id=user_id,
        client_request_id=client_request_id,
        title=title,
        subtitle=subtitle,
        body=body,
        visibility=ContentVisibility.FAMILY.value,
        status=ContentStatus.PUBLISHED.value,
        render_protocol_version=1,
        version=1,
        like_count=0,
        comment_count=0,
        created_at=now,
        updated_at=now,
    )
    session.add(log)
    await session.flush()
    await _set_log_media(
        session,
        log,
        user_id,
        family_id,
        media_ids or [],
    )
    await session.commit()
    return await _log_details(session, log, user_id)


async def list_logs(
    session: AsyncSession,
    user_id: str,
    cursor: str | None,
    limit: int,
) -> LogPage:
    family_id = await _require_family_id(session, user_id)
    statement = (
        select(FamilyLog, User)
        .join(User, User.id == FamilyLog.author_user_id)
        .where(
            FamilyLog.family_id == family_id,
            FamilyLog.status == ContentStatus.PUBLISHED.value,
            FamilyLog.visibility == ContentVisibility.FAMILY.value,
        )
        .order_by(FamilyLog.created_at.desc(), FamilyLog.id.desc())
        .limit(limit + 1)
    )
    if cursor is not None:
        cursor_time, cursor_id = _decode_cursor(cursor)
        statement = statement.where(
            or_(
                FamilyLog.created_at < cursor_time,
                and_(FamilyLog.created_at == cursor_time, FamilyLog.id < cursor_id),
            )
        )
    rows = list((await session.execute(statement)).all())
    has_more = len(rows) > limit
    visible_rows = rows[:limit]
    liked_ids = await _liked_log_ids(
        session,
        user_id,
        [log.id for log, _ in visible_rows],
    )
    media_by_log = await _media_by_log_ids(
        session,
        [log.id for log, _ in visible_rows],
    )
    items = [
        _to_log_details(log, author, log.id in liked_ids, media_by_log.get(log.id, []))
        for log, author in visible_rows
    ]
    next_cursor = None
    if has_more and visible_rows:
        last_log = visible_rows[-1][0]
        next_cursor = _encode_cursor(last_log.created_at, last_log.id)
    return LogPage(items=items, next_cursor=next_cursor)


async def get_log(session: AsyncSession, user_id: str, log_id: str) -> LogDetails:
    family_id = await _require_family_id(session, user_id)
    log, author = await _find_visible_log(session, family_id, log_id)
    liked = await _is_liked(session, user_id, log.id)
    media_by_log = await _media_by_log_ids(session, [log.id])
    return _to_log_details(log, author, liked, media_by_log.get(log.id, []))


async def update_log(
    session: AsyncSession,
    user_id: str,
    log_id: str,
    expected_version: int,
    title: str,
    subtitle: str | None,
    body: str,
    media_ids: list[str] | None = None,
) -> LogDetails:
    family_id = await _require_family_id(session, user_id)
    log = await _find_log_for_update(session, family_id, log_id)
    if log.author_user_id != user_id:
        raise LogPermissionDeniedError
    if log.version != expected_version:
        raise LogVersionConflictError
    log.title = title
    log.subtitle = subtitle
    log.body = body
    if media_ids is not None:
        await _set_log_media(session, log, user_id, family_id, media_ids)
    log.version += 1
    log.updated_at = datetime.now(UTC)
    await session.commit()
    return await _log_details(session, log, user_id)


async def delete_log(
    session: AsyncSession,
    user_id: str,
    log_id: str,
    expected_version: int,
) -> None:
    family_id = await _require_family_id(session, user_id)
    log = await _find_log_for_update(session, family_id, log_id)
    if log.author_user_id != user_id:
        raise LogPermissionDeniedError
    if log.version != expected_version:
        raise LogVersionConflictError
    log.status = ContentStatus.DELETED.value
    log.deleted_at = datetime.now(UTC)
    log.version += 1
    log.updated_at = log.deleted_at
    await session.commit()


async def like_log(
    session: AsyncSession,
    user_id: str,
    log_id: str,
) -> ReactionDetails:
    family_id = await _require_family_id(session, user_id)
    log = await _find_log_for_update(session, family_id, log_id)
    existing = await session.scalar(
        select(LogLike)
        .where(LogLike.log_id == log_id, LogLike.user_id == user_id)
        .with_for_update()
    )
    if existing is None:
        session.add(
            LogLike(
                family_id=family_id,
                log_id=log_id,
                user_id=user_id,
                created_at=datetime.now(UTC),
            )
        )
        log.like_count += 1
    await session.commit()
    return ReactionDetails(liked=True, like_count=log.like_count)


async def unlike_log(
    session: AsyncSession,
    user_id: str,
    log_id: str,
) -> ReactionDetails:
    family_id = await _require_family_id(session, user_id)
    log = await _find_log_for_update(session, family_id, log_id)
    existing = await session.scalar(
        select(LogLike)
        .where(LogLike.log_id == log_id, LogLike.user_id == user_id)
        .with_for_update()
    )
    if existing is not None:
        await session.delete(existing)
        log.like_count = max(0, log.like_count - 1)
    await session.commit()
    return ReactionDetails(liked=False, like_count=log.like_count)


async def list_comments(
    session: AsyncSession,
    user_id: str,
    log_id: str,
) -> list[CommentDetails]:
    family_id = await _require_family_id(session, user_id)
    await _find_visible_log(session, family_id, log_id)
    statement = (
        select(LogComment, User)
        .join(User, User.id == LogComment.author_user_id)
        .where(LogComment.family_id == family_id, LogComment.log_id == log_id)
        .order_by(LogComment.created_at, LogComment.id)
    )
    rows = (await session.execute(statement)).all()
    return [_to_comment_details(comment, author) for comment, author in rows]


async def create_comment(
    session: AsyncSession,
    user_id: str,
    log_id: str,
    client_request_id: str,
    title: str | None,
    body: str,
    reply_to_comment_id: str | None,
) -> CommentDetails:
    family_id = await _require_family_id(session, user_id, lock=True)
    log = await _find_log_for_update(session, family_id, log_id)
    existing = await session.scalar(
        select(LogComment).where(
            LogComment.author_user_id == user_id,
            LogComment.client_request_id == client_request_id,
        )
    )
    if existing is not None:
        expected = (log_id, title, body, reply_to_comment_id)
        actual = (existing.log_id, existing.title, existing.body, existing.reply_to_comment_id)
        if actual != expected:
            raise IdempotencyConflictError
        await session.commit()
        return await _comment_details(session, existing)

    root_comment_id = None
    if reply_to_comment_id is not None:
        target = await session.scalar(
            select(LogComment).where(
                LogComment.id == reply_to_comment_id,
                LogComment.family_id == family_id,
                LogComment.log_id == log_id,
                LogComment.status == ContentStatus.PUBLISHED.value,
            )
        )
        if target is None:
            raise CommentNotFoundError
        root_comment_id = target.root_comment_id or target.id

    now = datetime.now(UTC)
    comment = LogComment(
        family_id=family_id,
        log_id=log_id,
        author_user_id=user_id,
        root_comment_id=root_comment_id,
        reply_to_comment_id=reply_to_comment_id,
        client_request_id=client_request_id,
        title=title,
        body=body,
        status=ContentStatus.PUBLISHED.value,
        version=1,
        created_at=now,
        updated_at=now,
    )
    session.add(comment)
    log.comment_count += 1
    await session.commit()
    return await _comment_details(session, comment)


async def update_comment(
    session: AsyncSession,
    user_id: str,
    log_id: str,
    comment_id: str,
    expected_version: int,
    title: str | None,
    body: str,
) -> CommentDetails:
    family_id = await _require_family_id(session, user_id)
    await _find_visible_log(session, family_id, log_id)
    comment = await _find_comment_for_update(session, family_id, log_id, comment_id)
    if comment.author_user_id != user_id:
        raise LogPermissionDeniedError
    if comment.version != expected_version:
        raise LogVersionConflictError
    comment.title = title
    comment.body = body
    comment.version += 1
    comment.updated_at = datetime.now(UTC)
    await session.commit()
    return await _comment_details(session, comment)


async def delete_comment(
    session: AsyncSession,
    user_id: str,
    log_id: str,
    comment_id: str,
    expected_version: int,
) -> None:
    family_id = await _require_family_id(session, user_id)
    log = await _find_log_for_update(session, family_id, log_id)
    comment = await _find_comment_for_update(session, family_id, log_id, comment_id)
    if comment.author_user_id != user_id:
        raise LogPermissionDeniedError
    if comment.version != expected_version:
        raise LogVersionConflictError
    comment.status = ContentStatus.DELETED.value
    comment.deleted_at = datetime.now(UTC)
    comment.version += 1
    comment.updated_at = comment.deleted_at
    log.comment_count = max(0, log.comment_count - 1)
    await session.commit()


async def _require_family_id(
    session: AsyncSession,
    user_id: str,
    *,
    lock: bool = False,
) -> str:
    statement = select(FamilyMembership.family_id).where(
        FamilyMembership.user_id == user_id,
        FamilyMembership.status == MembershipStatus.ACTIVE.value,
    )
    if lock:
        statement = statement.with_for_update()
    family_id = await session.scalar(statement)
    if family_id is None:
        raise FamilyRequiredError
    return family_id


async def _find_log_by_request(
    session: AsyncSession,
    user_id: str,
    client_request_id: str,
) -> FamilyLog | None:
    statement = select(FamilyLog).where(
        FamilyLog.author_user_id == user_id,
        FamilyLog.client_request_id == client_request_id,
    )
    return (await session.execute(statement)).scalar_one_or_none()


async def _find_visible_log(
    session: AsyncSession,
    family_id: str,
    log_id: str,
) -> tuple[FamilyLog, User]:
    row = (
        await session.execute(
            select(FamilyLog, User)
            .join(User, User.id == FamilyLog.author_user_id)
            .where(
                FamilyLog.id == log_id,
                FamilyLog.family_id == family_id,
                FamilyLog.status == ContentStatus.PUBLISHED.value,
                FamilyLog.visibility == ContentVisibility.FAMILY.value,
            )
        )
    ).one_or_none()
    if row is None:
        raise LogNotFoundError
    return row[0], row[1]


async def _find_log_for_update(
    session: AsyncSession,
    family_id: str,
    log_id: str,
) -> FamilyLog:
    log = await session.scalar(
        select(FamilyLog)
        .where(
            FamilyLog.id == log_id,
            FamilyLog.family_id == family_id,
            FamilyLog.status == ContentStatus.PUBLISHED.value,
            FamilyLog.visibility == ContentVisibility.FAMILY.value,
        )
        .with_for_update()
    )
    if log is None:
        raise LogNotFoundError
    return log


async def _find_comment_for_update(
    session: AsyncSession,
    family_id: str,
    log_id: str,
    comment_id: str,
) -> LogComment:
    comment = await session.scalar(
        select(LogComment)
        .where(
            LogComment.id == comment_id,
            LogComment.family_id == family_id,
            LogComment.log_id == log_id,
            LogComment.status == ContentStatus.PUBLISHED.value,
        )
        .with_for_update()
    )
    if comment is None:
        raise CommentNotFoundError
    return comment


async def _liked_log_ids(
    session: AsyncSession,
    user_id: str,
    log_ids: list[str],
) -> set[str]:
    if not log_ids:
        return set()
    values = await session.scalars(
        select(LogLike.log_id).where(LogLike.user_id == user_id, LogLike.log_id.in_(log_ids))
    )
    return set(values)


async def _is_liked(session: AsyncSession, user_id: str, log_id: str) -> bool:
    like_id = await session.scalar(
        select(LogLike.id).where(LogLike.user_id == user_id, LogLike.log_id == log_id)
    )
    return like_id is not None


async def _log_details(
    session: AsyncSession,
    log: FamilyLog,
    user_id: str,
) -> LogDetails:
    author = await session.get(User, log.author_user_id)
    if author is None:
        raise LogNotFoundError
    media_by_log = await _media_by_log_ids(session, [log.id])
    return _to_log_details(
        log,
        author,
        await _is_liked(session, user_id, log.id),
        media_by_log.get(log.id, []),
    )


async def _comment_details(
    session: AsyncSession,
    comment: LogComment,
) -> CommentDetails:
    author = await session.get(User, comment.author_user_id)
    if author is None:
        raise CommentNotFoundError
    return _to_comment_details(comment, author)


def _to_log_details(
    log: FamilyLog,
    author: User,
    liked_by_me: bool,
    media: list[LogMedia],
) -> LogDetails:
    return LogDetails(
        id=log.id,
        author_user_id=log.author_user_id,
        author_display_name=author.display_name,
        title=log.title,
        subtitle=log.subtitle,
        body=log.body,
        version=log.version,
        like_count=log.like_count,
        comment_count=log.comment_count,
        liked_by_me=liked_by_me,
        media=[
            LogMediaDetails(
                id=item.id,
                content_type=item.content_type,
                width=item.width,
                height=item.height,
                byte_size=item.byte_size,
            )
            for item in media
        ],
        created_at=_as_utc(log.created_at),
        updated_at=_as_utc(log.updated_at),
    )


async def _media_by_log_ids(
    session: AsyncSession,
    log_ids: list[str],
) -> dict[str, list[LogMedia]]:
    if not log_ids:
        return {}
    items = list(
        await session.scalars(
            select(LogMedia)
            .where(
                LogMedia.log_id.in_(log_ids),
                LogMedia.deleted_at.is_(None),
            )
            .order_by(LogMedia.log_id, LogMedia.sort_order, LogMedia.id)
        )
    )
    grouped: dict[str, list[LogMedia]] = {}
    for item in items:
        if item.log_id is not None:
            grouped.setdefault(item.log_id, []).append(item)
    return grouped


async def _set_log_media(
    session: AsyncSession,
    log: FamilyLog,
    user_id: str,
    family_id: str,
    media_ids: list[str],
) -> None:
    if len(media_ids) > 9 or len(set(media_ids)) != len(media_ids):
        raise LogServiceError
    current = list(
        await session.scalars(
            select(LogMedia)
            .where(LogMedia.log_id == log.id, LogMedia.deleted_at.is_(None))
            .with_for_update()
        )
    )
    requested = []
    if media_ids:
        requested = list(
            await session.scalars(
                select(LogMedia)
                .where(LogMedia.id.in_(media_ids), LogMedia.deleted_at.is_(None))
                .with_for_update()
            )
        )
    if len(requested) != len(media_ids):
        raise LogServiceError
    by_id = {item.id: item for item in requested}
    now = datetime.now(UTC)
    for position, media_id in enumerate(media_ids):
        item = by_id[media_id]
        owns_pending = (
            item.log_id is None
            and item.uploader_user_id == user_id
            and item.family_id == family_id
            and (item.expires_at is None or _as_utc(item.expires_at) > now)
        )
        already_attached = item.log_id == log.id
        if not owns_pending and not already_attached:
            raise LogPermissionDeniedError
        item.log_id = log.id
        item.sort_order = position
        item.expires_at = None
    requested_ids = set(media_ids)
    for item in current:
        if item.id not in requested_ids:
            item.log_id = None
            item.deleted_at = now


def _to_comment_details(comment: LogComment, author: User) -> CommentDetails:
    deleted = comment.status == ContentStatus.DELETED.value
    return CommentDetails(
        id=comment.id,
        author_user_id=comment.author_user_id,
        author_display_name=author.display_name,
        root_comment_id=comment.root_comment_id,
        reply_to_comment_id=comment.reply_to_comment_id,
        title=None if deleted else comment.title,
        body=None if deleted else comment.body,
        version=comment.version,
        deleted=deleted,
        created_at=_as_utc(comment.created_at),
        updated_at=_as_utc(comment.updated_at),
    )


def _encode_cursor(created_at: datetime, log_id: str) -> str:
    payload = json.dumps(
        {"created_at": _as_utc(created_at).isoformat(), "id": log_id},
        separators=(",", ":"),
    ).encode()
    return base64.urlsafe_b64encode(payload).decode().rstrip("=")


def _decode_cursor(cursor: str) -> tuple[datetime, str]:
    try:
        padding = "=" * (-len(cursor) % 4)
        value = json.loads(base64.urlsafe_b64decode(cursor + padding))
        created_at = datetime.fromisoformat(value["created_at"])
        log_id = value["id"]
        if not isinstance(log_id, str) or not log_id or created_at.tzinfo is None:
            raise ValueError
        return created_at.astimezone(UTC), log_id
    except (ValueError, TypeError, KeyError, json.JSONDecodeError) as error:
        raise InvalidCursorError from error


def _as_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=UTC)
    return value.astimezone(UTC)
