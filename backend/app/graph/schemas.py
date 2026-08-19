from __future__ import annotations

from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field, field_validator


class GraphNodeUpsert(BaseModel):
    entity_type: str = Field(min_length=1, max_length=64)
    entity_id: str = Field(min_length=1, max_length=128)
    workspace_id: str = Field(default='', max_length=64)
    label: str = Field(default='', max_length=240)
    content_text: str = Field(default='', max_length=200_000)
    tags: list[str] = Field(default_factory=list, max_length=50)
    metadata: dict[str, Any] = Field(default_factory=dict)
    active: bool = True

    @field_validator('entity_type', 'entity_id', 'workspace_id', mode='before')
    @classmethod
    def strip_ids(cls, value: Any) -> str:
        return str(value or '').strip()


class GraphNodeRead(GraphNodeUpsert):
    id: str
    degree: int = 0
    created_at: datetime
    updated_at: datetime

    model_config = {'from_attributes': True}


class RelationshipCreate(BaseModel):
    workspace_id: str = Field(default='', max_length=64)
    source_node_id: str = Field(min_length=1, max_length=180)
    target_node_id: str = Field(min_length=1, max_length=180)
    relationship_type: str = Field(min_length=1, max_length=80)
    weight: float = Field(default=1.0, ge=0.0, le=1_000_000)
    confidence: float = Field(default=1.0, ge=0.0, le=1.0)
    explanation: str = Field(default='', max_length=1_000)
    source: str = Field(default='manual', max_length=32)
    metadata: dict[str, Any] = Field(default_factory=dict)


class RelationshipRead(RelationshipCreate):
    id: str
    created_at: datetime
    updated_at: datetime

    model_config = {'from_attributes': True}


class GraphSuggestionRead(BaseModel):
    id: str
    workspace_id: str
    source_node_id: str
    target_node_id: str
    relationship_type: str
    score: float
    explanation: str
    status: str
    created_at: datetime
    updated_at: datetime

    model_config = {'from_attributes': True}


class GraphContext(BaseModel):
    node: GraphNodeRead
    incoming: list[RelationshipRead] = Field(default_factory=list)
    outgoing: list[RelationshipRead] = Field(default_factory=list)
    related: list[GraphNodeRead] = Field(default_factory=list)
    suggestions: list[GraphSuggestionRead] = Field(default_factory=list)


class GraphSearchResponse(BaseModel):
    query: str
    nodes: list[GraphNodeRead] = Field(default_factory=list)
    relationships: list[RelationshipRead] = Field(default_factory=list)


class GraphPathResponse(BaseModel):
    source_node_id: str
    target_node_id: str
    node_ids: list[str] = Field(default_factory=list)
    relationships: list[RelationshipRead] = Field(default_factory=list)
    found: bool


class GraphStats(BaseModel):
    workspace_id: str
    total_nodes: int
    active_nodes: int
    total_relationships: int
    relationship_types: dict[str, int]
    graph_density: float
    connected_components: int
    orphaned_nodes: int
    accepted_suggestions: int


class GraphInsight(BaseModel):
    insight_type: str
    title: str
    explanation: str
    node_ids: list[str] = Field(default_factory=list)
    score: float = 0.0


class DuplicateGroup(BaseModel):
    reason: str
    node_ids: list[str]
    explanation: str
    score: float


class GraphEntityEvent(BaseModel):
    event_name: str
    entity_type: str
    entity_id: str
    workspace_id: str = ''
    label: str = ''
    content_text: str = ''
    tags: list[str] = Field(default_factory=list)
    metadata: dict[str, Any] = Field(default_factory=dict)


class RelationshipEvent(BaseModel):
    workspace_id: str = ''
    source_node_id: str
    target_node_id: str
    relationship_type: str
    explanation: str = ''
    source: str = 'event'
