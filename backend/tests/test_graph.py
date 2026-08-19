from uuid import uuid4

from fastapi.testclient import TestClient

from app.core.event_bus.bus import DomainEvent, bus
from app.main import app

client = TestClient(app)


def _node(entity_type: str, entity_id: str, workspace_id: str, label: str, content_text: str, tags: list[str]) -> dict:
    response = client.post('/api/v1/graph/nodes', json={'entity_type': entity_type, 'entity_id': entity_id, 'workspace_id': workspace_id, 'label': label, 'content_text': content_text, 'tags': tags})
    assert response.status_code == 201, response.text
    return response.json()


def test_graph_crud_context_path_and_stats() -> None:
    workspace = f'graph-{uuid4().hex}'
    project = _node('project', 'project-1', workspace, 'Focus project', 'deep work planning', ['focus', 'planning'])
    task = _node('task', 'task-1', workspace, 'Planning task', 'deep work planning', ['focus', 'planning'])
    relationship = client.post('/api/v1/graph/relationships', json={'workspace_id': workspace, 'source_node_id': task['id'], 'target_node_id': project['id'], 'relationship_type': 'belongs_to', 'explanation': 'Task belongs to project.'})

    assert relationship.status_code == 201, relationship.text
    context = client.get(f"/api/v1/graph/context/{task['id']}?workspace_id={workspace}")
    path = client.get(f"/api/v1/graph/path/{task['id']}/{project['id']}?workspace_id={workspace}")
    stats = client.get(f'/api/v1/graph/stats?workspace_id={workspace}')

    assert context.status_code == 200
    assert context.json()['related'][0]['id'] == project['id']
    assert path.json()['found'] is True
    assert stats.json()['total_nodes'] == 2
    assert stats.json()['total_relationships'] == 1
    assert stats.json()['orphaned_nodes'] == 0


def test_graph_search_suggestions_duplicates_and_acceptance() -> None:
    workspace = f'graph-{uuid4().hex}'
    first = _node('note', 'note-1', workspace, 'Focus note', 'protect a deep work block every morning', ['focus', 'morning'])
    second = _node('asset', 'asset-1', workspace, 'Focus resource', 'protect a deep work block every morning', ['focus', 'morning'])

    search = client.get(f'/api/v1/graph/search?q=deep+work&workspace_id={workspace}')
    suggestions = client.get(f'/api/v1/graph/suggestions?workspace_id={workspace}')
    duplicates = client.get(f'/api/v1/graph/duplicates?workspace_id={workspace}')

    assert search.status_code == 200
    assert {item['id'] for item in search.json()['nodes']} == {first['id'], second['id']}
    assert suggestions.status_code == 200
    assert suggestions.json()
    assert duplicates.status_code == 200
    assert duplicates.json()

    suggestion_id = suggestions.json()[0]['id']
    accepted = client.post(f'/api/v1/graph/suggestions/{suggestion_id}/accept?workspace_id={workspace}')
    stats = client.get(f'/api/v1/graph/stats?workspace_id={workspace}')

    assert accepted.status_code == 200
    assert accepted.json()['source'] == 'ai_suggestion'
    assert stats.json()['accepted_suggestions'] == 1


def test_graph_event_bus_creates_workspace_and_project_nodes() -> None:
    workspace = f'graph-{uuid4().hex}'
    project_id = f'project-{uuid4().hex}'
    bus.publish(DomainEvent('project.created', {'project_id': project_id, 'workspace_id': workspace}))

    nodes = client.get(f'/api/v1/graph/nodes?workspace_id={workspace}')

    assert nodes.status_code == 200
    assert any(item['entity_id'] == project_id and item['entity_type'] == 'project' for item in nodes.json())
    assert any(item['entity_type'] == 'workspace' for item in nodes.json())


def test_graph_insights_report_orphans_and_connected_items() -> None:
    workspace = f'graph-{uuid4().hex}'
    _node('note', 'orphan', workspace, 'Orphan note', 'unlinked knowledge', [])
    insights = client.get(f'/api/v1/graph/insights?workspace_id={workspace}')

    assert insights.status_code == 200
    assert any(item['insight_type'] == 'orphaned_items' for item in insights.json())


def test_graph_nodes_are_indexed_in_shared_core_search() -> None:
    workspace = f'graph-{uuid4().hex}'
    node = _node('note', 'search-note', workspace, 'Focus search note', 'semantic graph discovery', ['search'])

    results = client.get(f'/api/v1/core/search?q=semantic+graph&workspace_id={workspace}')

    assert results.status_code == 200
    assert any(item['document_id'] == node['id'] and item['metadata']['workspace_id'] == workspace for item in results.json())
