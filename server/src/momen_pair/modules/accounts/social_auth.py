from dataclasses import dataclass
from hashlib import sha256
from typing import Protocol

from momen_pair.modules.accounts.models import IdentityProvider


class SocialAuthUnavailableError(RuntimeError):
    pass


class InvalidSocialCodeError(ValueError):
    pass


@dataclass(frozen=True, slots=True)
class SocialIdentity:
    provider_subject: str
    display_name: str


class SocialAuthGateway(Protocol):
    async def exchange_code(
        self,
        provider: IdentityProvider,
        code: str,
    ) -> SocialIdentity: ...


class DisabledSocialAuthGateway:
    async def exchange_code(
        self,
        provider: IdentityProvider,
        code: str,
    ) -> SocialIdentity:
        raise SocialAuthUnavailableError


class FakeSocialAuthGateway:
    async def exchange_code(
        self,
        provider: IdentityProvider,
        code: str,
    ) -> SocialIdentity:
        normalized_code = code.strip()
        if not 3 <= len(normalized_code) <= 256:
            raise InvalidSocialCodeError
        subject_digest = sha256(f"{provider.value}:{normalized_code}".encode()).hexdigest()
        provider_name = "微信" if provider is IdentityProvider.WECHAT else "QQ"
        return SocialIdentity(
            provider_subject=f"fake_{subject_digest}",
            display_name=f"{provider_name}本地用户",
        )
