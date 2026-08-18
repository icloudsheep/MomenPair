from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from hashlib import sha256
from secrets import token_urlsafe
from uuid import uuid4

import jwt
from jwt import InvalidTokenError

from momen_pair.core.config import Settings

ACCESS_TOKEN_ALGORITHM = "HS256"  # noqa: S105


class InvalidAccessTokenError(ValueError):
    pass


@dataclass(frozen=True, slots=True)
class AccessTokenClaims:
    user_id: str
    session_id: str


def create_access_token(
    user_id: str,
    session_id: str,
    settings: Settings,
    *,
    now: datetime | None = None,
) -> tuple[str, int]:
    issued_at = now or datetime.now(UTC)
    expires_in = settings.access_token_ttl_minutes * 60
    expires_at = issued_at + timedelta(seconds=expires_in)
    payload = {
        "sub": user_id,
        "sid": session_id,
        "iat": issued_at,
        "exp": expires_at,
        "iss": settings.token_issuer,
        "aud": settings.token_audience,
        "jti": str(uuid4()),
    }
    encoded = jwt.encode(
        payload,
        settings.secret_key.get_secret_value(),
        algorithm=ACCESS_TOKEN_ALGORITHM,
    )
    return encoded, expires_in


def decode_access_token(token: str, settings: Settings) -> AccessTokenClaims:
    try:
        payload = jwt.decode(
            token,
            settings.secret_key.get_secret_value(),
            algorithms=[ACCESS_TOKEN_ALGORITHM],
            audience=settings.token_audience,
            issuer=settings.token_issuer,
            options={"require": ["sub", "sid", "iat", "exp", "iss", "aud", "jti"]},
        )
        user_id = payload["sub"]
        session_id = payload["sid"]
        if not isinstance(user_id, str) or not isinstance(session_id, str):
            raise InvalidAccessTokenError
    except (InvalidTokenError, KeyError, TypeError) as error:
        raise InvalidAccessTokenError from error
    return AccessTokenClaims(user_id=user_id, session_id=session_id)


def create_refresh_token() -> str:
    return token_urlsafe(48)


def hash_refresh_token(token: str) -> str:
    return sha256(token.encode("utf-8")).hexdigest()
