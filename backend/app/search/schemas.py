from __future__ import annotations

from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field


class SearchFilters(BaseModel):
    workspace_id: str = ''
    project_id: str = ''
    category: str = ''
    tags: list[str] = Field(default_factory=list)
    date_from: datetime | None = None
    date_to: datetime | None = None
    author: str = ''
    file_type: str = ''
    ai_generated: bool | None = None
    favorite: bool | None = None
    recent_only: bool = False
    source_types: list[str] = Field(default_factory=list)


class SearchRequest(BaseModel):
    query: str = Field(min_length=1, max_length=500)
    filters: SearchFilters = Field(default_factory=SearchFilters)
    search_type: str = Field(default='keyword', max_length=32)
    limit: int = Field(default=50, ge=1, le=200)


class SearchResult(BaseModel):
    document_id: str
    title: str
    score: float
    snippet: str
    source_type: str
    source_url: str = ''
    metadata: dict[str, Any] = Field(default_factory=dict)
    preview: str = ''
    thumbnail_url: str = ''
    summary: str = ''
    related_item_ids: list[str] = Field(default_factory=list)
    ai_insights: list[str] = Field(default_factory=list)
    quick_actions: list[str] = Field(default_factory=list)


class SearchResponse(BaseModel):
    query: str
    search_type: str
    intent: str = 'search'
    results: list[SearchResult] = Field(default_factory=list)
    total: int = 0
    took_ms: float = 0.0


class SearchIntent(BaseModel):
    intent: str
    normalized_query: str
    entity_type: str = ''
    filters: SearchFilters = Field(default_factory=SearchFilters)
    explanation: str = ''


class CommandItem(BaseModel):
    id: str
    title: str
    subtitle: str = ''
    category: str
    keywords: list[str] = Field(default_factory=list)
    route: str = ''
    action: str
    icon: str = ''


class CommandSearchRequest(BaseModel):
    query: str = ''
    workspace_id: str = ''
    limit: int = Field(default=30, ge=1, le=100)


class CommandExecuteRequest(BaseModel):
    command_id: str
    workspace_id: str = ''
    parameters: dict[str, Any] = Field(default_factory=dict)


class CommandExecutionResult(BaseModel):
    command_id: str
    success: bool
    message: str
    route: str = ''
    payload: dict[str, Any] = Field(default_factory=dict)


class SearchHistoryRead(BaseModel):
    id: str
    workspace_id: str
    query: str
    search_type: str
    result_count: int
    created_at: datetime

    model_config = {'from_attributes': True}


class SavedSearchCreate(BaseModel):
    workspace_id: str = ''
    name: str = Field(min_length=1, max_length=160)
    query: str = Field(min_length=1, max_length=500)
    filters: SearchFilters = Field(default_factory=SearchFilters)
    favorite: bool = False


class SavedSearchRead(SavedSearchCreate):
    id: str
    created_at: datetime
    updated_at: datetime

    model_config = {'from_attributes': True}


class StudyRequest(BaseModel):
    source_id: str = Field(min_length=1, max_length=180)
    workspace_id: str = ''
    source_title: str = ''
    source_text: str = Field(default='', max_length=500_000)
    resource_type: str = Field(default='executive_summary', max_length=40)
    force_refresh: bool = False


class StudyResourceRead(BaseModel):
    id: str
    source_id: str
    workspace_id: str
    resource_type: str
    title: str
    content: dict[str, Any] = Field(default_factory=dict)
    cached: bool = False
    created_at: datetime
    updated_at: datetime


class DiscoveryResponse(BaseModel):
    source_id: str
    related_results: list[SearchResult] = Field(default_factory=list)
    related_node_ids: list[str] = Field(default_factory=list)
    forgotten_items: list[SearchResult] = Field(default_factory=list)
    missing_links: list[str] = Field(default_factory=list)
    recommended_collections: list[str] = Field(default_factory=list)


class SmartCollectionRead(BaseModel):
    id: str
    workspace_id: str
    name: str
    description: str
    rule: dict[str, Any] = Field(default_factory=dict)
    item_ids: list[str] = Field(default_factory=list)
    ai_recommended: bool
    created_at: datetime
    updated_at: datetime

    model_config = {'from_attributes': True}


class KnowledgePathRequest(BaseModel):
    query: str = Field(min_length=1, max_length=300)
    workspace_id: str = ''
    max_steps: int = Field(default=8, ge=2, le=20)


class KnowledgePathResponse(BaseModel):
    title: str
    steps: list[dict[str, Any]] = Field(default_factory=list)
    explanation: str
