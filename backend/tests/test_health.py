from fastapi.testclient import TestClient

from app.main import app


client = TestClient(app)


def test_root_exposes_health_contract() -> None:
    response = client.get('/')
    assert response.status_code == 200
    assert response.json()['health'] == '/api/v1/health'


def test_health_is_ok() -> None:
    response = client.get('/api/v1/health')
    assert response.status_code == 200
    payload = response.json()
    assert payload['status'] == 'ok'
    assert payload['service'] == 'Productivity Dashboard API'
    assert 'timestamp' in payload
