from dataclasses import asdict
from datetime import datetime
from typing import Annotated, Literal, NoReturn

from fastapi import (
    APIRouter,
    Depends,
    File,
    Header,
    HTTPException,
    Query,
    Response,
    UploadFile,
    status,
)
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy.ext.asyncio import AsyncSession

from momen_pair.api.routes.auth import get_current_user
from momen_pair.db.session import get_session
from momen_pair.infrastructure.object_storage import ObjectStorage, get_object_storage
from momen_pair.modules.accounts.service import AuthenticatedUser
from momen_pair.modules.logs.media_service import (
    MAX_UPLOAD_BYTES,
    InvalidImageError,
    MediaNotFoundError,
    MediaServiceError,
    delete_pending_media,
    get_media_content,
    upload_media,
)
from momen_pair.modules.logs.models import LogMedia
from momen_pair.modules.logs.service import (
    CommentDetails,
    CommentNotFoundError,
    FamilyRequiredError,
    IdempotencyConflictError,
    InvalidCursorError,
    LogDetails,
    LogMediaDetails,
    LogNotFoundError,
    LogPermissionDeniedError,
    LogServiceError,
    LogVersionConflictError,
    ReactionDetails,
    create_comment,
    create_log,
    delete_comment,
    delete_log,
    get_log,
    like_log,
    list_comments,
    list_logs,
    unlike_log,
    update_comment,
    update_log,
)

router = APIRouter()


class CreateLogRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    title: str = Field(min_length=1, max_length=100)
    subtitle: str | None = Field(default=None, max_length=200)
    body: str = Field(min_length=1, max_length=50_000)
    media_ids: list[str] = Field(default_factory=list, max_length=9)


class UpdateLogRequest(CreateLogRequest):
    expected_version: int = Field(ge=1)


class CreateCommentRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    title: str | None = Field(default=None, max_length=100)
    body: str = Field(min_length=1, max_length=10_000)
    reply_to_comment_id: str | None = Field(default=None, min_length=1, max_length=36)


class UpdateCommentRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    title: str | None = Field(default=None, max_length=100)
    body: str = Field(min_length=1, max_length=10_000)
    expected_version: int = Field(ge=1)


class LogMediaResponse(BaseModel):
    model_config = ConfigDict(frozen=True)

    id: str
    content_type: str
    width: int
    height: int
    byte_size: int
    content_url: str


class LogResponse(BaseModel):
    model_config = ConfigDict(frozen=True)

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
    media: list[LogMediaResponse]
    created_at: datetime
    updated_at: datetime


class LogPageResponse(BaseModel):
    model_config = ConfigDict(frozen=True)

    items: list[LogResponse]
    next_cursor: str | None


class ReactionResponse(BaseModel):
    model_config = ConfigDict(frozen=True)

    liked: bool
    like_count: int


class CommentResponse(BaseModel):
    model_config = ConfigDict(frozen=True)

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


class LogActionResponse(BaseModel):
    model_config = ConfigDict(frozen=True)

    status: Literal["ok"] = "ok"


@router.get("", response_model=LogPageResponse)
async def index(
    user: Annotated[AuthenticatedUser, Depends(get_current_user)],
    session: Annotated[AsyncSession, Depends(get_session)],
    cursor: Annotated[str | None, Query(max_length=1024)] = None,
    limit: Annotated[int, Query(ge=1, le=50)] = 20,
) -> LogPageResponse:
    try:
        page = await list_logs(session, user.id, cursor, limit)
    except LogServiceError as error:
        _raise_log_error(error)
    return LogPageResponse(
        items=[_log_response(item) for item in page.items],
        next_cursor=page.next_cursor,
    )


@router.post("", response_model=LogResponse, status_code=status.HTTP_201_CREATED)
async def create(
    request: CreateLogRequest,
    user: Annotated[AuthenticatedUser, Depends(get_current_user)],
    session: Annotated[AsyncSession, Depends(get_session)],
    idempotency_key: Annotated[
        str,
        Header(alias="Idempotency-Key", min_length=8, max_length=64),
    ],
) -> LogResponse:
    try:
        item = await create_log(
            session,
            user.id,
            idempotency_key,
            request.title,
            request.subtitle or None,
            request.body,
            request.media_ids,
        )
    except LogServiceError as error:
        _raise_log_error(error)
    return _log_response(item)


