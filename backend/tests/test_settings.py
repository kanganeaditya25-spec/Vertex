from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_settings_defaults_and_patch() -> None:
    client.patch('/api/v1/settings/value', json={'path': 'appearance.theme_mode', 'value': 'system'})
    response = client.get('/api/v1/settings')
    assert response.status_code == 200
    assert response.json()['values']['appearance']['theme_mode'] == 'system'
    patched = client.patch('/api/v1/settings/value', json={'path': 'appearance.theme_mode', 'value': 'dark'})
    assert patched.status_code == 200
    assert patched.json()['values']['appearance']['theme_mode'] == 'dark'


def test_settings_search_and_backup_restore() -> None:
    search = client.get('/api/v1/settings/search', params={'q': 'theme'})
    assert search.status_code == 200
    assert any(item['path'] == 'appearance.theme_mode' for item in search.json())
    client.patch('/api/v1/settings/value', json={'path': 'appearance.theme_mode', 'value': 'dark'})
    backup = client.post('/api/v1/settings/backups', json={'label': 'Acceptance backup'})
    assert backup.status_code == 200
    backup_id = backup.json()['id']
    client.patch('/api/v1/settings/value', json={'path': 'appearance.theme_mode', 'value': 'light'})
    restored = client.post(f'/api/v1/settings/backups/{backup_id}/restore', json={})
    assert restored.status_code == 200
    assert restored.json()['values']['appearance']['theme_mode'] == 'dark'
    listing = client.get('/api/v1/settings/backups')
    assert listing.status_code == 200
    assert listing.json()[0]['verified'] is True


def test_privacy_confirmation_and_storage() -> None:
    blocked = client.post('/api/v1/settings/privacy', json={'action': 'clear_cache', 'confirm': False})
    assert blocked.status_code == 400
    completed = client.post('/api/v1/settings/privacy', json={'action': 'clear_cache', 'confirm': True})
    assert completed.status_code == 200
    storage = client.get('/api/v1/settings/storage')
    assert storage.status_code == 200
    assert 'settings_bytes' in storage.json()
