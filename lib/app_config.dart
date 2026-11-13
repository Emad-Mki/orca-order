class AppConfig {
  static const String _environment = String.fromEnvironment(
    'ORCA_ENV',
    defaultValue: 'production',
  );
  static const String _testingApiUrl = String.fromEnvironment(
    'ORCA_TEST_API_URL',
  );

  static String get apiUrl {
    switch (_environment) {
      case 'production':
        return 'https://script.google.com/macros/s/AKfycbxmLi8k4o9gO8kBx-9QrcPqcnA-kC-lffnsz70YArKRU7UoqdZMUeNV37Ov-gZJaWRd/exec';
      case 'testing':
        return _testingApiUrl;
      default:
        return '';
    }
  }

  static bool get isTesting => _environment == 'testing';
  static bool get isProduction => _environment == 'production';
  static String get environmentName => isTesting
      ? 'testing'
      : isProduction
          ? 'production'
          : 'invalid';

  static const String companyName = 'شركة أوركا ش.م.م';
  static const String companyNameEn = 'Orca L.L.C';

  static const String defaultCurrency = 'USD';
}