@router.post(
    "/media",
    response_model=LogMediaResponse,
    status_code=status.HTTP_201_CREATED,
)
async def add_media(
    image: Annotated[UploadFile, File()],
    user: Annotated[AuthenticatedUser, Depends(get_current_user)],
    session: Annotated[AsyncSession, Depends(get_session)],
    storage: Annotated[ObjectStorage, Depends(get_object_storage)],
) -> LogMediaResponse:
    content = await image.read(MAX_UPLOAD_BYTES + 1)
    try:
        item = await upload_media(session, storage, user.id, content)
    except MediaServiceError as error:
        _raise_media_error(error)
    except LogServiceError as error:
        _raise_log_error(error)
    return _media_response(item)


@router.get("/media/{media_id}/content")
async def media_content(
    media_id: str,
    user: Annotated[AuthenticatedUser, Depends(get_current_user)],
    session: Annotated[AsyncSession, Depends(get_session)],
    storage: Annotated[ObjectStorage, Depends(get_object_storage)],
) -> Response:
    try:
        item = await get_media_content(session, storage, user.id, media_id)
    except MediaServiceError as error:
        _raise_media_error(error)
    except LogServiceError as error:
        _raise_log_error(error)
    return Response(
        content=item.content,
        media_type=item.content_type,
        headers={"Cache-Control": "private, max-age=3600"},
    )


@router.delete("/media/{media_id}", response_model=LogActionResponse)
async def remove_pending_media(
    media_id: str,
    user: Annotated[AuthenticatedUser, Depends(get_current_user)],
    session: Annotated[AsyncSession, Depends(get_session)],
    storage: Annotated[ObjectStorage, Depends(get_object_storage)],
) -> LogActionResponse:
    try:
        await delete_pending_media(session, storage, user.id, media_id)
    except MediaServiceError as error:
        _raise_media_error(error)
    except LogServiceError as error:
        _raise_log_error(error)
    return LogActionResponse()


@router.get("/{log_id}", response_model=LogResponse)
async def detail(
    log_id: str,
    user: Annotated[AuthenticatedUser, Depends(get_current_user)],
    session: Annotated[AsyncSession, Depends(get_session)],
) -> LogResponse:
    try:
        item = await get_log(session, user.id, log_id)
    except LogServiceError as error:
        _raise_log_error(error)
    return _log_response(item)


@router.patch("/{log_id}", response_model=LogResponse)
async def update(
    log_id: str,
    request: UpdateLogRequest,
    user: Annotated[AuthenticatedUser, Depends(get_current_user)],
    session: Annotated[AsyncSession, Depends(get_session)],
) -> LogResponse:
    try:
        item = await update_log(
            session,
            user.id,
            log_id,
            request.expected_version,
            request.title,
            request.subtitle or None,
            request.body,
            request.media_ids,
        )
    except LogServiceError as error:
        _raise_log_error(error)
    return _log_response(item)


@router.delete("/{log_id}", response_model=LogActionResponse)
async def delete(
    log_id: str,
    user: Annotated[AuthenticatedUser, Depends(get_current_user)],
    session: Annotated[AsyncSession, Depends(get_session)],
    expected_version: Annotated[int, Query(ge=1)],
) -> LogActionResponse:
    try:
        await delete_log(session, user.id, log_id, expected_version)
    except LogServiceError as error:
        _raise_log_error(error)
    return LogActionResponse()


@router.put("/{log_id}/like", response_model=ReactionResponse)
async def like(
    log_id: str,
    user: Annotated[AuthenticatedUser, Depends(get_current_user)],
    session: Annotated[AsyncSession, Depends(get_session)],
) -> ReactionResponse:
    try:
        reaction = await like_log(session, user.id, log_id)
    except LogServiceError as error:
        _raise_log_error(error)
    return _reaction_response(reaction)


@router.delete("/{log_id}/like", response_model=ReactionResponse)
async def unlike(
    log_id: str,
    user: Annotated[AuthenticatedUser, Depends(get_current_user)],
    session: Annotated[AsyncSession, Depends(get_session)],
) -> ReactionResponse:
    try:
        reaction = await unlike_log(session, user.id, log_id)
    except LogServiceError as error:
        _raise_log_error(error)
    return _reaction_response(reaction)


@router.get("/{log_id}/comments", response_model=list[CommentResponse])
async def comments(
    log_id: str,
    user: Annotated[AuthenticatedUser, Depends(get_current_user)],
    session: Annotated[AsyncSession, Depends(get_session)],
) -> list[CommentResponse]:
    try:
        items = await list_comments(session, user.id, log_id)
    except LogServiceError as error:
        _raise_log_error(error)
    return [_comment_response(item) for item in items]


