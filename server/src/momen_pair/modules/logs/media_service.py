import asyncio
import warnings
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from io import BytesIO
from uuid import uuid4

from PIL import Image, ImageOps, UnidentifiedImageError
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from momen_pair.infrastructure.object_storage import ObjectStorage
from momen_pair.modules.families.models import FamilyMembership, MembershipStatus
from momen_pair.modules.logs.models import ContentStatus, FamilyLog, LogMedia

MAX_UPLOAD_BYTES = 10 * 1024 * 1024
MAX_IMAGE_PIXELS = 40_000_000
MAX_IMAGE_EDGE = 2560
PENDING_MEDIA_TTL = timedelta(hours=24)


class MediaServiceError(RuntimeError):
    pass


class InvalidImageError(MediaServiceError):
    pass


class MediaNotFoundError(MediaServiceError):
    pass


@dataclass(frozen=True, slots=True)
class ProcessedImage:
    content: bytes
    content_type: str
    width: int
    height: int


@dataclass(frozen=True, slots=True)
class MediaContent:
    content: bytes
    content_type: str


def process_image(content: bytes) -> ProcessedImage:
    if not content or len(content) > MAX_UPLOAD_BYTES:
        raise InvalidImageError
    try:
        with warnings.catch_warnings():
            warnings.simplefilter("error", Image.DecompressionBombWarning)
            with Image.open(BytesIO(content)) as source:
                if source.width * source.height > MAX_IMAGE_PIXELS:
                    raise InvalidImageError
                source.verify()
            with Image.open(BytesIO(content)) as source:
                if getattr(source, "n_frames", 1) != 1:
                    raise InvalidImageError
                image = ImageOps.exif_transpose(source).convert("RGB")
                image.thumbnail((MAX_IMAGE_EDGE, MAX_IMAGE_EDGE), Image.Resampling.LANCZOS)
                output = BytesIO()
                image.save(output, format="WEBP", quality=82, method=6)
                return ProcessedImage(
                    content=output.getvalue(),
                    content_type="image/webp",
                    width=image.width,
                    height=image.height,
                )
    except (
        Image.DecompressionBombError,
        Image.DecompressionBombWarning,
        OSError,
        UnidentifiedImageError,
        ValueError,
    ) as error:
        raise InvalidImageError from error


async def upload_media(
    session: AsyncSession,
    storage: ObjectStorage,
    user_id: str,
    content: bytes,
) -> LogMedia:
    family_id = await _require_family_id(session, user_id)
    image = await asyncio.to_thread(process_image, content)
    now = datetime.now(UTC)
    object_key = f"logs/{family_id}/{uuid4()}.webp"
    await storage.put(object_key, image.content, image.content_type)
    media = LogMedia(
        family_id=family_id,
        uploader_user_id=user_id,
        object_key=object_key,
        content_type=image.content_type,
        width=image.width,
        height=image.height,
        byte_size=len(image.content),
        sort_order=0,
        created_at=now,
        expires_at=now + PENDING_MEDIA_TTL,
    )
    session.add(media)
    try:
        await session.commit()
    except Exception:
        await storage.remove(object_key)
        raise
    return media


async def get_media_content(
    session: AsyncSession,
    storage: ObjectStorage,
    user_id: str,
    media_id: str,
) -> MediaContent:
    family_id = await _require_family_id(session, user_id)
    media = await session.scalar(
        select(LogMedia).where(
            LogMedia.id == media_id,
            LogMedia.family_id == family_id,
            LogMedia.deleted_at.is_(None),
        )
    )
    if media is None or not await _can_read_media(session, media, user_id):
        raise MediaNotFoundError
    return MediaContent(
        content=await storage.get(media.object_key),
        content_type=media.content_type,
    )


async def delete_pending_media(
    session: AsyncSession,
    storage: ObjectStorage,
    user_id: str,
    media_id: str,
) -> None:
    family_id = await _require_family_id(session, user_id)
    media = await session.scalar(
        select(LogMedia).where(
            LogMedia.id == media_id,
            LogMedia.family_id == family_id,
            LogMedia.uploader_user_id == user_id,
            LogMedia.log_id.is_(None),
            LogMedia.deleted_at.is_(None),
        )
    )
    if media is None:
        raise MediaNotFoundError
    media.deleted_at = datetime.now(UTC)
    await session.commit()
    await storage.remove(media.object_key)


async def _can_read_media(
    session: AsyncSession,
    media: LogMedia,
    user_id: str,
) -> bool:
    if media.log_id is None:
        return media.uploader_user_id == user_id and (
            media.expires_at is None or _as_utc(media.expires_at) > datetime.now(UTC)
        )
    log_id = await session.scalar(
        select(FamilyLog.id).where(
            FamilyLog.id == media.log_id,
            FamilyLog.family_id == media.family_id,
            FamilyLog.status == ContentStatus.PUBLISHED.value,
        )
    )
    return log_id is not None


async def _require_family_id(session: AsyncSession, user_id: str) -> str:
    family_id = await session.scalar(
        select(FamilyMembership.family_id).where(
            FamilyMembership.user_id == user_id,
            FamilyMembership.status == MembershipStatus.ACTIVE.value,
        )
    )
    if family_id is None:
        from momen_pair.modules.logs.service import FamilyRequiredError

        raise FamilyRequiredError
    return family_id


def _as_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=UTC)
    return value.astimezone(UTC)
