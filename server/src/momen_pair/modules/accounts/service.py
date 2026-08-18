from dataclasses import dataclass
from datetime import UTC, datetime, timedelta

from sqlalchemy import select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from momen_pair.core.config import Settings
from momen_pair.core.security import create_access_token, create_refresh_token, hash_refresh_token
from momen_pair.modules.accounts.models import (
    AuthSession,
    IdentityProvider,
    LoginIdentity,
    RefreshToken,
    User,
    UserStatus,
)
from momen_pair.modules.accounts.social_auth import SocialAuthGateway


class InvalidRefreshTokenError(ValueError):
    pass


class UserUnavailableError(RuntimeError):
    pass


class IdentityConflictError(RuntimeError):
    pass


@dataclass(frozen=True, slots=True)
class AuthenticatedUser:
    id: str
    display_name: str
    provider: IdentityProvider


@dataclass(frozen=True, slots=True)
class AuthResult:
    access_token: str
    refresh_token: str
    expires_in: int
    user: AuthenticatedUser


async def login_with_social_code(
    session: AsyncSession,
    gateway: SocialAuthGateway,
    provider: IdentityProvider,
    code: str,
    device_id: str,
    settings: Settings,
) -> AuthResult:
    social_identity = await gateway.exchange_code(provider, code)
    user = await _find_user_by_identity(session, provider, social_identity.provider_subject)
    if user is None:
        user = User(display_name=social_identity.display_name, status=UserStatus.ACTIVE)
        session.add(user)
        await session.flush()
        session.add(
            LoginIdentity(
                user_id=user.id,
                provider=provider.value,
                provider_subject=social_identity.provider_subject,
            )
        )
        try:
            await session.flush()
        except IntegrityError as error:
            await session.rollback()
            user = await _find_user_by_identity(
                session,
                provider,
                social_identity.provider_subject,
            )
            if user is None:
                raise IdentityConflictError from error
    if user.status != UserStatus.ACTIVE:
        await session.rollback()
        raise UserUnavailableError
    result = await _create_session(session, user, provider, device_id, settings)
    await session.commit()
    return result


async def rotate_refresh_token(
    session: AsyncSession,
    raw_refresh_token: str,
    settings: Settings,
) -> AuthResult:
    token_hash = hash_refresh_token(raw_refresh_token)
    statement = (
        select(RefreshToken, AuthSession, User, LoginIdentity)
        .join(AuthSession, RefreshToken.session_id == AuthSession.id)
        .join(User, AuthSession.user_id == User.id)
        .join(LoginIdentity, LoginIdentity.user_id == User.id)
        .where(RefreshToken.token_hash == token_hash)
        .with_for_update()
    )
    row = (await session.execute(statement)).one_or_none()
    if row is None:
        raise InvalidRefreshTokenError

    refresh_token, auth_session, user, identity = row
    now = datetime.now(UTC)
    if (
        refresh_token.used_at is not None
        or auth_session.revoked_at is not None
        or _as_utc(refresh_token.expires_at) <= now
        or _as_utc(auth_session.expires_at) <= now
    ):
        auth_session.revoked_at = now
        await session.commit()
        raise InvalidRefreshTokenError
    if user.status != UserStatus.ACTIVE:
        auth_session.revoked_at = now
        await session.commit()
        raise UserUnavailableError

    refresh_token.used_at = now
    new_raw_refresh_token = create_refresh_token()
    session.add(
        RefreshToken(
            session_id=auth_session.id,
            token_hash=hash_refresh_token(new_raw_refresh_token),
            expires_at=auth_session.expires_at,
        )
    )
    access_token, expires_in = create_access_token(user.id, auth_session.id, settings)
    await session.commit()
    return AuthResult(
        access_token=access_token,
        refresh_token=new_raw_refresh_token,
        expires_in=expires_in,
        user=_authenticated_user(user, identity),
    )


async def get_authenticated_user(
    session: AsyncSession,
    user_id: str,
    session_id: str,
) -> AuthenticatedUser:
    now = datetime.now(UTC)
    statement = (
        select(User, LoginIdentity)
        .join(AuthSession, AuthSession.user_id == User.id)
        .join(LoginIdentity, LoginIdentity.user_id == User.id)
        .where(
            User.id == user_id,
            User.status == UserStatus.ACTIVE,
            AuthSession.id == session_id,
            AuthSession.revoked_at.is_(None),
            AuthSession.expires_at > now,
        )
    )
    row = (await session.execute(statement)).one_or_none()
    if row is None:
        raise UserUnavailableError
    user, identity = row
    return _authenticated_user(user, identity)


async def revoke_session_by_refresh_token(
    session: AsyncSession,
    raw_refresh_token: str,
) -> None:
    token_hash = hash_refresh_token(raw_refresh_token)
    statement = (
        select(AuthSession)
        .join(RefreshToken, RefreshToken.session_id == AuthSession.id)
        .where(RefreshToken.token_hash == token_hash)
        .with_for_update()
    )
    auth_session = (await session.execute(statement)).scalar_one_or_none()
    if auth_session is not None and auth_session.revoked_at is None:
        auth_session.revoked_at = datetime.now(UTC)
        await session.commit()


async def revoke_all_sessions(session: AsyncSession, user_id: str) -> None:
    await session.execute(
        update(AuthSession)
        .where(AuthSession.user_id == user_id, AuthSession.revoked_at.is_(None))
        .values(revoked_at=datetime.now(UTC))
    )
    await session.commit()


async def _find_user_by_identity(
    session: AsyncSession,
    provider: IdentityProvider,
    provider_subject: str,
) -> User | None:
    statement = (
        select(User)
        .join(LoginIdentity, LoginIdentity.user_id == User.id)
        .where(
            LoginIdentity.provider == provider.value,
            LoginIdentity.provider_subject == provider_subject,
        )
    )
    return (await session.execute(statement)).scalar_one_or_none()


async def _create_session(
    session: AsyncSession,
    user: User,
    provider: IdentityProvider,
    device_id: str,
    settings: Settings,
) -> AuthResult:
    session_expires_at = datetime.now(UTC) + timedelta(days=settings.refresh_token_ttl_days)
    auth_session = AuthSession(
        user_id=user.id,
        device_id=device_id,
        expires_at=session_expires_at,
    )
    session.add(auth_session)
    await session.flush()
    raw_refresh_token = create_refresh_token()
    session.add(
        RefreshToken(
            session_id=auth_session.id,
            token_hash=hash_refresh_token(raw_refresh_token),
            expires_at=session_expires_at,
        )
    )
    access_token, expires_in = create_access_token(user.id, auth_session.id, settings)
    return AuthResult(
        access_token=access_token,
        refresh_token=raw_refresh_token,
        expires_in=expires_in,
        user=AuthenticatedUser(
            id=user.id,
            display_name=user.display_name,
            provider=provider,
        ),
    )


def _authenticated_user(user: User, identity: LoginIdentity) -> AuthenticatedUser:
    return AuthenticatedUser(
        id=user.id,
        display_name=user.display_name,
        provider=IdentityProvider(identity.provider),
    )


def _as_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=UTC)
    return value.astimezone(UTC)
