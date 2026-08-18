from functools import lru_cache
from typing import Literal

from pydantic import Field, SecretStr, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_prefix="MOMENPAIR_",
        extra="ignore",
    )

    app_name: str = "MomenPair API"
    environment: Literal["development", "test", "production"] = "development"
    debug: bool = False
    docs_enabled: bool = True
    api_prefix: str = "/api/v1"
    secret_key: SecretStr = SecretStr("development-only-change-me")
    database_url: str = "mysql+asyncmy://momenpair:momenpair@127.0.0.1:3306/momenpair"
    redis_url: str = "redis://127.0.0.1:6379/0"
    object_storage_endpoint: str = "http://127.0.0.1:9000"
    object_storage_access_key: SecretStr = SecretStr("momenpair")
    object_storage_secret_key: SecretStr = SecretStr("development-only-change-me")
    object_storage_bucket: str = "momenpair-media"
    cors_origins: list[str] = []
    allowed_hosts: list[str] = ["localhost", "127.0.0.1", "testserver"]
    social_auth_mode: Literal["disabled", "fake"] = "disabled"
    access_token_ttl_minutes: int = Field(default=15, ge=5, le=60)
    refresh_token_ttl_days: int = Field(default=30, ge=1, le=90)
    token_issuer: str = Field(default="momen-pair-server")
    token_audience: str = Field(default="momen-pair-client")

    @model_validator(mode="after")
    def reject_insecure_production_settings(self) -> "Settings":
        if self.environment == "production":
            if self.secret_key.get_secret_value() == "development-only-change-me":
                raise ValueError("MOMENPAIR_SECRET_KEY must be changed in production")
            if self.object_storage_secret_key.get_secret_value() == "development-only-change-me":
                raise ValueError(
                    "MOMENPAIR_OBJECT_STORAGE_SECRET_KEY must be changed in production"
                )
            if self.debug:
                raise ValueError("MOMENPAIR_DEBUG must be false in production")
            if self.social_auth_mode == "fake":
                raise ValueError("MOMENPAIR_SOCIAL_AUTH_MODE=fake is forbidden in production")
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()
