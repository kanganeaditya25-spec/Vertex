class AutomationConditionModel {
  const AutomationConditionModel(
      {this.field,
      this.operator,
      this.value,
      this.logical,
      this.children = const []});
  final String? field;
  final String? operator;
  final dynamic value;
  final String? logical;
  final List<AutomationConditionModel> children;

  factory AutomationConditionModel.leaf(
          String field, String operator, dynamic value) =>
      AutomationConditionModel(field: field, operator: operator, value: value);
  factory AutomationConditionModel.group(
          String logical, List<AutomationConditionModel> children) =>
      AutomationConditionModel(logical: logical, children: children);
  factory AutomationConditionModel.fromJson(Map<String, dynamic> json) =>
      AutomationConditionModel(
          field: json['field'] as String?,
          operator: json['operator'] as String?,
          value: json['value'],
          logical: json['logical'] as String?,
          children: _maps(json['children'])
              .map(AutomationConditionModel.fromJson)
              .toList());
  Map<String, dynamic> toJson() => {
        'field': field,
        'operator': operator,
        'value': value,
        'logical': logical,
        'children': children.map((item) => item.toJson()).toList()
      };
}

class AutomationActionModel {
  const AutomationActionModel(
      {required this.actionType,
      this.label = '',
      this.parameters = const {},
      this.order = 0,
      this.requiresApproval = false,
      this.retryLimit = 0});
  final String actionType;
  final String label;
  final Map<String, dynamic> parameters;
  final int order;
  final bool requiresApproval;
  final int retryLimit;

  factory AutomationActionModel.fromJson(Map<String, dynamic> json) =>
      AutomationActionModel(
          actionType: '${json['action_type'] ?? json['actionType'] ?? 'noop'}',
          label: '${json['label'] ?? ''}',
          parameters: _map(json['parameters']),
          order: (json['order'] as num?)?.toInt() ?? 0,
          requiresApproval: json['requires_approval'] as bool? ??
              json['requiresApproval'] as bool? ??
              false,
          retryLimit: (json['retry_limit'] as num?)?.toInt() ?? 0);
  Map<String, dynamic> toJson() => {
        'action_type': actionType,
        'label': label,
        'parameters': parameters,
        'order': order,
        'requires_approval': requiresApproval,
        'retry_limit': retryLimit
      };
}

class AutomationNodeModel {
  const AutomationNodeModel(
      {required this.id,
      required this.nodeType,
      this.label = '',
      this.data = const {},
      this.position = const {}});
  final String id;
  final String nodeType;
  final String label;
  final Map<String, dynamic> data;
  final Map<String, double> position;
  factory AutomationNodeModel.fromJson(Map<String, dynamic> json) =>
      AutomationNodeModel(
          id: '${json['id'] ?? ''}',
          nodeType: '${json['node_type'] ?? json['nodeType'] ?? 'action'}',
          label: '${json['label'] ?? ''}',
          data: _map(json['data']),
          position: _map(json['position']).map((key, value) =>
              MapEntry(key, value is num ? value.toDouble() : 0)));
  Map<String, dynamic> toJson() => {
        'id': id,
        'node_type': nodeType,
        'label': label,
        'data': data,
        'position': position
      };
}

class AutomationEdgeModel {
  const AutomationEdgeModel(
      {required this.source, required this.target, this.label = ''});
  final String source;
  final String target;
  final String label;
  factory AutomationEdgeModel.fromJson(Map<String, dynamic> json) =>
      AutomationEdgeModel(
          source: '${json['source'] ?? ''}',
          target: '${json['target'] ?? ''}',
          label: '${json['label'] ?? ''}');
  Map<String, dynamic> toJson() =>
      {'source': source, 'target': target, 'label': label};
}

