import pytest
from httpx import ASGITransport, AsyncClient

from momen_pair.main import app


@pytest.mark.asyncio
async def test_live_health_check() -> None:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        response = await client.get("/api/v1/health/live")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


@pytest.mark.asyncio
async def test_service_metadata() -> None:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        response = await client.get("/api/v1/meta")

    assert response.status_code == 200
    assert response.json()["api_version"] == "v1"
    assert "families" in response.json()["modules"]
