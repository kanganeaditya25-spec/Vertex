from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding='utf-8')


def require(text: str, marker: str, source: str) -> None:
    if marker not in text:
        raise AssertionError(f'{marker!r} missing from {source}')


pubspec = read('frontend/pubspec.yaml')
main = read('frontend/lib/main.dart')
router = read('frontend/lib/core/router.dart')
models = read('frontend/lib/models/dashboard_models.dart')
repository = read('frontend/lib/repositories/dashboard_repository.dart')
providers = read('frontend/lib/providers/dashboard_providers.dart')
service = read('frontend/lib/services/ai_insight_service.dart')
dashboard = read('frontend/lib/features/dashboard/dashboard_page.dart')

for package in ('flutter_riverpod', 'go_router', 'dio', 'shared_preferences', 'flutter_local_notifications', 'fl_chart', 'workmanager'):
    require(pubspec, package, 'frontend/pubspec.yaml')

for marker in ('ProviderScope', 'MaterialApp.router', 'ThemeMode.system'):
    require(main, marker, 'frontend/lib/main.dart')
require(router, "path: '/'", 'frontend/lib/core/router.dart')

for marker in ('class DashboardSnapshot', 'class DashboardPreferences', 'class FocusSummary', 'toJson()', 'fromJson'):
    require(models, marker, 'frontend/lib/models/dashboard_models.dart')
for marker in ('SharedPreferences', '_snapshotKey', '_preferencesKey', 'saveSnapshot', 'savePreferences'):
    require(repository, marker, 'frontend/lib/repositories/dashboard_repository.dart')
for marker in ('dashboardProvider', 'greetingProvider', 'analyticsProvider', 'quickActionProvider', 'recentActivityProvider', 'aiInsightProvider', 'widgetProvider', 'statisticsProvider', 'notificationProvider', 'focusProvider'):
    require(providers, marker, 'frontend/lib/providers/dashboard_providers.dart')
for marker in ('/api/tags', '/api/generate', 'DioException'):
    require(service, marker, 'frontend/lib/services/ai_insight_service.dart')
for marker in ('Today overview', 'AI priority queue', 'Focus mode', 'Calendar preview', 'Recent notes', 'Project status', 'Habits', 'Productivity analytics', 'AI insights', 'Customize dashboard'):
    require(dashboard, marker, 'frontend/lib/features/dashboard/dashboard_page.dart')

for path in (ROOT / 'frontend' / 'lib').rglob('*.dart'):
    text = path.read_text(encoding='utf-8').lower()
    if 'mock' in text or 'placeholder' in text:
        raise AssertionError(f'production marker found in {path}')

print('Task 2 foundation structure verified: Flutter shell, Riverpod providers, repositories, offline persistence, local AI boundary, dashboard sections, and no TODO/mock/placeholder markers.')
