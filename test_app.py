"""Minimal tests that run before every build, without needing a real database."""

from app import app


def test_healthz_returns_ok():
    client = app.test_client()
    response = client.get("/healthz")
    assert response.status_code == 200
    assert response.get_json() == {"status": "ok"}


def test_version_returns_version_field():
    client = app.test_client()
    response = client.get("/version")
    assert response.status_code == 200
    body = response.get_json()
    assert "version" in body
    assert isinstance(body["version"], str)