class AutomationWorkflowModel {
  const AutomationWorkflowModel(
      {required this.id,
      required this.name,
      required this.triggerType,
      this.description = '',
      this.workflowType = 'manual',
      this.enabled = true,
      this.triggerConfig = const {},
      this.conditions = const [],
      this.actions = const [],
      this.variables = const {},
      this.nodes = const [],
      this.edges = const [],
      this.approvalMode = 'destructive',
      this.retryLimit = 0,
      this.timeoutSeconds = 30,
      this.maxSteps = 50,
      this.lastRunAt,
      this.createdAt,
      this.updatedAt});
  final String id;
  final String name;
  final String description;
  final String workflowType;
  final bool enabled;
  final String triggerType;
  final Map<String, dynamic> triggerConfig;
  final List<AutomationConditionModel> conditions;
  final List<AutomationActionModel> actions;
  final Map<String, dynamic> variables;
  final List<AutomationNodeModel> nodes;
  final List<AutomationEdgeModel> edges;
  final String approvalMode;
  final int retryLimit;
  final int timeoutSeconds;
  final int maxSteps;
  final DateTime? lastRunAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AutomationWorkflowModel copyWith(
          {String? name,
          String? description,
          bool? enabled,
          String? triggerType,
          String? workflowType,
          List<AutomationConditionModel>? conditions,
          List<AutomationActionModel>? actions,
          List<AutomationNodeModel>? nodes,
          List<AutomationEdgeModel>? edges}) =>
      AutomationWorkflowModel(
          id: id,
          name: name ?? this.name,
          description: description ?? this.description,
          workflowType: workflowType ?? this.workflowType,
          enabled: enabled ?? this.enabled,
          triggerType: triggerType ?? this.triggerType,
          triggerConfig: triggerConfig,
          conditions: conditions ?? this.conditions,
          actions: actions ?? this.actions,
          variables: variables,
          nodes: nodes ?? this.nodes,
          edges: edges ?? this.edges,
          approvalMode: approvalMode,
          retryLimit: retryLimit,
          timeoutSeconds: timeoutSeconds,
          maxSteps: maxSteps,
          lastRunAt: lastRunAt,
          createdAt: createdAt,
          updatedAt: updatedAt);
  factory AutomationWorkflowModel.fromJson(Map<String, dynamic> json) =>
      AutomationWorkflowModel(
          id: '${json['id'] ?? ''}',
          name: '${json['name'] ?? 'Automation'}',
          description: '${json['description'] ?? ''}',
          workflowType:
              '${json['workflow_type'] ?? json['workflowType'] ?? 'manual'}',
          enabled: json['enabled'] as bool? ?? true,
          triggerType:
              '${json['trigger_type'] ?? json['triggerType'] ?? 'manual'}',
          triggerConfig: _map(json['trigger_config'] ?? json['triggerConfig']),
          conditions: _maps(json['conditions'])
              .map(AutomationConditionModel.fromJson)
              .toList(),
          actions: _maps(json['actions'])
              .map(AutomationActionModel.fromJson)
              .toList(),
          variables: _map(json['variables']),
          nodes:
              _maps(json['nodes']).map(AutomationNodeModel.fromJson).toList(),
          edges:
              _maps(json['edges']).map(AutomationEdgeModel.fromJson).toList(),
          approvalMode:
              '${json['approval_mode'] ?? json['approvalMode'] ?? 'destructive'}',
          retryLimit: (json['retry_limit'] as num?)?.toInt() ?? 0,
          timeoutSeconds: (json['timeout_seconds'] as num?)?.toInt() ?? 30,
          maxSteps: (json['max_steps'] as num?)?.toInt() ?? 50,
          lastRunAt: _date(json['last_run_at'] ?? json['lastRunAt']),
          createdAt: _date(json['created_at'] ?? json['createdAt']),
          updatedAt: _date(json['updated_at'] ?? json['updatedAt']));
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'workflow_type': workflowType,
        'enabled': enabled,
        'trigger_type': triggerType,
        'trigger_config': triggerConfig,
        'conditions': conditions.map((item) => item.toJson()).toList(),
        'actions': actions.map((item) => item.toJson()).toList(),
        'variables': variables,
        'nodes': nodes.map((item) => item.toJson()).toList(),
        'edges': edges.map((item) => item.toJson()).toList(),
        'approval_mode': approvalMode,
        'retry_limit': retryLimit,
        'timeout_seconds': timeoutSeconds,
        'max_steps': maxSteps,
        'last_run_at': lastRunAt?.toIso8601String(),
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String()
      };
}

