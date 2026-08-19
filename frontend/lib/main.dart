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
    final accent = _accentColor(settings?.accentColor ?? 'indigo');
    final scale = settings?.fontScale ?? 1.0;
    return MaterialApp.router(
      title: 'Productivity Dashboard',
      routerConfig: appRouter,
      theme: _theme(accent, Brightness.light, scale),
      darkTheme: _theme(accent, Brightness.dark, scale),
      themeMode: _themeMode('${settings?.themeMode ?? 'system'}'),
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

ThemeData _theme(Color accent, Brightness brightness, double scale) {
  final base = ThemeData(
    useMaterial3: true,
    colorSchemeSeed: accent,
    brightness: brightness,
  );
  final foreground = base.colorScheme.onSurface;
  return base.copyWith(
    textTheme: base.textTheme.apply(
      fontSizeFactor: scale,
      bodyColor: foreground,
      displayColor: foreground,
    ),
    scaffoldBackgroundColor: base.colorScheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: base.colorScheme.surface,
      foregroundColor: foreground,
    ),
    cardTheme: CardThemeData(
      color: base.colorScheme.surfaceContainer,
      margin: EdgeInsets.zero,
    ),
  );
}

ThemeMode _themeMode(String mode) => switch (mode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

Color _accentColor(String name) => switch (name) {
      'teal' => const Color(0xFF0F766E),
      'amber' => const Color(0xFFB45309),
      'blue' => const Color(0xFF0369A1),
      'violet' => const Color(0xFF6D28D9),
      'rose' => const Color(0xFFBE123C),
      _ => const Color(0xFF4F46E5),
    };
