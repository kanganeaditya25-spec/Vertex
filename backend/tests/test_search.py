from uuid import uuid4

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def _node(workspace: str, entity_type: str, entity_id: str, label: str, content: str, tags: list[str]) -> dict:
    response = client.post('/api/v1/graph/nodes', json={'workspace_id': workspace, 'entity_type': entity_type, 'entity_id': entity_id, 'label': label, 'content_text': content, 'tags': tags, 'metadata': {'project_id': 'project-react' if 'react' in content.lower() else ''}})
    assert response.status_code == 201, response.text
    return response.json()


def test_global_search_supports_workspace_source_and_tag_filters() -> None:
    workspace = f'search-{uuid4().hex}'
    project = _node(workspace, 'project', 'react-project', 'React project', 'Build a React dashboard with accessible components', ['react', 'frontend'])
    _node(workspace, 'note', 'python-note', 'Python note', 'Study Python iterators and generators', ['python'])

    response = client.post('/api/v1/search/query', json={'query': 'React', 'filters': {'workspace_id': workspace, 'source_types': ['project'], 'tags': ['react']}, 'search_type': 'keyword', 'limit': 20})

    assert response.status_code == 200, response.text
    assert response.json()['total'] == 1
    assert response.json()['results'][0]['document_id'] == project['id']
    assert response.json()['results'][0]['quick_actions']


def test_natural_language_intent_and_search_history() -> None:
    workspace = f'search-{uuid4().hex}'
    _node(workspace, 'project', 'react-project', 'React project', 'React components and routing', ['react'])

    intent = client.get(f'/api/v1/search/intent?q=Show+all+React+projects&workspace_id={workspace}')
    response = client.get(f'/api/v1/search/query?q=Show+all+React+projects&workspace_id={workspace}&search_type=ai')
    history = client.get(f'/api/v1/search/history?workspace_id={workspace}')

    assert intent.status_code == 200
    assert intent.json()['entity_type'] == 'project'
    assert response.status_code == 200
    assert response.json()['search_type'] == 'semantic'
    assert history.status_code == 200
    assert history.json()


def test_command_palette_saved_search_and_navigation_execution() -> None:
    workspace = f'search-{uuid4().hex}'
    commands = client.get('/api/v1/search/commands?q=knowledge')
    assert commands.status_code == 200
    assert any(item['id'] == 'navigate.graph' for item in commands.json())

    saved = client.post('/api/v1/search/saved', json={'workspace_id': workspace, 'name': 'React work', 'query': 'React', 'filters': {'workspace_id': workspace}, 'favorite': True})
    listed = client.get(f'/api/v1/search/saved?workspace_id={workspace}')
    executed = client.post('/api/v1/search/commands/execute', json={'command_id': 'navigate.graph', 'workspace_id': workspace})

    assert saved.status_code == 201
    assert listed.json()[0]['favorite'] is True
    assert executed.json()['success'] is True
    assert executed.json()['route'] == '/knowledge-graph'


def test_study_resource_is_deterministically_extracted_and_cached() -> None:
    workspace = f'search-{uuid4().hex}'
    payload = {'workspace_id': workspace, 'source_id': 'os-formulas', 'source_title': 'Operating Systems', 'source_text': '# Processes\nA process is a program in execution.\nThreads are lightweight execution units.\nT = 4 and Memory = 8GB. Important date 2026.', 'resource_type': 'revision_notes'}

    first = client.post('/api/v1/search/study', json=payload)
    second = client.post('/api/v1/search/study', json=payload)

    assert first.status_code == 200
    assert second.status_code == 200
    assert first.json()['content']['key_concepts']
    assert first.json()['content']['definitions']
    assert first.json()['content']['formulas']
    assert second.json()['cached'] is True


def test_discovery_and_smart_collections_reuse_graph_context() -> None:
    workspace = f'search-{uuid4().hex}'
    project = _node(workspace, 'project', 'project-1', 'Operating Systems', 'processes threads scheduling', ['os', 'study'])
    note = _node(workspace, 'note', 'note-1', 'Processes note', 'processes threads scheduling', ['os', 'study'])
    relationship = client.post('/api/v1/graph/relationships', json={'workspace_id': workspace, 'source_node_id': note['id'], 'target_node_id': project['id'], 'relationship_type': 'belongs_to'})
    discovery = client.get(f"/api/v1/search/discovery/{project['id']}?workspace_id={workspace}")
    collections = client.get(f'/api/v1/search/collections?workspace_id={workspace}')
    path = client.post('/api/v1/search/knowledge-path', json={'workspace_id': workspace, 'query': 'Operating Systems', 'max_steps': 5})

    assert relationship.status_code == 201
    assert discovery.status_code == 200
    assert note['id'] in discovery.json()['related_node_ids']
    assert collections.status_code == 200
    assert collections.json()
    assert path.status_code == 200
    assert path.json()['steps']
