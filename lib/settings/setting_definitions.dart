enum SettingScope { system, account, device }

enum SettingValueType { currency, decimal, integer, text, choice }

class SettingDefinition {
  const SettingDefinition({
    required this.key,
    required this.type,
    required this.defaultValue,
    required this.scope,
    required this.allowedRoles,
    required this.isValid,
  });

  final String key;
  final SettingValueType type;
  final Object? defaultValue;
  final SettingScope scope;
  final Set<String> allowedRoles;
  final bool Function(Object?) isValid;
}

bool _invoiceCurrency(Object? value) => value == 'USD';
bool _currency(Object? value) => value == 'USD' || value == 'SYP';
bool _rate(Object? value) =>
    value == null || value is num && value.isFinite && value > 0;
bool _precision(Object? value) => value is int && value >= 0 && value <= 4;
bool _theme(Object? value) => const {'system', 'light', 'dark'}.contains(value);
bool _productView(Object? value) => const {'grid', 'list'}.contains(value);
bool _text(Object? value) => value is String;

/// Definitions describe existing settings, not proposed server features.
abstract final class SettingDefinitions {
  static const salesRoles = {'admin', 'accountant'};
  static const allRoles = {
    'admin',
    'manager',
    'accountant',
    'warehouse',
    'salesperson',
    'customer',
    'user',
  };

  static const invoiceCurrency = SettingDefinition(
    key: 'invoice_currency',
    type: SettingValueType.currency,
    defaultValue: null,
    scope: SettingScope.system,
    allowedRoles: salesRoles,
    isValid: _invoiceCurrency,
  );
  static const shamCurrency = SettingDefinition(
    key: 'sham_cash_currency',
    type: SettingValueType.currency,
    defaultValue: null,
    scope: SettingScope.system,
    allowedRoles: salesRoles,
    isValid: _currency,
  );
  static const productCurrency = SettingDefinition(
    key: 'default_product_currency',
    type: SettingValueType.currency,
    defaultValue: null,
    scope: SettingScope.system,
    allowedRoles: salesRoles,
    isValid: _currency,
  );
  static const exchangeRate = SettingDefinition(
    key: 'rate_syp_per_usd',
    type: SettingValueType.decimal,
    defaultValue: null,
    scope: SettingScope.system,
    allowedRoles: salesRoles,
    isValid: _rate,
  );
  static const usdDecimals = SettingDefinition(
    key: 'usd_decimals',
    type: SettingValueType.integer,
    defaultValue: null,
    scope: SettingScope.system,
    allowedRoles: salesRoles,
    isValid: _precision,
  );
  static const sypDecimals = SettingDefinition(
    key: 'syp_decimals',
    type: SettingValueType.integer,
    defaultValue: null,
    scope: SettingScope.system,
    allowedRoles: salesRoles,
    isValid: _precision,
  );
  static const theme = SettingDefinition(
    key: 'orca_theme_mode',
    type: SettingValueType.choice,
    defaultValue: 'system',
    scope: SettingScope.device,
    allowedRoles: allRoles,
    isValid: _theme,
  );
  static const productView = SettingDefinition(
    key: 'product_view_mode',
    type: SettingValueType.choice,
    defaultValue: 'grid',
    scope: SettingScope.device,
    allowedRoles: allRoles,
    isValid: _productView,
  );
  static const syncFileId = SettingDefinition(
    key: 'csv_file_id',
    type: SettingValueType.text,
    defaultValue: '',
    scope: SettingScope.system,
    allowedRoles: {'admin'},
    isValid: _text,
  );
  static const accountName = SettingDefinition(
    key: 'full_name',
    type: SettingValueType.text,
    defaultValue: '',
    scope: SettingScope.account,
    allowedRoles: allRoles,
    isValid: _text,
  );
  static const accountPhone = SettingDefinition(
    key: 'phone',
    type: SettingValueType.text,
    defaultValue: '',
    scope: SettingScope.account,
    allowedRoles: allRoles,
    isValid: _text,
  );

  static const sales = [
    invoiceCurrency,
    shamCurrency,
    productCurrency,
    exchangeRate,
    usdDecimals,
    sypDecimals,
  ];
  static const all = [
    ...sales,
    syncFileId,
    theme,
    productView,
    accountName,
    accountPhone,
  ];
}
