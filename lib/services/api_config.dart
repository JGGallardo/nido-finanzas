class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/api/v1',
  );
  static const syncEnabled = bool.fromEnvironment(
    'SYNC_ENABLED',
    defaultValue: false,
  );
}
