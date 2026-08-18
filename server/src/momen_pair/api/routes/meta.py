from fastapi import APIRouter
from pydantic import BaseModel, ConfigDict

from momen_pair import __version__

router = APIRouter()


class ServiceMeta(BaseModel):
    model_config = ConfigDict(frozen=True)

    name: str
    version: str
    api_version: str
    modules: tuple[str, ...]


@router.get("", response_model=ServiceMeta)
async def meta() -> ServiceMeta:
    return ServiceMeta(
        name="momen-pair-server",
        version=__version__,
        api_version="v1",
        modules=(
            "accounts",
            "families",
            "logs",
            "notices",
            "countdowns",
            "notifications",
            "media",
        ),
    )