class AutomationTemplateModel {
  const AutomationTemplateModel(
      {required this.id,
      required this.name,
      required this.category,
      this.description = '',
      this.definition = const {},
      this.builtIn = false,
      this.createdAt});
  final String id;
  final String name;
  final String category;
  final String description;
  final Map<String, dynamic> definition;
  final bool builtIn;
  final DateTime? createdAt;
  factory AutomationTemplateModel.fromJson(Map<String, dynamic> json) =>
      AutomationTemplateModel(
          id: '${json['id'] ?? ''}',
          name: '${json['name'] ?? 'Template'}',
          category: '${json['category'] ?? 'general'}',
          description: '${json['description'] ?? ''}',
          definition: _map(json['definition']),
          builtIn:
              json['built_in'] as bool? ?? json['builtIn'] as bool? ?? false,
          createdAt: _date(json['created_at'] ?? json['createdAt']));
}

class AutomationExecutionModel {
  const AutomationExecutionModel(
      {required this.id,
      required this.workflowId,
      required this.status,
      this.triggerEvent = const {},
      this.actionLogs = const [],
      this.error,
      this.approvalRequired = false,
      this.replayOf,
      this.attempts = 1,
      this.startedAt,
      this.finishedAt,
      this.durationMs = 0});
  final String id;
  final String workflowId;
  final String status;
  final Map<String, dynamic> triggerEvent;
  final List<Map<String, dynamic>> actionLogs;
  final String? error;
  final bool approvalRequired;
  final String? replayOf;
  final int attempts;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final int durationMs;
  factory AutomationExecutionModel.fromJson(Map<String, dynamic> json) =>
      AutomationExecutionModel(
          id: '${json['id'] ?? ''}',
          workflowId: '${json['workflow_id'] ?? json['workflowId'] ?? ''}',
          status: '${json['status'] ?? 'success'}',
          triggerEvent: _map(json['trigger_event'] ?? json['triggerEvent']),
          actionLogs: _maps(json['action_logs'] ?? json['actionLogs']),
          error: json['error'] as String?,
          approvalRequired: json['approval_required'] as bool? ??
              json['approvalRequired'] as bool? ??
              false,
          replayOf: json['replay_of'] as String? ?? json['replayOf'] as String?,
          attempts: (json['attempts'] as num?)?.toInt() ?? 1,
          startedAt: _date(json['started_at'] ?? json['startedAt']),
          finishedAt: _date(json['finished_at'] ?? json['finishedAt']),
          durationMs: (json['duration_ms'] as num?)?.toInt() ?? 0);
}

class AutomationStatsModel {
  const AutomationStatsModel(
      {this.workflowCount = 0,
      this.enabledWorkflowCount = 0,
      this.executionCount = 0,
      this.successCount = 0,
      this.failureCount = 0,
      this.pendingApprovalCount = 0,
      this.pendingEventCount = 0});
  final int workflowCount;
  final int enabledWorkflowCount;
  final int executionCount;
  final int successCount;
  final int failureCount;
  final int pendingApprovalCount;
  final int pendingEventCount;
  factory AutomationStatsModel.fromJson(Map<String, dynamic> json) =>
      AutomationStatsModel(
          workflowCount: _int(json['workflow_count']),
          enabledWorkflowCount: _int(json['enabled_workflow_count']),
          executionCount: _int(json['execution_count']),
          successCount: _int(json['success_count']),
          failureCount: _int(json['failure_count']),
          pendingApprovalCount: _int(json['pending_approval_count']),
          pendingEventCount: _int(json['pending_event_count']));
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? value.cast<String, dynamic>() : <String, dynamic>{};
List<Map<String, dynamic>> _maps(dynamic value) => value is List
    ? value
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList()
    : <Map<String, dynamic>>[];
DateTime? _date(dynamic value) =>
    value is String ? DateTime.tryParse(value) : null;
int _int(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;
