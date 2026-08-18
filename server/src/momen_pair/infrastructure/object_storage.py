import asyncio
from functools import lru_cache
from io import BytesIO
from urllib.parse import urlparse

from minio import Minio

from momen_pair.core.config import get_settings


class ObjectStorage:
    def __init__(self, client: Minio, bucket: str) -> None:
        self._client = client
        self._bucket = bucket
        self._bucket_ready = False
        self._bucket_lock = asyncio.Lock()

    async def put(self, object_key: str, content: bytes, content_type: str) -> None:
        await self._ensure_bucket()
        await asyncio.to_thread(
            self._client.put_object,
            self._bucket,
            object_key,
            BytesIO(content),
            len(content),
            content_type=content_type,
        )

    async def get(self, object_key: str) -> bytes:
        await self._ensure_bucket()
        response = await asyncio.to_thread(
            self._client.get_object,
            self._bucket,
            object_key,
        )
        try:
            return await asyncio.to_thread(response.read)
        finally:
            response.close()
            response.release_conn()

    async def remove(self, object_key: str) -> None:
        await self._ensure_bucket()
        await asyncio.to_thread(
            self._client.remove_object,
            self._bucket,
            object_key,
        )

    async def _ensure_bucket(self) -> None:
        if self._bucket_ready:
            return
        async with self._bucket_lock:
            if self._bucket_ready:
                return
            exists = await asyncio.to_thread(self._client.bucket_exists, self._bucket)
            if not exists:
                await asyncio.to_thread(self._client.make_bucket, self._bucket)
            self._bucket_ready = True


@lru_cache
def get_object_storage() -> ObjectStorage:
    settings = get_settings()
    endpoint = urlparse(settings.object_storage_endpoint)
    client = Minio(
        endpoint.netloc or endpoint.path,
        access_key=settings.object_storage_access_key.get_secret_value(),
        secret_key=settings.object_storage_secret_key.get_secret_value(),
        secure=endpoint.scheme == "https",
    )
    return ObjectStorage(client, settings.object_storage_bucket)
