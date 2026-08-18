from typing import Annotated, Literal

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy.ext.asyncio import AsyncSession

from momen_pair.core.config import Settings, get_settings
from momen_pair.core.security import InvalidAccessTokenError, decode_access_token
from momen_pair.db.session import get_session
from momen_pair.modules.accounts.models import IdentityProvider
from momen_pair.modules.accounts.service import (
    AuthenticatedUser,
    AuthResult,
    IdentityConflictError,
    InvalidRefreshTokenError,
    UserUnavailableError,
    get_authenticated_user,
    login_with_social_code,
    revoke_all_sessions,
    revoke_session_by_refresh_token,
    rotate_refresh_token,
)
from momen_pair.modules.accounts.social_auth import (
    DisabledSocialAuthGateway,
    FakeSocialAuthGateway,
    InvalidSocialCodeError,
    SocialAuthGateway,
    SocialAuthUnavailableError,
)

router = APIRouter()
bearer_scheme = HTTPBearer(auto_error=False)


class SocialLoginRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    code: str = Field(min_length=3, max_length=512)
    device_id: str = Field(min_length=1, max_length=128)


class RefreshRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    refresh_token: str = Field(min_length=32, max_length=512)


class AuthUserResponse(BaseModel):
    model_config = ConfigDict(frozen=True)

    id: str
    display_name: str
    provider: IdentityProvider


class AuthResponse(BaseModel):
    model_config = ConfigDict(frozen=True)

    access_token: str
    refresh_token: str
    token_type: Literal["Bearer"] = Field(default="Bearer")
    expires_in: int
    user: AuthUserResponse


class LogoutResponse(BaseModel):
    model_config = ConfigDict(frozen=True)

    status: Literal["ok"] = "ok"


def get_social_auth_gateway(
    settings: Annotated[Settings, Depends(get_settings)],
) -> SocialAuthGateway:
    if settings.social_auth_mode == "fake":
        return FakeSocialAuthGateway()
    return DisabledSocialAuthGateway()


async def get_current_user(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer_scheme)],
    session: Annotated[AsyncSession, Depends(get_session)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> AuthenticatedUser:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise _auth_error("access_token_required", status.HTTP_401_UNAUTHORIZED)
    try:
        claims = decode_access_token(credentials.credentials, settings)
        return await get_authenticated_user(session, claims.user_id, claims.session_id)
    except (InvalidAccessTokenError, UserUnavailableError) as error:
        raise _auth_error("access_token_invalid", status.HTTP_401_UNAUTHORIZED) from error


@router.post("/wechat/mobile", response_model=AuthResponse)
async def login_wechat(
    request: SocialLoginRequest,
    session: Annotated[AsyncSession, Depends(get_session)],
    gateway: Annotated[SocialAuthGateway, Depends(get_social_auth_gateway)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> AuthResponse:
    return await _login(IdentityProvider.WECHAT, request, session, gateway, settings)


@router.post("/qq/mobile", response_model=AuthResponse)
async def login_qq(
    request: SocialLoginRequest,
    session: Annotated[AsyncSession, Depends(get_session)],
    gateway: Annotated[SocialAuthGateway, Depends(get_social_auth_gateway)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> AuthResponse:
    return await _login(IdentityProvider.QQ, request, session, gateway, settings)


@router.post("/refresh", response_model=AuthResponse)
async def refresh(
    request: RefreshRequest,
    session: Annotated[AsyncSession, Depends(get_session)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> AuthResponse:
    try:
        result = await rotate_refresh_token(session, request.refresh_token, settings)
    except (InvalidRefreshTokenError, UserUnavailableError) as error:
        raise _auth_error("refresh_token_invalid", status.HTTP_401_UNAUTHORIZED) from error
    return _auth_response(result)


@router.get("/me", response_model=AuthUserResponse)
async def me(
    user: Annotated[AuthenticatedUser, Depends(get_current_user)],
) -> AuthUserResponse:
    return _user_response(user)


@router.post("/logout", response_model=LogoutResponse)
async def logout(
    request: RefreshRequest,
    session: Annotated[AsyncSession, Depends(get_session)],
) -> LogoutResponse:
    await revoke_session_by_refresh_token(session, request.refresh_token)
    return LogoutResponse()


@router.post("/logout-all", response_model=LogoutResponse)
async def logout_all(
    user: Annotated[AuthenticatedUser, Depends(get_current_user)],
    session: Annotated[AsyncSession, Depends(get_session)],
) -> LogoutResponse:
    await revoke_all_sessions(session, user.id)
    return LogoutResponse()


async def _login(
    provider: IdentityProvider,
    request: SocialLoginRequest,
    session: AsyncSession,
    gateway: SocialAuthGateway,
    settings: Settings,
) -> AuthResponse:
    try:
        result = await login_with_social_code(
            session,
            gateway,
            provider,
            request.code,
            request.device_id,
            settings,
        )
    except SocialAuthUnavailableError as error:
        raise _auth_error("social_auth_unavailable", status.HTTP_503_SERVICE_UNAVAILABLE) from error
    except InvalidSocialCodeError as error:
        raise _auth_error("social_code_invalid", status.HTTP_401_UNAUTHORIZED) from error
    except UserUnavailableError as error:
        raise _auth_error("user_unavailable", status.HTTP_403_FORBIDDEN) from error
    except IdentityConflictError as error:
        raise _auth_error("identity_conflict", status.HTTP_409_CONFLICT) from error
    return _auth_response(result)


def _auth_response(result: AuthResult) -> AuthResponse:
    return AuthResponse(
        access_token=result.access_token,
        refresh_token=result.refresh_token,
        expires_in=result.expires_in,
        user=_user_response(result.user),
    )


def _user_response(user: AuthenticatedUser) -> AuthUserResponse:
    return AuthUserResponse(
        id=user.id,
        display_name=user.display_name,
        provider=user.provider,
    )


def _auth_error(code: str, status_code: int) -> HTTPException:
    return HTTPException(
        status_code=status_code,
        detail={
            "code": code,
            "message_key": f"errors.{code}",
            "parameters": {},
        },
    )
