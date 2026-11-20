import 'package:flutter_test/flutter_test.dart';
import 'package:orca_order/settings/setting_definitions.dart';

void main() {
  test('supported setting keys are unique and have explicit scope and roles',
      () {
    final definitions = SettingDefinitions.all;
    expect(definitions.map((setting) => setting.key).toSet().length,
        definitions.length);
    for (final setting in definitions) {
      expect(setting.allowedRoles, isNotEmpty);
      if (setting.scope != SettingScope.system) {
        expect(setting.isValid(setting.defaultValue), isTrue);
      }
    }
    expect(SettingDefinitions.theme.scope, SettingScope.device);
    expect(SettingDefinitions.accountName.scope, SettingScope.account);
    expect(
        SettingDefinitions.sales.every((setting) =>
            setting.scope == SettingScope.system &&
            setting.allowedRoles.length == 2 &&
            setting.allowedRoles.containsAll({'admin', 'accountant'})),
        isTrue);
  });

  test('financial setting rules reject invalid rates and precision', () {
    expect(SettingDefinitions.exchangeRate.isValid(null), isTrue);
    expect(SettingDefinitions.exchangeRate.isValid(14500), isTrue);
    expect(SettingDefinitions.exchangeRate.isValid(0), isFalse);
    expect(SettingDefinitions.exchangeRate.isValid(double.infinity), isFalse);
    for (final definition in [
      SettingDefinitions.usdDecimals,
      SettingDefinitions.sypDecimals,
    ]) {
      expect(definition.isValid(0), isTrue);
      expect(definition.isValid(4), isTrue);
      expect(definition.isValid(-1), isFalse);
      expect(definition.isValid(5), isFalse);
      expect(definition.isValid(1.5), isFalse);
    }
    expect(SettingDefinitions.invoiceCurrency.isValid('SYP'), isFalse);
    expect(SettingDefinitions.invoiceCurrency.isValid('USD'), isTrue);
  });
}
