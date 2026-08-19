import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:productivity_dashboard/features/auth/auth_store.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('creates a local account and restores the session', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(authStoreProvider.future);
    await container.read(authStoreProvider.notifier).signUp(
          name: 'Ada Lovelace',
          email: 'ada@example.com',
          password: 'securepass',
        );

    final session = container.read(authStoreProvider).value;
    expect(session?.name, 'Ada Lovelace');
    expect(session?.email, 'ada@example.com');
    expect(session?.isGuest, isFalse);
  });

  test('rejects invalid credentials and supports offline guest mode', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(authStoreProvider.future);
    await container.read(authStoreProvider.notifier).signUp(
          name: 'Ada Lovelace',
          email: 'ada@example.com',
          password: 'securepass',
        );

    await expectLater(
      container.read(authStoreProvider.notifier).signIn(email: 'ada@example.com', password: 'wrongpass'),
      throwsA(isA<AuthException>()),
    );
    await container.read(authStoreProvider.notifier).continueOffline();
    expect(container.read(authStoreProvider).value?.isGuest, isTrue);
  });
}
