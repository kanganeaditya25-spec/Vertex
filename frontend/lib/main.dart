import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/router.dart';
import 'features/settings/settings_providers.dart';

void main() {
  runApp(const ProviderScope(child: ProductivityApp()));
}

class ProductivityApp extends ConsumerWidget {
  const ProductivityApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider).valueOrNull;
    final accent = _accentColor(settings?.accentColor ?? 'teal');
    final scale = settings?.fontScale ?? 1.0;
    return MaterialApp.router(
      title: 'Productivity Dashboard',
      routerConfig: appRouter,
      theme: _theme(accent, scale),
      darkTheme: _theme(accent, scale),
      themeMode: ThemeMode.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child ?? const SizedBox.shrink(),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
    );
  }
}

ThemeData _theme(Color accent, double scale) {
  final scheme = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: Brightness.light,
    surface: const Color(0xFFF7FAF8),
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFF7FAF8),
    canvasColor: const Color(0xFFF7FAF8),
  );
  final foreground = scheme.onSurface;
  return base.copyWith(
    textTheme: base.textTheme.apply(
      fontSizeFactor: scale,
      bodyColor: foreground,
      displayColor: foreground,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFFF7FAF8),
      foregroundColor: foreground,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2EAE5)),
      ),
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFFE2EAE5)),
  );
}

Color _accentColor(String name) => switch (name) {
  'teal' => const Color(0xFF0F766E),
  'amber' => const Color(0xFFB45309),
  'blue' => const Color(0xFF0369A1),
  'violet' => const Color(0xFF6D28D9),
  'rose' => const Color(0xFFBE123C),
  _ => const Color(0xFF4F46E5),
};
