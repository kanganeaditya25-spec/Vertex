from __future__ import annotations

from datetime import datetime
from typing import Any, Iterable


DESTRUCTIVE_ACTIONS = {"delete_task", "delete_project", "delete_workspace", "delete_asset", "bulk_delete"}
SUPPORTED_ACTIONS = {
    "create_task", "update_task", "archive_task", "restore_task", "delete_task", "duplicate_task",
    "create_event", "update_event", "archive_event", "create_note", "archive_note", "create_reminder",
    "notify", "send_local_notification", "generate_ai_summary", "generate_subtasks", "attach_asset",
    "export_data", "schedule", "move", "duplicate", "noop",
}


def nested_value(payload: dict[str, Any], field: str) -> Any:
    current: Any = payload
    for part in field.split("."):
        if isinstance(current, dict):
            current = current.get(part)
        else:
            return None
    return current


def compare(actual: Any, operator: str, expected: Any) -> bool:
    if operator == "exists":
        return actual is not None
    if operator == "contains":
        if isinstance(actual, (list, tuple, set)):
            return expected in actual
        return str(expected).casefold() in str(actual or "").casefold()
    if operator == "in":
        return actual in (expected if isinstance(expected, list) else [expected])
    try:
        if operator == "equals":
            return actual == expected or str(actual).casefold() == str(expected).casefold()
        if operator == "not_equals":
            return not compare(actual, "equals", expected)
        if operator == "greater_than":
            return actual > expected
        if operator == "less_than":
            return actual < expected
        if operator == "greater_or_equal":
            return actual >= expected
        if operator == "less_or_equal":
            return actual <= expected
    except (TypeError, ValueError):
        return False
    return False


def condition_matches(condition: dict[str, Any], payload: dict[str, Any]) -> bool:
    logical = condition.get("logical")
    children = condition.get("children") or []
    if logical == "AND":
        return all(condition_matches(child, payload) for child in children)
    if logical == "OR":
        return any(condition_matches(child, payload) for child in children)
    if logical == "NOT":
        return not condition_matches(children[0], payload) if children else False
    return compare(nested_value(payload, str(condition.get("field", ""))), str(condition.get("operator", "equals")), condition.get("value"))


def conditions_match(conditions: Iterable[dict[str, Any]], payload: dict[str, Any]) -> bool:
    return all(condition_matches(condition, payload) for condition in conditions)


def trigger_matches(trigger_type: str, event_type: str, trigger_config: dict[str, Any], payload: dict[str, Any]) -> bool:
    if trigger_type in {"manual", "system"}:
        return event_type == trigger_type or trigger_type == "manual"
    if trigger_type not in {event_type, "*", "all"}:
        return False
    return conditions_match(trigger_config.get("filters", []), payload)


def validate_workflow(workflow: dict[str, Any]) -> dict[str, Any]:
    errors: list[str] = []
    warnings: list[str] = []
    actions = workflow.get("actions") or []
    nodes = workflow.get("nodes") or []
    edges = workflow.get("edges") or []
    if not workflow.get("name"):
        errors.append("Workflow name is required.")
    if not workflow.get("trigger_type"):
        errors.append("A trigger type is required.")
    if not actions and not nodes:
        errors.append("Add at least one action or action node.")
    for action in actions:
        action_type = action.get("action_type")
        if action_type not in SUPPORTED_ACTIONS:
            errors.append(f"Unsupported action: {action_type}.")
    if len(nodes) > workflow.get("max_steps", 50):
        errors.append("The workflow exceeds its maximum step count.")
    node_ids = {node.get("id") for node in nodes}
    for edge in edges:
        if edge.get("source") not in node_ids or edge.get("target") not in node_ids:
            errors.append("Every workflow edge must connect existing nodes.")
    adjacency = {node_id: [] for node_id in node_ids if node_id}
    for edge in edges:
        if edge.get("source") in adjacency:
            adjacency[edge["source"]].append(edge.get("target"))
    visiting: set[str] = set()
    visited: set[str] = set()

    def visit(node_id: str) -> bool:
        if node_id in visiting:
            return True
        if node_id in visited:
            return False
        visiting.add(node_id)
        has_cycle = any(visit(child) for child in adjacency.get(node_id, []))
        visiting.remove(node_id)
        visited.add(node_id)
        return has_cycle

    if any(visit(node_id) for node_id in adjacency):
        errors.append("Workflow node graph contains a circular path.")
    if workflow.get("workflow_type") in {"scheduled", "recurring"} and not workflow.get("trigger_config", {}).get("schedule"):
        warnings.append("Scheduled workflows need a schedule expression before automatic evaluation.")
    if any(action.get("action_type") in DESTRUCTIVE_ACTIONS for action in actions) and workflow.get("approval_mode") == "never":
        errors.append("Destructive workflows cannot disable approval protection.")
    return {"valid": not errors, "errors": errors, "warnings": warnings, "step_count": max(len(actions), len(nodes))}


def suggest_workflow(prompt: str) -> dict[str, Any]:
    text = prompt.casefold()
    if "friday" in text or "monday" in text or "every" in text:
        trigger = "scheduled"
        workflow_type = "recurring"
        trigger_config = {"schedule": "weekly", "weekday": "monday" if "monday" in text else "friday"}
    elif "finish" in text or "complete" in text or "when" in text:
        trigger = "task_completed"
        workflow_type = "event"
        trigger_config = {}
    else:
        trigger = "manual"
        workflow_type = "manual"
        trigger_config = {}
    actions = [{"action_type": "create_task", "label": "Create next task", "parameters": {"title_template": "Next action from {{event.title}}"}, "order": 0, "requires_approval": False, "retry_limit": 0}]
    if "calendar" in text or "schedule" in text:
        actions.append({"action_type": "create_event", "label": "Schedule a focus block", "parameters": {"title_template": "Focus: {{event.title}}", "duration_minutes": 45}, "order": 1, "requires_approval": False, "retry_limit": 0})
    return {"name": "Suggested automation", "description": prompt, "workflow_type": workflow_type, "trigger_type": trigger, "trigger_config": trigger_config, "conditions": [], "actions": actions, "explanation": "This workflow was parsed locally from trigger words and action intent. Review the steps before enabling it."}