@router.post(
    "/{log_id}/comments",
    response_model=CommentResponse,
    status_code=status.HTTP_201_CREATED,
)
async def add_comment(
    log_id: str,
    request: CreateCommentRequest,
    user: Annotated[AuthenticatedUser, Depends(get_current_user)],
    session: Annotated[AsyncSession, Depends(get_session)],
    idempotency_key: Annotated[
        str,
        Header(alias="Idempotency-Key", min_length=8, max_length=64),
    ],
) -> CommentResponse:
    try:
        item = await create_comment(
            session,
            user.id,
            log_id,
            idempotency_key,
            request.title or None,
            request.body,
            request.reply_to_comment_id,
        )
    except LogServiceError as error:
        _raise_log_error(error)
    return _comment_response(item)


@router.patch("/{log_id}/comments/{comment_id}", response_model=CommentResponse)
async def edit_comment(
    log_id: str,
    comment_id: str,
    request: UpdateCommentRequest,
    user: Annotated[AuthenticatedUser, Depends(get_current_user)],
    session: Annotated[AsyncSession, Depends(get_session)],
) -> CommentResponse:
    try:
        item = await update_comment(
            session,
            user.id,
            log_id,
            comment_id,
            request.expected_version,
            request.title or None,
            request.body,
        )
    except LogServiceError as error:
        _raise_log_error(error)
    return _comment_response(item)


@router.delete("/{log_id}/comments/{comment_id}", response_model=LogActionResponse)
async def remove_comment(
    log_id: str,
    comment_id: str,
    user: Annotated[AuthenticatedUser, Depends(get_current_user)],
    session: Annotated[AsyncSession, Depends(get_session)],
    expected_version: Annotated[int, Query(ge=1)],
) -> LogActionResponse:
    try:
        await delete_comment(session, user.id, log_id, comment_id, expected_version)
    except LogServiceError as error:
        _raise_log_error(error)
    return LogActionResponse()


def _log_response(item: LogDetails) -> LogResponse:
    payload = asdict(item)
    payload["media"] = [_media_response(media) for media in item.media]
    return LogResponse(**payload)


def _media_response(item: LogMediaDetails | LogMedia) -> LogMediaResponse:
    media_id = item.id
    return LogMediaResponse(
        id=media_id,
        content_type=item.content_type,
        width=item.width,
        height=item.height,
        byte_size=item.byte_size,
        content_url=f"/api/v1/logs/media/{media_id}/content",
    )


def _reaction_response(item: ReactionDetails) -> ReactionResponse:
    return ReactionResponse(liked=item.liked, like_count=item.like_count)


def _comment_response(item: CommentDetails) -> CommentResponse:
    return CommentResponse(**asdict(item))


def _raise_log_error(error: LogServiceError) -> NoReturn:
    mappings: dict[type[LogServiceError], tuple[str, int]] = {
        FamilyRequiredError: ("family_required", status.HTTP_409_CONFLICT),
        LogNotFoundError: ("log_not_found", status.HTTP_404_NOT_FOUND),
        CommentNotFoundError: ("comment_not_found", status.HTTP_404_NOT_FOUND),
        LogPermissionDeniedError: ("log_permission_denied", status.HTTP_403_FORBIDDEN),
        LogVersionConflictError: ("log_version_conflict", status.HTTP_409_CONFLICT),
        InvalidCursorError: ("invalid_cursor", status.HTTP_400_BAD_REQUEST),
        IdempotencyConflictError: ("idempotency_conflict", status.HTTP_409_CONFLICT),
    }
    code, status_code = mappings.get(
        type(error),
        ("log_operation_failed", status.HTTP_400_BAD_REQUEST),
    )
    raise HTTPException(status_code=status_code, detail={"code": code}) from error


def _raise_media_error(error: MediaServiceError) -> NoReturn:
    mappings: dict[type[MediaServiceError], tuple[str, int]] = {
        InvalidImageError: ("invalid_log_image", status.HTTP_422_UNPROCESSABLE_CONTENT),
        MediaNotFoundError: ("log_media_not_found", status.HTTP_404_NOT_FOUND),
    }
    code, status_code = mappings.get(
        type(error),
        ("log_media_operation_failed", status.HTTP_400_BAD_REQUEST),
    )
    raise HTTPException(status_code=status_code, detail={"code": code}) from error
