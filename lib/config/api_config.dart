class ApiConfig {
  const ApiConfig._();

  static const baseUrl = String.fromEnvironment(
    'IKRILI_API_URL',
    defaultValue: 'http://localhost:8000',
  );
}

