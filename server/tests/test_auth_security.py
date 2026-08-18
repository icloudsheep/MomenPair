import pytest

from momen_pair.core.config import Settings
from momen_pair.core.security import (
    InvalidAccessTokenError,
    create_access_token,
    decode_access_token,
    hash_refresh_token,
)
from momen_pair.modules.accounts.models import IdentityProvider
from momen_pair.modules.accounts.social_auth import FakeSocialAuthGateway


def test_access_token_round_trip() -> None:
    settings = Settings(secret_key="test-secret-with-more-than-32-characters")

    token, expires_in = create_access_token("user-id", "session-id", settings)
    claims = decode_access_token(token, settings)

    assert expires_in == 900
    assert claims.user_id == "user-id"
    assert claims.session_id == "session-id"


def test_access_token_rejects_wrong_secret() -> None:
    issuer = Settings(secret_key="issuer-secret-with-more-than-32-characters")
    verifier = Settings(secret_key="verifier-secret-with-more-than-32-characters")
    token, _ = create_access_token("user-id", "session-id", issuer)

    with pytest.raises(InvalidAccessTokenError):
        decode_access_token(token, verifier)


def test_refresh_token_hash_is_stable_and_non_plaintext() -> None:
    token = "refresh-token-value"

    assert hash_refresh_token(token) == hash_refresh_token(token)
    assert hash_refresh_token(token) != token


@pytest.mark.asyncio
async def test_fake_provider_keeps_qq_and_wechat_subjects_separate() -> None:
    gateway = FakeSocialAuthGateway()

    wechat = await gateway.exchange_code(IdentityProvider.WECHAT, "same-local-code")
    qq = await gateway.exchange_code(IdentityProvider.QQ, "same-local-code")

    assert wechat.provider_subject != qq.provider_subject


def test_production_rejects_fake_social_auth() -> None:
    with pytest.raises(ValueError, match="fake is forbidden"):
        Settings(
            environment="production",
            secret_key="production-secret-with-more-than-32-characters",
            object_storage_secret_key="production-object-secret",
            social_auth_mode="fake",
        )
