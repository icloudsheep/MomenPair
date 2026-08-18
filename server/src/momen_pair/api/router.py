from fastapi import APIRouter

from momen_pair.api.routes.auth import router as auth_router
from momen_pair.api.routes.families import router as families_router
from momen_pair.api.routes.health import router as health_router
from momen_pair.api.routes.logs import router as logs_router
from momen_pair.api.routes.meta import router as meta_router

api_router = APIRouter()
api_router.include_router(auth_router, prefix="/auth", tags=["auth"])
api_router.include_router(families_router, prefix="/families", tags=["families"])
api_router.include_router(health_router, prefix="/health", tags=["health"])
api_router.include_router(logs_router, prefix="/logs", tags=["logs"])
api_router.include_router(meta_router, prefix="/meta", tags=["meta"])
