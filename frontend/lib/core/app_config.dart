class AppConfig {
  const AppConfig._();

  static const authTokenKey = 'auth_token';

  static const apiBaseUrl = String.fromEnvironment(
    'PRODUCTIVITY_API_BASE_URL',
    defaultValue: 'https://vertex-eta-bice.vercel.app/api',
  );
}
