// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database_service.dart';

// ignore_for_file: type=lint
class $LocalProductsTable extends LocalProducts
    with TableInfo<$LocalProductsTable, LocalProduct> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalProductsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _environmentMeta =
      const VerificationMeta('environment');
  @override
  late final GeneratedColumn<String> environment = GeneratedColumn<String>(
      'environment', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 50),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _accountIdMeta =
      const VerificationMeta('accountId');
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
      'account_id', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 50),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
      'code', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 50),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
      'unit', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _priceMicrosMeta =
      const VerificationMeta('priceMicros');
  @override
  late final GeneratedColumn<int> priceMicros = GeneratedColumn<int>(
      'price_micros', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _stockMicrosMeta =
      const VerificationMeta('stockMicros');
  @override
  late final GeneratedColumn<int> stockMicros = GeneratedColumn<int>(
      'stock_micros', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _currencyMeta =
      const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
      'currency', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 3, maxTextLength: 3),
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('USD'));
  static const VerificationMeta _imageUrlMeta =
      const VerificationMeta('imageUrl');
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
      'image_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _jsonDataMeta =
      const VerificationMeta('jsonData');
  @override
  late final GeneratedColumn<String> jsonData = GeneratedColumn<String>(
      'json_data', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        environment,
        accountId,
        code,
        name,
        category,
        unit,
        priceMicros,
        stockMicros,
        currency,
        imageUrl,
        jsonData
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_products';
  @override
  VerificationContext validateIntegrity(Insertable<LocalProduct> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('environment')) {
      context.handle(
          _environmentMeta,
          environment.isAcceptableOrUnknown(
              data['environment']!, _environmentMeta));
    } else if (isInserting) {
      context.missing(_environmentMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(_accountIdMeta,
          accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta));
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('code')) {
      context.handle(
          _codeMeta, code.isAcceptableOrUnknown(data['code']!, _codeMeta));
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('unit')) {
      context.handle(
          _unitMeta, unit.isAcceptableOrUnknown(data['unit']!, _unitMeta));
    } else if (isInserting) {
      context.missing(_unitMeta);
    }
    if (data.containsKey('price_micros')) {
      context.handle(
          _priceMicrosMeta,
          priceMicros.isAcceptableOrUnknown(
              data['price_micros']!, _priceMicrosMeta));
    } else if (isInserting) {
      context.missing(_priceMicrosMeta);
    }
    if (data.containsKey('stock_micros')) {
      context.handle(
          _stockMicrosMeta,
          stockMicros.isAcceptableOrUnknown(
              data['stock_micros']!, _stockMicrosMeta));
    } else if (isInserting) {
      context.missing(_stockMicrosMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta,
          currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    }
    if (data.containsKey('image_url')) {
      context.handle(_imageUrlMeta,
          imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta));
    }
    if (data.containsKey('json_data')) {
      context.handle(_jsonDataMeta,
          jsonData.isAcceptableOrUnknown(data['json_data']!, _jsonDataMeta));
    } else if (isInserting) {
      context.missing(_jsonDataMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {environment, accountId, code};
  @override
  LocalProduct map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalProduct(
      environment: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}environment'])!,
      accountId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}account_id'])!,
      code: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}code'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category'])!,
      unit: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}unit'])!,
      priceMicros: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}price_micros'])!,
      stockMicros: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}stock_micros'])!,
      currency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
      imageUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_url']),
      jsonData: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}json_data'])!,
    );
  }

  @override
  $LocalProductsTable createAlias(String alias) {
    return $LocalProductsTable(attachedDatabase, alias);
  }
}

class LocalProduct extends DataClass implements Insertable<LocalProduct> {
  final String environment;
  final String accountId;
  final String code;
  final String name;
  final String category;
  final String unit;
  final int priceMicros;
  final int stockMicros;
  final String currency;
  final String? imageUrl;
  final String jsonData;
  const LocalProduct(
      {required this.environment,
      required this.accountId,
      required this.code,
      required this.name,
      required this.category,
      required this.unit,
      required this.priceMicros,
      required this.stockMicros,
      required this.currency,
      this.imageUrl,
      required this.jsonData});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['environment'] = Variable<String>(environment);
    map['account_id'] = Variable<String>(accountId);
    map['code'] = Variable<String>(code);
    map['name'] = Variable<String>(name);
    map['category'] = Variable<String>(category);
    map['unit'] = Variable<String>(unit);
    map['price_micros'] = Variable<int>(priceMicros);
    map['stock_micros'] = Variable<int>(stockMicros);
    map['currency'] = Variable<String>(currency);
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    map['json_data'] = Variable<String>(jsonData);
    return map;
  }

  LocalProductsCompanion toCompanion(bool nullToAbsent) {
    return LocalProductsCompanion(
      environment: Value(environment),
      accountId: Value(accountId),
      code: Value(code),
      name: Value(name),
      category: Value(category),
      unit: Value(unit),
      priceMicros: Value(priceMicros),
      stockMicros: Value(stockMicros),
      currency: Value(currency),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
      jsonData: Value(jsonData),
    );
  }

  factory LocalProduct.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalProduct(
      environment: serializer.fromJson<String>(json['environment']),
      accountId: serializer.fromJson<String>(json['accountId']),
      code: serializer.fromJson<String>(json['code']),
      name: serializer.fromJson<String>(json['name']),
      category: serializer.fromJson<String>(json['category']),
      unit: serializer.fromJson<String>(json['unit']),
      priceMicros: serializer.fromJson<int>(json['priceMicros']),
      stockMicros: serializer.fromJson<int>(json['stockMicros']),
      currency: serializer.fromJson<String>(json['currency']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      jsonData: serializer.fromJson<String>(json['jsonData']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'environment': serializer.toJson<String>(environment),
      'accountId': serializer.toJson<String>(accountId),
      'code': serializer.toJson<String>(code),
      'name': serializer.toJson<String>(name),
      'category': serializer.toJson<String>(category),
      'unit': serializer.toJson<String>(unit),
      'priceMicros': serializer.toJson<int>(priceMicros),
      'stockMicros': serializer.toJson<int>(stockMicros),
      'currency': serializer.toJson<String>(currency),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'jsonData': serializer.toJson<String>(jsonData),
    };
  }

  LocalProduct copyWith(
          {String? environment,
          String? accountId,
          String? code,
          String? name,
          String? category,
          String? unit,
          int? priceMicros,
          int? stockMicros,
          String? currency,
          Value<String?> imageUrl = const Value.absent(),
          String? jsonData}) =>
      LocalProduct(
        environment: environment ?? this.environment,
        accountId: accountId ?? this.accountId,
        code: code ?? this.code,
        name: name ?? this.name,
        category: category ?? this.category,
        unit: unit ?? this.unit,
        priceMicros: priceMicros ?? this.priceMicros,
        stockMicros: stockMicros ?? this.stockMicros,
        currency: currency ?? this.currency,
        imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
        jsonData: jsonData ?? this.jsonData,
      );
  LocalProduct copyWithCompanion(LocalProductsCompanion data) {
    return LocalProduct(
      environment:
          data.environment.present ? data.environment.value : this.environment,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      code: data.code.present ? data.code.value : this.code,
      name: data.name.present ? data.name.value : this.name,
      category: data.category.present ? data.category.value : this.category,
      unit: data.unit.present ? data.unit.value : this.unit,
      priceMicros:
          data.priceMicros.present ? data.priceMicros.value : this.priceMicros,
      stockMicros:
          data.stockMicros.present ? data.stockMicros.value : this.stockMicros,
      currency: data.currency.present ? data.currency.value : this.currency,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      jsonData: data.jsonData.present ? data.jsonData.value : this.jsonData,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalProduct(')
          ..write('environment: $environment, ')
          ..write('accountId: $accountId, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('unit: $unit, ')
          ..write('priceMicros: $priceMicros, ')
          ..write('stockMicros: $stockMicros, ')
          ..write('currency: $currency, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('jsonData: $jsonData')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(environment, accountId, code, name, category,
      unit, priceMicros, stockMicros, currency, imageUrl, jsonData);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalProduct &&
          other.environment == this.environment &&
          other.accountId == this.accountId &&
          other.code == this.code &&
          other.name == this.name &&
          other.category == this.category &&
          other.unit == this.unit &&
          other.priceMicros == this.priceMicros &&
          other.stockMicros == this.stockMicros &&
          other.currency == this.currency &&
          other.imageUrl == this.imageUrl &&
          other.jsonData == this.jsonData);
}

class LocalProductsCompanion extends UpdateCompanion<LocalProduct> {
  final Value<String> environment;
  final Value<String> accountId;
  final Value<String> code;
  final Value<String> name;
  final Value<String> category;
  final Value<String> unit;
  final Value<int> priceMicros;
  final Value<int> stockMicros;
  final Value<String> currency;
  final Value<String?> imageUrl;
  final Value<String> jsonData;
  final Value<int> rowid;
  const LocalProductsCompanion({
    this.environment = const Value.absent(),
    this.accountId = const Value.absent(),
    this.code = const Value.absent(),
    this.name = const Value.absent(),
    this.category = const Value.absent(),
    this.unit = const Value.absent(),
    this.priceMicros = const Value.absent(),
    this.stockMicros = const Value.absent(),
    this.currency = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.jsonData = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalProductsCompanion.insert({
    required String environment,
    required String accountId,
    required String code,
    required String name,
    required String category,
    required String unit,
    required int priceMicros,
    required int stockMicros,
    this.currency = const Value.absent(),
    this.imageUrl = const Value.absent(),
    required String jsonData,
    this.rowid = const Value.absent(),
  })  : environment = Value(environment),
        accountId = Value(accountId),
        code = Value(code),
        name = Value(name),
        category = Value(category),
        unit = Value(unit),
        priceMicros = Value(priceMicros),
        stockMicros = Value(stockMicros),
        jsonData = Value(jsonData);
  static Insertable<LocalProduct> custom({
    Expression<String>? environment,
    Expression<String>? accountId,
    Expression<String>? code,
    Expression<String>? name,
    Expression<String>? category,
    Expression<String>? unit,
    Expression<int>? priceMicros,
    Expression<int>? stockMicros,
    Expression<String>? currency,
    Expression<String>? imageUrl,
    Expression<String>? jsonData,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (environment != null) 'environment': environment,
      if (accountId != null) 'account_id': accountId,
      if (code != null) 'code': code,
      if (name != null) 'name': name,
      if (category != null) 'category': category,
      if (unit != null) 'unit': unit,
      if (priceMicros != null) 'price_micros': priceMicros,
      if (stockMicros != null) 'stock_micros': stockMicros,
      if (currency != null) 'currency': currency,
      if (imageUrl != null) 'image_url': imageUrl,
      if (jsonData != null) 'json_data': jsonData,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalProductsCompanion copyWith(
      {Value<String>? environment,
      Value<String>? accountId,
      Value<String>? code,
      Value<String>? name,
      Value<String>? category,
      Value<String>? unit,
      Value<int>? priceMicros,
      Value<int>? stockMicros,
      Value<String>? currency,
      Value<String?>? imageUrl,
      Value<String>? jsonData,
      Value<int>? rowid}) {
    return LocalProductsCompanion(
      environment: environment ?? this.environment,
      accountId: accountId ?? this.accountId,
      code: code ?? this.code,
      name: name ?? this.name,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      priceMicros: priceMicros ?? this.priceMicros,
      stockMicros: stockMicros ?? this.stockMicros,
      currency: currency ?? this.currency,
      imageUrl: imageUrl ?? this.imageUrl,
      jsonData: jsonData ?? this.jsonData,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (environment.present) {
      map['environment'] = Variable<String>(environment.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (priceMicros.present) {
      map['price_micros'] = Variable<int>(priceMicros.value);
    }
    if (stockMicros.present) {
      map['stock_micros'] = Variable<int>(stockMicros.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (jsonData.present) {
      map['json_data'] = Variable<String>(jsonData.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalProductsCompanion(')
          ..write('environment: $environment, ')
          ..write('accountId: $accountId, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('unit: $unit, ')
          ..write('priceMicros: $priceMicros, ')
          ..write('stockMicros: $stockMicros, ')
          ..write('currency: $currency, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('jsonData: $jsonData, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OrderDraftsTable extends OrderDrafts
    with TableInfo<$OrderDraftsTable, LocalOrderDraft> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OrderDraftsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _environmentMeta =
      const VerificationMeta('environment');
  @override
  late final GeneratedColumn<String> environment = GeneratedColumn<String>(
      'environment', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 50),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _accountIdMeta =
      const VerificationMeta('accountId');
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
      'account_id', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 50),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _customerIdMeta =
      const VerificationMeta('customerId');
  @override
  late final GeneratedColumn<String> customerId = GeneratedColumn<String>(
      'customer_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _customerNameMeta =
      const VerificationMeta('customerName');
  @override
  late final GeneratedColumn<String> customerName = GeneratedColumn<String>(
      'customer_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('draft'));
  static const VerificationMeta _currencyMeta =
      const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
      'currency', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 3, maxTextLength: 3),
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('USD'));
  static const VerificationMeta _customTitleMeta =
      const VerificationMeta('customTitle');
  @override
  late final GeneratedColumn<String> customTitle = GeneratedColumn<String>(
      'custom_title', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        environment,
        accountId,
        customerId,
        customerName,
        createdAt,
        updatedAt,
        note,
        status,
        currency,
        customTitle
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'order_drafts';
  @override
  VerificationContext validateIntegrity(Insertable<LocalOrderDraft> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('environment')) {
      context.handle(
          _environmentMeta,
          environment.isAcceptableOrUnknown(
              data['environment']!, _environmentMeta));
    } else if (isInserting) {
      context.missing(_environmentMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(_accountIdMeta,
          accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta));
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('customer_id')) {
      context.handle(
          _customerIdMeta,
          customerId.isAcceptableOrUnknown(
              data['customer_id']!, _customerIdMeta));
    } else if (isInserting) {
      context.missing(_customerIdMeta);
    }
    if (data.containsKey('customer_name')) {
      context.handle(
          _customerNameMeta,
          customerName.isAcceptableOrUnknown(
              data['customer_name']!, _customerNameMeta));
    } else if (isInserting) {
      context.missing(_customerNameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta,
          currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    }
    if (data.containsKey('custom_title')) {
      context.handle(
          _customTitleMeta,
          customTitle.isAcceptableOrUnknown(
              data['custom_title']!, _customTitleMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalOrderDraft map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalOrderDraft(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      environment: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}environment'])!,
      accountId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}account_id'])!,
      customerId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}customer_id'])!,
      customerName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}customer_name'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      currency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
      customTitle: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}custom_title']),
    );
  }

  @override
  $OrderDraftsTable createAlias(String alias) {
    return $OrderDraftsTable(attachedDatabase, alias);
  }
}

class LocalOrderDraft extends DataClass implements Insertable<LocalOrderDraft> {
  final int id;
  final String environment;
  final String accountId;
  final String customerId;
  final String customerName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? note;
  final String status;
  final String currency;
  final String? customTitle;
  const LocalOrderDraft(
      {required this.id,
      required this.environment,
      required this.accountId,
      required this.customerId,
      required this.customerName,
      required this.createdAt,
      required this.updatedAt,
      this.note,
      required this.status,
      required this.currency,
      this.customTitle});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['environment'] = Variable<String>(environment);
    map['account_id'] = Variable<String>(accountId);
    map['customer_id'] = Variable<String>(customerId);
    map['customer_name'] = Variable<String>(customerName);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['status'] = Variable<String>(status);
    map['currency'] = Variable<String>(currency);
    if (!nullToAbsent || customTitle != null) {
      map['custom_title'] = Variable<String>(customTitle);
    }
    return map;
  }

  OrderDraftsCompanion toCompanion(bool nullToAbsent) {
    return OrderDraftsCompanion(
      id: Value(id),
      environment: Value(environment),
      accountId: Value(accountId),
      customerId: Value(customerId),
      customerName: Value(customerName),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      status: Value(status),
      currency: Value(currency),
      customTitle: customTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(customTitle),
    );
  }

  factory LocalOrderDraft.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalOrderDraft(
      id: serializer.fromJson<int>(json['id']),
      environment: serializer.fromJson<String>(json['environment']),
      accountId: serializer.fromJson<String>(json['accountId']),
      customerId: serializer.fromJson<String>(json['customerId']),
      customerName: serializer.fromJson<String>(json['customerName']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      note: serializer.fromJson<String?>(json['note']),
      status: serializer.fromJson<String>(json['status']),
      currency: serializer.fromJson<String>(json['currency']),
      customTitle: serializer.fromJson<String?>(json['customTitle']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'environment': serializer.toJson<String>(environment),
      'accountId': serializer.toJson<String>(accountId),
      'customerId': serializer.toJson<String>(customerId),
      'customerName': serializer.toJson<String>(customerName),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'note': serializer.toJson<String?>(note),
      'status': serializer.toJson<String>(status),
      'currency': serializer.toJson<String>(currency),
      'customTitle': serializer.toJson<String?>(customTitle),
    };
  }

  LocalOrderDraft copyWith(
          {int? id,
          String? environment,
          String? accountId,
          String? customerId,
          String? customerName,
          DateTime? createdAt,
          DateTime? updatedAt,
          Value<String?> note = const Value.absent(),
          String? status,
          String? currency,
          Value<String?> customTitle = const Value.absent()}) =>
      LocalOrderDraft(
        id: id ?? this.id,
        environment: environment ?? this.environment,
        accountId: accountId ?? this.accountId,
        customerId: customerId ?? this.customerId,
        customerName: customerName ?? this.customerName,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        note: note.present ? note.value : this.note,
        status: status ?? this.status,
        currency: currency ?? this.currency,
        customTitle: customTitle.present ? customTitle.value : this.customTitle,
      );
  LocalOrderDraft copyWithCompanion(OrderDraftsCompanion data) {
    return LocalOrderDraft(
      id: data.id.present ? data.id.value : this.id,
      environment:
          data.environment.present ? data.environment.value : this.environment,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      customerId:
          data.customerId.present ? data.customerId.value : this.customerId,
      customerName: data.customerName.present
          ? data.customerName.value
          : this.customerName,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      note: data.note.present ? data.note.value : this.note,
      status: data.status.present ? data.status.value : this.status,
      currency: data.currency.present ? data.currency.value : this.currency,
      customTitle:
          data.customTitle.present ? data.customTitle.value : this.customTitle,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalOrderDraft(')
          ..write('id: $id, ')
          ..write('environment: $environment, ')
          ..write('accountId: $accountId, ')
          ..write('customerId: $customerId, ')
          ..write('customerName: $customerName, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('note: $note, ')
          ..write('status: $status, ')
          ..write('currency: $currency, ')
          ..write('customTitle: $customTitle')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, environment, accountId, customerId,
      customerName, createdAt, updatedAt, note, status, currency, customTitle);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalOrderDraft &&
          other.id == this.id &&
          other.environment == this.environment &&
          other.accountId == this.accountId &&
          other.customerId == this.customerId &&
          other.customerName == this.customerName &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.note == this.note &&
          other.status == this.status &&
          other.currency == this.currency &&
          other.customTitle == this.customTitle);
}

class OrderDraftsCompanion extends UpdateCompanion<LocalOrderDraft> {
  final Value<int> id;
  final Value<String> environment;
  final Value<String> accountId;
  final Value<String> customerId;
  final Value<String> customerName;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String?> note;
  final Value<String> status;
  final Value<String> currency;
  final Value<String?> customTitle;
  const OrderDraftsCompanion({
    this.id = const Value.absent(),
    this.environment = const Value.absent(),
    this.accountId = const Value.absent(),
    this.customerId = const Value.absent(),
    this.customerName = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.note = const Value.absent(),
    this.status = const Value.absent(),
    this.currency = const Value.absent(),
    this.customTitle = const Value.absent(),
  });
  OrderDraftsCompanion.insert({
    this.id = const Value.absent(),
    required String environment,
    required String accountId,
    required String customerId,
    required String customerName,
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.note = const Value.absent(),
    this.status = const Value.absent(),
    this.currency = const Value.absent(),
    this.customTitle = const Value.absent(),
  })  : environment = Value(environment),
        accountId = Value(accountId),
        customerId = Value(customerId),
        customerName = Value(customerName);
  static Insertable<LocalOrderDraft> custom({
    Expression<int>? id,
    Expression<String>? environment,
    Expression<String>? accountId,
    Expression<String>? customerId,
    Expression<String>? customerName,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? note,
    Expression<String>? status,
    Expression<String>? currency,
    Expression<String>? customTitle,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (environment != null) 'environment': environment,
      if (accountId != null) 'account_id': accountId,
      if (customerId != null) 'customer_id': customerId,
      if (customerName != null) 'customer_name': customerName,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (note != null) 'note': note,
      if (status != null) 'status': status,
      if (currency != null) 'currency': currency,
      if (customTitle != null) 'custom_title': customTitle,
    });
  }

  OrderDraftsCompanion copyWith(
      {Value<int>? id,
      Value<String>? environment,
      Value<String>? accountId,
      Value<String>? customerId,
      Value<String>? customerName,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<String?>? note,
      Value<String>? status,
      Value<String>? currency,
      Value<String?>? customTitle}) {
    return OrderDraftsCompanion(
      id: id ?? this.id,
      environment: environment ?? this.environment,
      accountId: accountId ?? this.accountId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      note: note ?? this.note,
      status: status ?? this.status,
      currency: currency ?? this.currency,
      customTitle: customTitle ?? this.customTitle,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (environment.present) {
      map['environment'] = Variable<String>(environment.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (customerId.present) {
      map['customer_id'] = Variable<String>(customerId.value);
    }
    if (customerName.present) {
      map['customer_name'] = Variable<String>(customerName.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (customTitle.present) {
      map['custom_title'] = Variable<String>(customTitle.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OrderDraftsCompanion(')
          ..write('id: $id, ')
          ..write('environment: $environment, ')
          ..write('accountId: $accountId, ')
          ..write('customerId: $customerId, ')
          ..write('customerName: $customerName, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('note: $note, ')
          ..write('status: $status, ')
          ..write('currency: $currency, ')
          ..write('customTitle: $customTitle')
          ..write(')'))
        .toString();
  }
}

class $OrderDraftItemsTable extends OrderDraftItems
    with TableInfo<$OrderDraftItemsTable, LocalOrderItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OrderDraftItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _draftIdMeta =
      const VerificationMeta('draftId');
  @override
  late final GeneratedColumn<int> draftId = GeneratedColumn<int>(
      'draft_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES order_drafts (id) ON DELETE CASCADE'));
  static const VerificationMeta _productCodeMeta =
      const VerificationMeta('productCode');
  @override
  late final GeneratedColumn<String> productCode = GeneratedColumn<String>(
      'product_code', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 50),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _productNameMeta =
      const VerificationMeta('productName');
  @override
  late final GeneratedColumn<String> productName = GeneratedColumn<String>(
      'product_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
      'unit', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _quantityMicrosMeta =
      const VerificationMeta('quantityMicros');
  @override
  late final GeneratedColumn<int> quantityMicros = GeneratedColumn<int>(
      'quantity_micros', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _priceMicrosMeta =
      const VerificationMeta('priceMicros');
  @override
  late final GeneratedColumn<int> priceMicros = GeneratedColumn<int>(
      'price_micros', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _productDataJsonMeta =
      const VerificationMeta('productDataJson');
  @override
  late final GeneratedColumn<String> productDataJson = GeneratedColumn<String>(
      'product_data_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        draftId,
        productCode,
        productName,
        unit,
        quantityMicros,
        priceMicros,
        note,
        productDataJson
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'order_draft_items';
  @override
  VerificationContext validateIntegrity(Insertable<LocalOrderItem> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('draft_id')) {
      context.handle(_draftIdMeta,
          draftId.isAcceptableOrUnknown(data['draft_id']!, _draftIdMeta));
    } else if (isInserting) {
      context.missing(_draftIdMeta);
    }
    if (data.containsKey('product_code')) {
      context.handle(
          _productCodeMeta,
          productCode.isAcceptableOrUnknown(
              data['product_code']!, _productCodeMeta));
    } else if (isInserting) {
      context.missing(_productCodeMeta);
    }
    if (data.containsKey('product_name')) {
      context.handle(
          _productNameMeta,
          productName.isAcceptableOrUnknown(
              data['product_name']!, _productNameMeta));
    } else if (isInserting) {
      context.missing(_productNameMeta);
    }
    if (data.containsKey('unit')) {
      context.handle(
          _unitMeta, unit.isAcceptableOrUnknown(data['unit']!, _unitMeta));
    } else if (isInserting) {
      context.missing(_unitMeta);
    }
    if (data.containsKey('quantity_micros')) {
      context.handle(
          _quantityMicrosMeta,
          quantityMicros.isAcceptableOrUnknown(
              data['quantity_micros']!, _quantityMicrosMeta));
    } else if (isInserting) {
      context.missing(_quantityMicrosMeta);
    }
    if (data.containsKey('price_micros')) {
      context.handle(
          _priceMicrosMeta,
          priceMicros.isAcceptableOrUnknown(
              data['price_micros']!, _priceMicrosMeta));
    } else if (isInserting) {
      context.missing(_priceMicrosMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('product_data_json')) {
      context.handle(
          _productDataJsonMeta,
          productDataJson.isAcceptableOrUnknown(
              data['product_data_json']!, _productDataJsonMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalOrderItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalOrderItem(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      draftId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}draft_id'])!,
      productCode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}product_code'])!,
      productName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}product_name'])!,
      unit: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}unit'])!,
      quantityMicros: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}quantity_micros'])!,
      priceMicros: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}price_micros'])!,
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
      productDataJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}product_data_json']),
    );
  }

  @override
  $OrderDraftItemsTable createAlias(String alias) {
    return $OrderDraftItemsTable(attachedDatabase, alias);
  }
}

class LocalOrderItem extends DataClass implements Insertable<LocalOrderItem> {
  final int id;
  final int draftId;
  final String productCode;
  final String productName;
  final String unit;
  final int quantityMicros;
  final int priceMicros;
  final String? note;
  final String? productDataJson;
  const LocalOrderItem(
      {required this.id,
      required this.draftId,
      required this.productCode,
      required this.productName,
      required this.unit,
      required this.quantityMicros,
      required this.priceMicros,
      this.note,
      this.productDataJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['draft_id'] = Variable<int>(draftId);
    map['product_code'] = Variable<String>(productCode);
    map['product_name'] = Variable<String>(productName);
    map['unit'] = Variable<String>(unit);
    map['quantity_micros'] = Variable<int>(quantityMicros);
    map['price_micros'] = Variable<int>(priceMicros);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || productDataJson != null) {
      map['product_data_json'] = Variable<String>(productDataJson);
    }
    return map;
  }

  OrderDraftItemsCompanion toCompanion(bool nullToAbsent) {
    return OrderDraftItemsCompanion(
      id: Value(id),
      draftId: Value(draftId),
      productCode: Value(productCode),
      productName: Value(productName),
      unit: Value(unit),
      quantityMicros: Value(quantityMicros),
      priceMicros: Value(priceMicros),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      productDataJson: productDataJson == null && nullToAbsent
          ? const Value.absent()
          : Value(productDataJson),
    );
  }

  factory LocalOrderItem.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalOrderItem(
      id: serializer.fromJson<int>(json['id']),
      draftId: serializer.fromJson<int>(json['draftId']),
      productCode: serializer.fromJson<String>(json['productCode']),
      productName: serializer.fromJson<String>(json['productName']),
      unit: serializer.fromJson<String>(json['unit']),
      quantityMicros: serializer.fromJson<int>(json['quantityMicros']),
      priceMicros: serializer.fromJson<int>(json['priceMicros']),
      note: serializer.fromJson<String?>(json['note']),
      productDataJson: serializer.fromJson<String?>(json['productDataJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'draftId': serializer.toJson<int>(draftId),
      'productCode': serializer.toJson<String>(productCode),
      'productName': serializer.toJson<String>(productName),
      'unit': serializer.toJson<String>(unit),
      'quantityMicros': serializer.toJson<int>(quantityMicros),
      'priceMicros': serializer.toJson<int>(priceMicros),
      'note': serializer.toJson<String?>(note),
      'productDataJson': serializer.toJson<String?>(productDataJson),
    };
  }

  LocalOrderItem copyWith(
          {int? id,
          int? draftId,
          String? productCode,
          String? productName,
          String? unit,
          int? quantityMicros,
          int? priceMicros,
          Value<String?> note = const Value.absent(),
          Value<String?> productDataJson = const Value.absent()}) =>
      LocalOrderItem(
        id: id ?? this.id,
        draftId: draftId ?? this.draftId,
        productCode: productCode ?? this.productCode,
        productName: productName ?? this.productName,
        unit: unit ?? this.unit,
        quantityMicros: quantityMicros ?? this.quantityMicros,
        priceMicros: priceMicros ?? this.priceMicros,
        note: note.present ? note.value : this.note,
        productDataJson: productDataJson.present
            ? productDataJson.value
            : this.productDataJson,
      );
  LocalOrderItem copyWithCompanion(OrderDraftItemsCompanion data) {
    return LocalOrderItem(
      id: data.id.present ? data.id.value : this.id,
      draftId: data.draftId.present ? data.draftId.value : this.draftId,
      productCode:
          data.productCode.present ? data.productCode.value : this.productCode,
      productName:
          data.productName.present ? data.productName.value : this.productName,
      unit: data.unit.present ? data.unit.value : this.unit,
      quantityMicros: data.quantityMicros.present
          ? data.quantityMicros.value
          : this.quantityMicros,
      priceMicros:
          data.priceMicros.present ? data.priceMicros.value : this.priceMicros,
      note: data.note.present ? data.note.value : this.note,
      productDataJson: data.productDataJson.present
          ? data.productDataJson.value
          : this.productDataJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalOrderItem(')
          ..write('id: $id, ')
          ..write('draftId: $draftId, ')
          ..write('productCode: $productCode, ')
          ..write('productName: $productName, ')
          ..write('unit: $unit, ')
          ..write('quantityMicros: $quantityMicros, ')
          ..write('priceMicros: $priceMicros, ')
          ..write('note: $note, ')
          ..write('productDataJson: $productDataJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, draftId, productCode, productName, unit,
      quantityMicros, priceMicros, note, productDataJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalOrderItem &&
          other.id == this.id &&
          other.draftId == this.draftId &&
          other.productCode == this.productCode &&
          other.productName == this.productName &&
          other.unit == this.unit &&
          other.quantityMicros == this.quantityMicros &&
          other.priceMicros == this.priceMicros &&
          other.note == this.note &&
          other.productDataJson == this.productDataJson);
}

class OrderDraftItemsCompanion extends UpdateCompanion<LocalOrderItem> {
  final Value<int> id;
  final Value<int> draftId;
  final Value<String> productCode;
  final Value<String> productName;
  final Value<String> unit;
  final Value<int> quantityMicros;
  final Value<int> priceMicros;
  final Value<String?> note;
  final Value<String?> productDataJson;
  const OrderDraftItemsCompanion({
    this.id = const Value.absent(),
    this.draftId = const Value.absent(),
    this.productCode = const Value.absent(),
    this.productName = const Value.absent(),
    this.unit = const Value.absent(),
    this.quantityMicros = const Value.absent(),
    this.priceMicros = const Value.absent(),
    this.note = const Value.absent(),
    this.productDataJson = const Value.absent(),
  });
  OrderDraftItemsCompanion.insert({
    this.id = const Value.absent(),
    required int draftId,
    required String productCode,
    required String productName,
    required String unit,
    required int quantityMicros,
    required int priceMicros,
    this.note = const Value.absent(),
    this.productDataJson = const Value.absent(),
  })  : draftId = Value(draftId),
        productCode = Value(productCode),
        productName = Value(productName),
        unit = Value(unit),
        quantityMicros = Value(quantityMicros),
        priceMicros = Value(priceMicros);
  static Insertable<LocalOrderItem> custom({
    Expression<int>? id,
    Expression<int>? draftId,
    Expression<String>? productCode,
    Expression<String>? productName,
    Expression<String>? unit,
    Expression<int>? quantityMicros,
    Expression<int>? priceMicros,
    Expression<String>? note,
    Expression<String>? productDataJson,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (draftId != null) 'draft_id': draftId,
      if (productCode != null) 'product_code': productCode,
      if (productName != null) 'product_name': productName,
      if (unit != null) 'unit': unit,
      if (quantityMicros != null) 'quantity_micros': quantityMicros,
      if (priceMicros != null) 'price_micros': priceMicros,
      if (note != null) 'note': note,
      if (productDataJson != null) 'product_data_json': productDataJson,
    });
  }

  OrderDraftItemsCompanion copyWith(
      {Value<int>? id,
      Value<int>? draftId,
      Value<String>? productCode,
      Value<String>? productName,
      Value<String>? unit,
      Value<int>? quantityMicros,
      Value<int>? priceMicros,
      Value<String?>? note,
      Value<String?>? productDataJson}) {
    return OrderDraftItemsCompanion(
      id: id ?? this.id,
      draftId: draftId ?? this.draftId,
      productCode: productCode ?? this.productCode,
      productName: productName ?? this.productName,
      unit: unit ?? this.unit,
      quantityMicros: quantityMicros ?? this.quantityMicros,
      priceMicros: priceMicros ?? this.priceMicros,
      note: note ?? this.note,
      productDataJson: productDataJson ?? this.productDataJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (draftId.present) {
      map['draft_id'] = Variable<int>(draftId.value);
    }
    if (productCode.present) {
      map['product_code'] = Variable<String>(productCode.value);
    }
    if (productName.present) {
      map['product_name'] = Variable<String>(productName.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (quantityMicros.present) {
      map['quantity_micros'] = Variable<int>(quantityMicros.value);
    }
    if (priceMicros.present) {
      map['price_micros'] = Variable<int>(priceMicros.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (productDataJson.present) {
      map['product_data_json'] = Variable<String>(productDataJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OrderDraftItemsCompanion(')
          ..write('id: $id, ')
          ..write('draftId: $draftId, ')
          ..write('productCode: $productCode, ')
          ..write('productName: $productName, ')
          ..write('unit: $unit, ')
          ..write('quantityMicros: $quantityMicros, ')
          ..write('priceMicros: $priceMicros, ')
          ..write('note: $note, ')
          ..write('productDataJson: $productDataJson')
          ..write(')'))
        .toString();
  }
}

class $LocalOrdersTable extends LocalOrders
    with TableInfo<$LocalOrdersTable, LocalOrder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalOrdersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _orderIdMeta =
      const VerificationMeta('orderId');
  @override
  late final GeneratedColumn<String> orderId = GeneratedColumn<String>(
      'order_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _environmentMeta =
      const VerificationMeta('environment');
  @override
  late final GeneratedColumn<String> environment = GeneratedColumn<String>(
      'environment', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _accountIdMeta =
      const VerificationMeta('accountId');
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
      'account_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _orderNumberMeta =
      const VerificationMeta('orderNumber');
  @override
  late final GeneratedColumn<String> orderNumber = GeneratedColumn<String>(
      'order_number', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _customerIdMeta =
      const VerificationMeta('customerId');
  @override
  late final GeneratedColumn<String> customerId = GeneratedColumn<String>(
      'customer_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _customerNameMeta =
      const VerificationMeta('customerName');
  @override
  late final GeneratedColumn<String> customerName = GeneratedColumn<String>(
      'customer_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _currencyMeta =
      const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
      'currency', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _totalAmountMicrosMeta =
      const VerificationMeta('totalAmountMicros');
  @override
  late final GeneratedColumn<int> totalAmountMicros = GeneratedColumn<int>(
      'total_amount_micros', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _jsonDataMeta =
      const VerificationMeta('jsonData');
  @override
  late final GeneratedColumn<String> jsonData = GeneratedColumn<String>(
      'json_data', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        orderId,
        environment,
        accountId,
        orderNumber,
        customerId,
        customerName,
        status,
        currency,
        createdAt,
        updatedAt,
        totalAmountMicros,
        jsonData
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_orders';
  @override
  VerificationContext validateIntegrity(Insertable<LocalOrder> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('order_id')) {
      context.handle(_orderIdMeta,
          orderId.isAcceptableOrUnknown(data['order_id']!, _orderIdMeta));
    } else if (isInserting) {
      context.missing(_orderIdMeta);
    }
    if (data.containsKey('environment')) {
      context.handle(
          _environmentMeta,
          environment.isAcceptableOrUnknown(
              data['environment']!, _environmentMeta));
    } else if (isInserting) {
      context.missing(_environmentMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(_accountIdMeta,
          accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta));
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('order_number')) {
      context.handle(
          _orderNumberMeta,
          orderNumber.isAcceptableOrUnknown(
              data['order_number']!, _orderNumberMeta));
    } else if (isInserting) {
      context.missing(_orderNumberMeta);
    }
    if (data.containsKey('customer_id')) {
      context.handle(
          _customerIdMeta,
          customerId.isAcceptableOrUnknown(
              data['customer_id']!, _customerIdMeta));
    } else if (isInserting) {
      context.missing(_customerIdMeta);
    }
    if (data.containsKey('customer_name')) {
      context.handle(
          _customerNameMeta,
          customerName.isAcceptableOrUnknown(
              data['customer_name']!, _customerNameMeta));
    } else if (isInserting) {
      context.missing(_customerNameMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta,
          currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    if (data.containsKey('total_amount_micros')) {
      context.handle(
          _totalAmountMicrosMeta,
          totalAmountMicros.isAcceptableOrUnknown(
              data['total_amount_micros']!, _totalAmountMicrosMeta));
    }
    if (data.containsKey('json_data')) {
      context.handle(_jsonDataMeta,
          jsonData.isAcceptableOrUnknown(data['json_data']!, _jsonDataMeta));
    } else if (isInserting) {
      context.missing(_jsonDataMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {orderId, environment, accountId};
  @override
  LocalOrder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalOrder(
      orderId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}order_id'])!,
      environment: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}environment'])!,
      accountId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}account_id'])!,
      orderNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}order_number'])!,
      customerId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}customer_id'])!,
      customerName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}customer_name'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      currency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at']),
      totalAmountMicros: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}total_amount_micros']),
      jsonData: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}json_data'])!,
    );
  }

  @override
  $LocalOrdersTable createAlias(String alias) {
    return $LocalOrdersTable(attachedDatabase, alias);
  }
}

class LocalOrder extends DataClass implements Insertable<LocalOrder> {
  final String orderId;
  final String environment;
  final String accountId;
  final String orderNumber;
  final String customerId;
  final String customerName;
  final String status;
  final String currency;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? totalAmountMicros;
  final String jsonData;
  const LocalOrder(
      {required this.orderId,
      required this.environment,
      required this.accountId,
      required this.orderNumber,
      required this.customerId,
      required this.customerName,
      required this.status,
      required this.currency,
      this.createdAt,
      this.updatedAt,
      this.totalAmountMicros,
      required this.jsonData});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['order_id'] = Variable<String>(orderId);
    map['environment'] = Variable<String>(environment);
    map['account_id'] = Variable<String>(accountId);
    map['order_number'] = Variable<String>(orderNumber);
    map['customer_id'] = Variable<String>(customerId);
    map['customer_name'] = Variable<String>(customerName);
    map['status'] = Variable<String>(status);
    map['currency'] = Variable<String>(currency);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    if (!nullToAbsent || totalAmountMicros != null) {
      map['total_amount_micros'] = Variable<int>(totalAmountMicros);
    }
    map['json_data'] = Variable<String>(jsonData);
    return map;
  }

  LocalOrdersCompanion toCompanion(bool nullToAbsent) {
    return LocalOrdersCompanion(
      orderId: Value(orderId),
      environment: Value(environment),
      accountId: Value(accountId),
      orderNumber: Value(orderNumber),
      customerId: Value(customerId),
      customerName: Value(customerName),
      status: Value(status),
      currency: Value(currency),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      totalAmountMicros: totalAmountMicros == null && nullToAbsent
          ? const Value.absent()
          : Value(totalAmountMicros),
      jsonData: Value(jsonData),
    );
  }

  factory LocalOrder.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalOrder(
      orderId: serializer.fromJson<String>(json['orderId']),
      environment: serializer.fromJson<String>(json['environment']),
      accountId: serializer.fromJson<String>(json['accountId']),
      orderNumber: serializer.fromJson<String>(json['orderNumber']),
      customerId: serializer.fromJson<String>(json['customerId']),
      customerName: serializer.fromJson<String>(json['customerName']),
      status: serializer.fromJson<String>(json['status']),
      currency: serializer.fromJson<String>(json['currency']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      totalAmountMicros: serializer.fromJson<int?>(json['totalAmountMicros']),
      jsonData: serializer.fromJson<String>(json['jsonData']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'orderId': serializer.toJson<String>(orderId),
      'environment': serializer.toJson<String>(environment),
      'accountId': serializer.toJson<String>(accountId),
      'orderNumber': serializer.toJson<String>(orderNumber),
      'customerId': serializer.toJson<String>(customerId),
      'customerName': serializer.toJson<String>(customerName),
      'status': serializer.toJson<String>(status),
      'currency': serializer.toJson<String>(currency),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'totalAmountMicros': serializer.toJson<int?>(totalAmountMicros),
      'jsonData': serializer.toJson<String>(jsonData),
    };
  }

  LocalOrder copyWith(
          {String? orderId,
          String? environment,
          String? accountId,
          String? orderNumber,
          String? customerId,
          String? customerName,
          String? status,
          String? currency,
          Value<DateTime?> createdAt = const Value.absent(),
          Value<DateTime?> updatedAt = const Value.absent(),
          Value<int?> totalAmountMicros = const Value.absent(),
          String? jsonData}) =>
      LocalOrder(
        orderId: orderId ?? this.orderId,
        environment: environment ?? this.environment,
        accountId: accountId ?? this.accountId,
        orderNumber: orderNumber ?? this.orderNumber,
        customerId: customerId ?? this.customerId,
        customerName: customerName ?? this.customerName,
        status: status ?? this.status,
        currency: currency ?? this.currency,
        createdAt: createdAt.present ? createdAt.value : this.createdAt,
        updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
        totalAmountMicros: totalAmountMicros.present
            ? totalAmountMicros.value
            : this.totalAmountMicros,
        jsonData: jsonData ?? this.jsonData,
      );
  LocalOrder copyWithCompanion(LocalOrdersCompanion data) {
    return LocalOrder(
      orderId: data.orderId.present ? data.orderId.value : this.orderId,
      environment:
          data.environment.present ? data.environment.value : this.environment,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      orderNumber:
          data.orderNumber.present ? data.orderNumber.value : this.orderNumber,
      customerId:
          data.customerId.present ? data.customerId.value : this.customerId,
      customerName: data.customerName.present
          ? data.customerName.value
          : this.customerName,
      status: data.status.present ? data.status.value : this.status,
      currency: data.currency.present ? data.currency.value : this.currency,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      totalAmountMicros: data.totalAmountMicros.present
          ? data.totalAmountMicros.value
          : this.totalAmountMicros,
      jsonData: data.jsonData.present ? data.jsonData.value : this.jsonData,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalOrder(')
          ..write('orderId: $orderId, ')
          ..write('environment: $environment, ')
          ..write('accountId: $accountId, ')
          ..write('orderNumber: $orderNumber, ')
          ..write('customerId: $customerId, ')
          ..write('customerName: $customerName, ')
          ..write('status: $status, ')
          ..write('currency: $currency, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('totalAmountMicros: $totalAmountMicros, ')
          ..write('jsonData: $jsonData')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      orderId,
      environment,
      accountId,
      orderNumber,
      customerId,
      customerName,
      status,
      currency,
      createdAt,
      updatedAt,
      totalAmountMicros,
      jsonData);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalOrder &&
          other.orderId == this.orderId &&
          other.environment == this.environment &&
          other.accountId == this.accountId &&
          other.orderNumber == this.orderNumber &&
          other.customerId == this.customerId &&
          other.customerName == this.customerName &&
          other.status == this.status &&
          other.currency == this.currency &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.totalAmountMicros == this.totalAmountMicros &&
          other.jsonData == this.jsonData);
}

class LocalOrdersCompanion extends UpdateCompanion<LocalOrder> {
  final Value<String> orderId;
  final Value<String> environment;
  final Value<String> accountId;
  final Value<String> orderNumber;
  final Value<String> customerId;
  final Value<String> customerName;
  final Value<String> status;
  final Value<String> currency;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<int?> totalAmountMicros;
  final Value<String> jsonData;
  final Value<int> rowid;
  const LocalOrdersCompanion({
    this.orderId = const Value.absent(),
    this.environment = const Value.absent(),
    this.accountId = const Value.absent(),
    this.orderNumber = const Value.absent(),
    this.customerId = const Value.absent(),
    this.customerName = const Value.absent(),
    this.status = const Value.absent(),
    this.currency = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.totalAmountMicros = const Value.absent(),
    this.jsonData = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalOrdersCompanion.insert({
    required String orderId,
    required String environment,
    required String accountId,
    required String orderNumber,
    required String customerId,
    required String customerName,
    required String status,
    required String currency,
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.totalAmountMicros = const Value.absent(),
    required String jsonData,
    this.rowid = const Value.absent(),
  })  : orderId = Value(orderId),
        environment = Value(environment),
        accountId = Value(accountId),
        orderNumber = Value(orderNumber),
        customerId = Value(customerId),
        customerName = Value(customerName),
        status = Value(status),
        currency = Value(currency),
        jsonData = Value(jsonData);
  static Insertable<LocalOrder> custom({
    Expression<String>? orderId,
    Expression<String>? environment,
    Expression<String>? accountId,
    Expression<String>? orderNumber,
    Expression<String>? customerId,
    Expression<String>? customerName,
    Expression<String>? status,
    Expression<String>? currency,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? totalAmountMicros,
    Expression<String>? jsonData,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (orderId != null) 'order_id': orderId,
      if (environment != null) 'environment': environment,
      if (accountId != null) 'account_id': accountId,
      if (orderNumber != null) 'order_number': orderNumber,
      if (customerId != null) 'customer_id': customerId,
      if (customerName != null) 'customer_name': customerName,
      if (status != null) 'status': status,
      if (currency != null) 'currency': currency,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (totalAmountMicros != null) 'total_amount_micros': totalAmountMicros,
      if (jsonData != null) 'json_data': jsonData,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalOrdersCompanion copyWith(
      {Value<String>? orderId,
      Value<String>? environment,
      Value<String>? accountId,
      Value<String>? orderNumber,
      Value<String>? customerId,
      Value<String>? customerName,
      Value<String>? status,
      Value<String>? currency,
      Value<DateTime?>? createdAt,
      Value<DateTime?>? updatedAt,
      Value<int?>? totalAmountMicros,
      Value<String>? jsonData,
      Value<int>? rowid}) {
    return LocalOrdersCompanion(
      orderId: orderId ?? this.orderId,
      environment: environment ?? this.environment,
      accountId: accountId ?? this.accountId,
      orderNumber: orderNumber ?? this.orderNumber,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      status: status ?? this.status,
      currency: currency ?? this.currency,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      totalAmountMicros: totalAmountMicros ?? this.totalAmountMicros,
      jsonData: jsonData ?? this.jsonData,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (orderId.present) {
      map['order_id'] = Variable<String>(orderId.value);
    }
    if (environment.present) {
      map['environment'] = Variable<String>(environment.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (orderNumber.present) {
      map['order_number'] = Variable<String>(orderNumber.value);
    }
    if (customerId.present) {
      map['customer_id'] = Variable<String>(customerId.value);
    }
    if (customerName.present) {
      map['customer_name'] = Variable<String>(customerName.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (totalAmountMicros.present) {
      map['total_amount_micros'] = Variable<int>(totalAmountMicros.value);
    }
    if (jsonData.present) {
      map['json_data'] = Variable<String>(jsonData.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalOrdersCompanion(')
          ..write('orderId: $orderId, ')
          ..write('environment: $environment, ')
          ..write('accountId: $accountId, ')
          ..write('orderNumber: $orderNumber, ')
          ..write('customerId: $customerId, ')
          ..write('customerName: $customerName, ')
          ..write('status: $status, ')
          ..write('currency: $currency, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('totalAmountMicros: $totalAmountMicros, ')
          ..write('jsonData: $jsonData, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalCustomersTable extends LocalCustomers
    with TableInfo<$LocalCustomersTable, LocalCustomer> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalCustomersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _environmentMeta =
      const VerificationMeta('environment');
  @override
  late final GeneratedColumn<String> environment = GeneratedColumn<String>(
      'environment', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _accountIdMeta =
      const VerificationMeta('accountId');
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
      'account_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
      'phone', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
      'email', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _addressMeta =
      const VerificationMeta('address');
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
      'address', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _balanceMicrosMeta =
      const VerificationMeta('balanceMicros');
  @override
  late final GeneratedColumn<int> balanceMicros = GeneratedColumn<int>(
      'balance_micros', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _currencyMeta =
      const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
      'currency', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('USD'));
  static const VerificationMeta _jsonDataMeta =
      const VerificationMeta('jsonData');
  @override
  late final GeneratedColumn<String> jsonData = GeneratedColumn<String>(
      'json_data', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        environment,
        accountId,
        name,
        phone,
        email,
        address,
        category,
        balanceMicros,
        currency,
        jsonData
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_customers';
  @override
  VerificationContext validateIntegrity(Insertable<LocalCustomer> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('environment')) {
      context.handle(
          _environmentMeta,
          environment.isAcceptableOrUnknown(
              data['environment']!, _environmentMeta));
    } else if (isInserting) {
      context.missing(_environmentMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(_accountIdMeta,
          accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta));
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('phone')) {
      context.handle(
          _phoneMeta, phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta));
    }
    if (data.containsKey('email')) {
      context.handle(
          _emailMeta, email.isAcceptableOrUnknown(data['email']!, _emailMeta));
    }
    if (data.containsKey('address')) {
      context.handle(_addressMeta,
          address.isAcceptableOrUnknown(data['address']!, _addressMeta));
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    }
    if (data.containsKey('balance_micros')) {
      context.handle(
          _balanceMicrosMeta,
          balanceMicros.isAcceptableOrUnknown(
              data['balance_micros']!, _balanceMicrosMeta));
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta,
          currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    }
    if (data.containsKey('json_data')) {
      context.handle(_jsonDataMeta,
          jsonData.isAcceptableOrUnknown(data['json_data']!, _jsonDataMeta));
    } else if (isInserting) {
      context.missing(_jsonDataMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id, environment, accountId};
  @override
  LocalCustomer map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalCustomer(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      environment: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}environment'])!,
      accountId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}account_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      phone: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}phone']),
      email: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}email']),
      address: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}address']),
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category']),
      balanceMicros: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}balance_micros'])!,
      currency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
      jsonData: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}json_data'])!,
    );
  }

  @override
  $LocalCustomersTable createAlias(String alias) {
    return $LocalCustomersTable(attachedDatabase, alias);
  }
}

class LocalCustomer extends DataClass implements Insertable<LocalCustomer> {
  final String id;
  final String environment;
  final String accountId;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? category;
  final int balanceMicros;
  final String currency;
  final String jsonData;
  const LocalCustomer(
      {required this.id,
      required this.environment,
      required this.accountId,
      required this.name,
      this.phone,
      this.email,
      this.address,
      this.category,
      required this.balanceMicros,
      required this.currency,
      required this.jsonData});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['environment'] = Variable<String>(environment);
    map['account_id'] = Variable<String>(accountId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    if (!nullToAbsent || address != null) {
      map['address'] = Variable<String>(address);
    }
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    map['balance_micros'] = Variable<int>(balanceMicros);
    map['currency'] = Variable<String>(currency);
    map['json_data'] = Variable<String>(jsonData);
    return map;
  }

  LocalCustomersCompanion toCompanion(bool nullToAbsent) {
    return LocalCustomersCompanion(
      id: Value(id),
      environment: Value(environment),
      accountId: Value(accountId),
      name: Value(name),
      phone:
          phone == null && nullToAbsent ? const Value.absent() : Value(phone),
      email:
          email == null && nullToAbsent ? const Value.absent() : Value(email),
      address: address == null && nullToAbsent
          ? const Value.absent()
          : Value(address),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      balanceMicros: Value(balanceMicros),
      currency: Value(currency),
      jsonData: Value(jsonData),
    );
  }

  factory LocalCustomer.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalCustomer(
      id: serializer.fromJson<String>(json['id']),
      environment: serializer.fromJson<String>(json['environment']),
      accountId: serializer.fromJson<String>(json['accountId']),
      name: serializer.fromJson<String>(json['name']),
      phone: serializer.fromJson<String?>(json['phone']),
      email: serializer.fromJson<String?>(json['email']),
      address: serializer.fromJson<String?>(json['address']),
      category: serializer.fromJson<String?>(json['category']),
      balanceMicros: serializer.fromJson<int>(json['balanceMicros']),
      currency: serializer.fromJson<String>(json['currency']),
      jsonData: serializer.fromJson<String>(json['jsonData']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'environment': serializer.toJson<String>(environment),
      'accountId': serializer.toJson<String>(accountId),
      'name': serializer.toJson<String>(name),
      'phone': serializer.toJson<String?>(phone),
      'email': serializer.toJson<String?>(email),
      'address': serializer.toJson<String?>(address),
      'category': serializer.toJson<String?>(category),
      'balanceMicros': serializer.toJson<int>(balanceMicros),
      'currency': serializer.toJson<String>(currency),
      'jsonData': serializer.toJson<String>(jsonData),
    };
  }

  LocalCustomer copyWith(
          {String? id,
          String? environment,
          String? accountId,
          String? name,
          Value<String?> phone = const Value.absent(),
          Value<String?> email = const Value.absent(),
          Value<String?> address = const Value.absent(),
          Value<String?> category = const Value.absent(),
          int? balanceMicros,
          String? currency,
          String? jsonData}) =>
      LocalCustomer(
        id: id ?? this.id,
        environment: environment ?? this.environment,
        accountId: accountId ?? this.accountId,
        name: name ?? this.name,
        phone: phone.present ? phone.value : this.phone,
        email: email.present ? email.value : this.email,
        address: address.present ? address.value : this.address,
        category: category.present ? category.value : this.category,
        balanceMicros: balanceMicros ?? this.balanceMicros,
        currency: currency ?? this.currency,
        jsonData: jsonData ?? this.jsonData,
      );
  LocalCustomer copyWithCompanion(LocalCustomersCompanion data) {
    return LocalCustomer(
      id: data.id.present ? data.id.value : this.id,
      environment:
          data.environment.present ? data.environment.value : this.environment,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      name: data.name.present ? data.name.value : this.name,
      phone: data.phone.present ? data.phone.value : this.phone,
      email: data.email.present ? data.email.value : this.email,
      address: data.address.present ? data.address.value : this.address,
      category: data.category.present ? data.category.value : this.category,
      balanceMicros: data.balanceMicros.present
          ? data.balanceMicros.value
          : this.balanceMicros,
      currency: data.currency.present ? data.currency.value : this.currency,
      jsonData: data.jsonData.present ? data.jsonData.value : this.jsonData,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalCustomer(')
          ..write('id: $id, ')
          ..write('environment: $environment, ')
          ..write('accountId: $accountId, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('email: $email, ')
          ..write('address: $address, ')
          ..write('category: $category, ')
          ..write('balanceMicros: $balanceMicros, ')
          ..write('currency: $currency, ')
          ..write('jsonData: $jsonData')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, environment, accountId, name, phone,
      email, address, category, balanceMicros, currency, jsonData);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalCustomer &&
          other.id == this.id &&
          other.environment == this.environment &&
          other.accountId == this.accountId &&
          other.name == this.name &&
          other.phone == this.phone &&
          other.email == this.email &&
          other.address == this.address &&
          other.category == this.category &&
          other.balanceMicros == this.balanceMicros &&
          other.currency == this.currency &&
          other.jsonData == this.jsonData);
}

class LocalCustomersCompanion extends UpdateCompanion<LocalCustomer> {
  final Value<String> id;
  final Value<String> environment;
  final Value<String> accountId;
  final Value<String> name;
  final Value<String?> phone;
  final Value<String?> email;
  final Value<String?> address;
  final Value<String?> category;
  final Value<int> balanceMicros;
  final Value<String> currency;
  final Value<String> jsonData;
  final Value<int> rowid;
  const LocalCustomersCompanion({
    this.id = const Value.absent(),
    this.environment = const Value.absent(),
    this.accountId = const Value.absent(),
    this.name = const Value.absent(),
    this.phone = const Value.absent(),
    this.email = const Value.absent(),
    this.address = const Value.absent(),
    this.category = const Value.absent(),
    this.balanceMicros = const Value.absent(),
    this.currency = const Value.absent(),
    this.jsonData = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalCustomersCompanion.insert({
    required String id,
    required String environment,
    required String accountId,
    required String name,
    this.phone = const Value.absent(),
    this.email = const Value.absent(),
    this.address = const Value.absent(),
    this.category = const Value.absent(),
    this.balanceMicros = const Value.absent(),
    this.currency = const Value.absent(),
    required String jsonData,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        environment = Value(environment),
        accountId = Value(accountId),
        name = Value(name),
        jsonData = Value(jsonData);
  static Insertable<LocalCustomer> custom({
    Expression<String>? id,
    Expression<String>? environment,
    Expression<String>? accountId,
    Expression<String>? name,
    Expression<String>? phone,
    Expression<String>? email,
    Expression<String>? address,
    Expression<String>? category,
    Expression<int>? balanceMicros,
    Expression<String>? currency,
    Expression<String>? jsonData,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (environment != null) 'environment': environment,
      if (accountId != null) 'account_id': accountId,
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (address != null) 'address': address,
      if (category != null) 'category': category,
      if (balanceMicros != null) 'balance_micros': balanceMicros,
      if (currency != null) 'currency': currency,
      if (jsonData != null) 'json_data': jsonData,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalCustomersCompanion copyWith(
      {Value<String>? id,
      Value<String>? environment,
      Value<String>? accountId,
      Value<String>? name,
      Value<String?>? phone,
      Value<String?>? email,
      Value<String?>? address,
      Value<String?>? category,
      Value<int>? balanceMicros,
      Value<String>? currency,
      Value<String>? jsonData,
      Value<int>? rowid}) {
    return LocalCustomersCompanion(
      id: id ?? this.id,
      environment: environment ?? this.environment,
      accountId: accountId ?? this.accountId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      category: category ?? this.category,
      balanceMicros: balanceMicros ?? this.balanceMicros,
      currency: currency ?? this.currency,
      jsonData: jsonData ?? this.jsonData,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (environment.present) {
      map['environment'] = Variable<String>(environment.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (balanceMicros.present) {
      map['balance_micros'] = Variable<int>(balanceMicros.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (jsonData.present) {
      map['json_data'] = Variable<String>(jsonData.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalCustomersCompanion(')
          ..write('id: $id, ')
          ..write('environment: $environment, ')
          ..write('accountId: $accountId, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('email: $email, ')
          ..write('address: $address, ')
          ..write('category: $category, ')
          ..write('balanceMicros: $balanceMicros, ')
          ..write('currency: $currency, ')
          ..write('jsonData: $jsonData, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncMetadataTable extends SyncMetadata
    with TableInfo<$SyncMetadataTable, SyncMetadataData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncMetadataTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _environmentMeta =
      const VerificationMeta('environment');
  @override
  late final GeneratedColumn<String> environment = GeneratedColumn<String>(
      'environment', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _accountIdMeta =
      const VerificationMeta('accountId');
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
      'account_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _lastSyncMeta =
      const VerificationMeta('lastSync');
  @override
  late final GeneratedColumn<DateTime> lastSync = GeneratedColumn<DateTime>(
      'last_sync', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, environment, accountId, lastSync];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_metadata';
  @override
  VerificationContext validateIntegrity(Insertable<SyncMetadataData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('environment')) {
      context.handle(
          _environmentMeta,
          environment.isAcceptableOrUnknown(
              data['environment']!, _environmentMeta));
    } else if (isInserting) {
      context.missing(_environmentMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(_accountIdMeta,
          accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta));
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('last_sync')) {
      context.handle(_lastSyncMeta,
          lastSync.isAcceptableOrUnknown(data['last_sync']!, _lastSyncMeta));
    } else if (isInserting) {
      context.missing(_lastSyncMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key, environment, accountId};
  @override
  SyncMetadataData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncMetadataData(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      environment: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}environment'])!,
      accountId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}account_id'])!,
      lastSync: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_sync'])!,
    );
  }

  @override
  $SyncMetadataTable createAlias(String alias) {
    return $SyncMetadataTable(attachedDatabase, alias);
  }
}

class SyncMetadataData extends DataClass
    implements Insertable<SyncMetadataData> {
  final String key;
  final String environment;
  final String accountId;
  final DateTime lastSync;
  const SyncMetadataData(
      {required this.key,
      required this.environment,
      required this.accountId,
      required this.lastSync});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['environment'] = Variable<String>(environment);
    map['account_id'] = Variable<String>(accountId);
    map['last_sync'] = Variable<DateTime>(lastSync);
    return map;
  }

  SyncMetadataCompanion toCompanion(bool nullToAbsent) {
    return SyncMetadataCompanion(
      key: Value(key),
      environment: Value(environment),
      accountId: Value(accountId),
      lastSync: Value(lastSync),
    );
  }

  factory SyncMetadataData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncMetadataData(
      key: serializer.fromJson<String>(json['key']),
      environment: serializer.fromJson<String>(json['environment']),
      accountId: serializer.fromJson<String>(json['accountId']),
      lastSync: serializer.fromJson<DateTime>(json['lastSync']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'environment': serializer.toJson<String>(environment),
      'accountId': serializer.toJson<String>(accountId),
      'lastSync': serializer.toJson<DateTime>(lastSync),
    };
  }

  SyncMetadataData copyWith(
          {String? key,
          String? environment,
          String? accountId,
          DateTime? lastSync}) =>
      SyncMetadataData(
        key: key ?? this.key,
        environment: environment ?? this.environment,
        accountId: accountId ?? this.accountId,
        lastSync: lastSync ?? this.lastSync,
      );
  SyncMetadataData copyWithCompanion(SyncMetadataCompanion data) {
    return SyncMetadataData(
      key: data.key.present ? data.key.value : this.key,
      environment:
          data.environment.present ? data.environment.value : this.environment,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      lastSync: data.lastSync.present ? data.lastSync.value : this.lastSync,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetadataData(')
          ..write('key: $key, ')
          ..write('environment: $environment, ')
          ..write('accountId: $accountId, ')
          ..write('lastSync: $lastSync')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, environment, accountId, lastSync);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncMetadataData &&
          other.key == this.key &&
          other.environment == this.environment &&
          other.accountId == this.accountId &&
          other.lastSync == this.lastSync);
}

class SyncMetadataCompanion extends UpdateCompanion<SyncMetadataData> {
  final Value<String> key;
  final Value<String> environment;
  final Value<String> accountId;
  final Value<DateTime> lastSync;
  final Value<int> rowid;
  const SyncMetadataCompanion({
    this.key = const Value.absent(),
    this.environment = const Value.absent(),
    this.accountId = const Value.absent(),
    this.lastSync = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncMetadataCompanion.insert({
    required String key,
    required String environment,
    required String accountId,
    required DateTime lastSync,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        environment = Value(environment),
        accountId = Value(accountId),
        lastSync = Value(lastSync);
  static Insertable<SyncMetadataData> custom({
    Expression<String>? key,
    Expression<String>? environment,
    Expression<String>? accountId,
    Expression<DateTime>? lastSync,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (environment != null) 'environment': environment,
      if (accountId != null) 'account_id': accountId,
      if (lastSync != null) 'last_sync': lastSync,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncMetadataCompanion copyWith(
      {Value<String>? key,
      Value<String>? environment,
      Value<String>? accountId,
      Value<DateTime>? lastSync,
      Value<int>? rowid}) {
    return SyncMetadataCompanion(
      key: key ?? this.key,
      environment: environment ?? this.environment,
      accountId: accountId ?? this.accountId,
      lastSync: lastSync ?? this.lastSync,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (environment.present) {
      map['environment'] = Variable<String>(environment.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (lastSync.present) {
      map['last_sync'] = Variable<DateTime>(lastSync.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetadataCompanion(')
          ..write('key: $key, ')
          ..write('environment: $environment, ')
          ..write('accountId: $accountId, ')
          ..write('lastSync: $lastSync, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LocalProductsTable localProducts = $LocalProductsTable(this);
  late final $OrderDraftsTable orderDrafts = $OrderDraftsTable(this);
  late final $OrderDraftItemsTable orderDraftItems =
      $OrderDraftItemsTable(this);
  late final $LocalOrdersTable localOrders = $LocalOrdersTable(this);
  late final $LocalCustomersTable localCustomers = $LocalCustomersTable(this);
  late final $SyncMetadataTable syncMetadata = $SyncMetadataTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        localProducts,
        orderDrafts,
        orderDraftItems,
        localOrders,
        localCustomers,
        syncMetadata
      ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules(
        [
          WritePropagation(
            on: TableUpdateQuery.onTableName('order_drafts',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('order_draft_items', kind: UpdateKind.delete),
            ],
          ),
        ],
      );
}

typedef $$LocalProductsTableCreateCompanionBuilder = LocalProductsCompanion
    Function({
  required String environment,
  required String accountId,
  required String code,
  required String name,
  required String category,
  required String unit,
  required int priceMicros,
  required int stockMicros,
  Value<String> currency,
  Value<String?> imageUrl,
  required String jsonData,
  Value<int> rowid,
});
typedef $$LocalProductsTableUpdateCompanionBuilder = LocalProductsCompanion
    Function({
  Value<String> environment,
  Value<String> accountId,
  Value<String> code,
  Value<String> name,
  Value<String> category,
  Value<String> unit,
  Value<int> priceMicros,
  Value<int> stockMicros,
  Value<String> currency,
  Value<String?> imageUrl,
  Value<String> jsonData,
  Value<int> rowid,
});

class $$LocalProductsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalProductsTable> {
  $$LocalProductsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get environment => $composableBuilder(
      column: $table.environment, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get code => $composableBuilder(
      column: $table.code, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get unit => $composableBuilder(
      column: $table.unit, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get priceMicros => $composableBuilder(
      column: $table.priceMicros, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get stockMicros => $composableBuilder(
      column: $table.stockMicros, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get jsonData => $composableBuilder(
      column: $table.jsonData, builder: (column) => ColumnFilters(column));
}

class $$LocalProductsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalProductsTable> {
  $$LocalProductsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get environment => $composableBuilder(
      column: $table.environment, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get code => $composableBuilder(
      column: $table.code, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get unit => $composableBuilder(
      column: $table.unit, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get priceMicros => $composableBuilder(
      column: $table.priceMicros, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get stockMicros => $composableBuilder(
      column: $table.stockMicros, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get jsonData => $composableBuilder(
      column: $table.jsonData, builder: (column) => ColumnOrderings(column));
}

class $$LocalProductsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalProductsTable> {
  $$LocalProductsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get environment => $composableBuilder(
      column: $table.environment, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<int> get priceMicros => $composableBuilder(
      column: $table.priceMicros, builder: (column) => column);

  GeneratedColumn<int> get stockMicros => $composableBuilder(
      column: $table.stockMicros, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<String> get jsonData =>
      $composableBuilder(column: $table.jsonData, builder: (column) => column);
}

class $$LocalProductsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LocalProductsTable,
    LocalProduct,
    $$LocalProductsTableFilterComposer,
    $$LocalProductsTableOrderingComposer,
    $$LocalProductsTableAnnotationComposer,
    $$LocalProductsTableCreateCompanionBuilder,
    $$LocalProductsTableUpdateCompanionBuilder,
    (
      LocalProduct,
      BaseReferences<_$AppDatabase, $LocalProductsTable, LocalProduct>
    ),
    LocalProduct,
    PrefetchHooks Function()> {
  $$LocalProductsTableTableManager(_$AppDatabase db, $LocalProductsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalProductsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalProductsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalProductsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> environment = const Value.absent(),
            Value<String> accountId = const Value.absent(),
            Value<String> code = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> category = const Value.absent(),
            Value<String> unit = const Value.absent(),
            Value<int> priceMicros = const Value.absent(),
            Value<int> stockMicros = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<String?> imageUrl = const Value.absent(),
            Value<String> jsonData = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalProductsCompanion(
            environment: environment,
            accountId: accountId,
            code: code,
            name: name,
            category: category,
            unit: unit,
            priceMicros: priceMicros,
            stockMicros: stockMicros,
            currency: currency,
            imageUrl: imageUrl,
            jsonData: jsonData,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String environment,
            required String accountId,
            required String code,
            required String name,
            required String category,
            required String unit,
            required int priceMicros,
            required int stockMicros,
            Value<String> currency = const Value.absent(),
            Value<String?> imageUrl = const Value.absent(),
            required String jsonData,
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalProductsCompanion.insert(
            environment: environment,
            accountId: accountId,
            code: code,
            name: name,
            category: category,
            unit: unit,
            priceMicros: priceMicros,
            stockMicros: stockMicros,
            currency: currency,
            imageUrl: imageUrl,
            jsonData: jsonData,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$LocalProductsTable, LocalProduct>(table),
                    BaseReferences<_$AppDatabase, $LocalProductsTable,
                        LocalProduct>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalProductsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $LocalProductsTable,
    LocalProduct,
    $$LocalProductsTableFilterComposer,
    $$LocalProductsTableOrderingComposer,
    $$LocalProductsTableAnnotationComposer,
    $$LocalProductsTableCreateCompanionBuilder,
    $$LocalProductsTableUpdateCompanionBuilder,
    (
      LocalProduct,
      BaseReferences<_$AppDatabase, $LocalProductsTable, LocalProduct>
    ),
    LocalProduct,
    PrefetchHooks Function()>;
typedef $$OrderDraftsTableCreateCompanionBuilder = OrderDraftsCompanion
    Function({
  Value<int> id,
  required String environment,
  required String accountId,
  required String customerId,
  required String customerName,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<String?> note,
  Value<String> status,
  Value<String> currency,
  Value<String?> customTitle,
});
typedef $$OrderDraftsTableUpdateCompanionBuilder = OrderDraftsCompanion
    Function({
  Value<int> id,
  Value<String> environment,
  Value<String> accountId,
  Value<String> customerId,
  Value<String> customerName,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<String?> note,
  Value<String> status,
  Value<String> currency,
  Value<String?> customTitle,
});

final class $$OrderDraftsTableReferences
    extends BaseReferences<_$AppDatabase, $OrderDraftsTable, LocalOrderDraft> {
  $$OrderDraftsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$OrderDraftItemsTable, List<LocalOrderItem>>
      _orderDraftItemsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.orderDraftItems,
              aliasName: 'order_drafts__id__order_draft_items__draft_id');

  $$OrderDraftItemsTableProcessedTableManager get orderDraftItemsRefs {
    final manager =
        $$OrderDraftItemsTableTableManager($_db, $_db.orderDraftItems)
            .filter((f) => f.draftId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_orderDraftItemsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$OrderDraftsTableFilterComposer
    extends Composer<_$AppDatabase, $OrderDraftsTable> {
  $$OrderDraftsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get environment => $composableBuilder(
      column: $table.environment, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get customerId => $composableBuilder(
      column: $table.customerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get customerName => $composableBuilder(
      column: $table.customerName, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get customTitle => $composableBuilder(
      column: $table.customTitle, builder: (column) => ColumnFilters(column));

  Expression<bool> orderDraftItemsRefs(
      Expression<bool> Function($$OrderDraftItemsTableFilterComposer f) f) {
    final $$OrderDraftItemsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.orderDraftItems,
        getReferencedColumn: (t) => t.draftId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$OrderDraftItemsTableFilterComposer(
              $db: $db,
              $table: $db.orderDraftItems,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$OrderDraftsTableOrderingComposer
    extends Composer<_$AppDatabase, $OrderDraftsTable> {
  $$OrderDraftsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get environment => $composableBuilder(
      column: $table.environment, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get customerId => $composableBuilder(
      column: $table.customerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get customerName => $composableBuilder(
      column: $table.customerName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get customTitle => $composableBuilder(
      column: $table.customTitle, builder: (column) => ColumnOrderings(column));
}

class $$OrderDraftsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OrderDraftsTable> {
  $$OrderDraftsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get environment => $composableBuilder(
      column: $table.environment, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get customerId => $composableBuilder(
      column: $table.customerId, builder: (column) => column);

  GeneratedColumn<String> get customerName => $composableBuilder(
      column: $table.customerName, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get customTitle => $composableBuilder(
      column: $table.customTitle, builder: (column) => column);

  Expression<T> orderDraftItemsRefs<T extends Object>(
      Expression<T> Function($$OrderDraftItemsTableAnnotationComposer a) f) {
    final $$OrderDraftItemsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.orderDraftItems,
        getReferencedColumn: (t) => t.draftId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$OrderDraftItemsTableAnnotationComposer(
              $db: $db,
              $table: $db.orderDraftItems,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$OrderDraftsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $OrderDraftsTable,
    LocalOrderDraft,
    $$OrderDraftsTableFilterComposer,
    $$OrderDraftsTableOrderingComposer,
    $$OrderDraftsTableAnnotationComposer,
    $$OrderDraftsTableCreateCompanionBuilder,
    $$OrderDraftsTableUpdateCompanionBuilder,
    (LocalOrderDraft, $$OrderDraftsTableReferences),
    LocalOrderDraft,
    PrefetchHooks Function({bool orderDraftItemsRefs})> {
  $$OrderDraftsTableTableManager(_$AppDatabase db, $OrderDraftsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OrderDraftsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OrderDraftsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OrderDraftsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> environment = const Value.absent(),
            Value<String> accountId = const Value.absent(),
            Value<String> customerId = const Value.absent(),
            Value<String> customerName = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<String?> customTitle = const Value.absent(),
          }) =>
              OrderDraftsCompanion(
            id: id,
            environment: environment,
            accountId: accountId,
            customerId: customerId,
            customerName: customerName,
            createdAt: createdAt,
            updatedAt: updatedAt,
            note: note,
            status: status,
            currency: currency,
            customTitle: customTitle,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String environment,
            required String accountId,
            required String customerId,
            required String customerName,
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<String?> customTitle = const Value.absent(),
          }) =>
              OrderDraftsCompanion.insert(
            id: id,
            environment: environment,
            accountId: accountId,
            customerId: customerId,
            customerName: customerName,
            createdAt: createdAt,
            updatedAt: updatedAt,
            note: note,
            status: status,
            currency: currency,
            customTitle: customTitle,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$OrderDraftsTable, LocalOrderDraft>(table),
                    $$OrderDraftsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({orderDraftItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (orderDraftItemsRefs) db.orderDraftItems
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (orderDraftItemsRefs)
                    await $_getPrefetchedData<LocalOrderDraft,
                            $OrderDraftsTable, LocalOrderItem>(
                        currentTable: table,
                        referencedTable: $$OrderDraftsTableReferences
                            ._orderDraftItemsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$OrderDraftsTableReferences(db, table, p0)
                                .orderDraftItemsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.draftId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$OrderDraftsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $OrderDraftsTable,
    LocalOrderDraft,
    $$OrderDraftsTableFilterComposer,
    $$OrderDraftsTableOrderingComposer,
    $$OrderDraftsTableAnnotationComposer,
    $$OrderDraftsTableCreateCompanionBuilder,
    $$OrderDraftsTableUpdateCompanionBuilder,
    (LocalOrderDraft, $$OrderDraftsTableReferences),
    LocalOrderDraft,
    PrefetchHooks Function({bool orderDraftItemsRefs})>;
typedef $$OrderDraftItemsTableCreateCompanionBuilder = OrderDraftItemsCompanion
    Function({
  Value<int> id,
  required int draftId,
  required String productCode,
  required String productName,
  required String unit,
  required int quantityMicros,
  required int priceMicros,
  Value<String?> note,
  Value<String?> productDataJson,
});
typedef $$OrderDraftItemsTableUpdateCompanionBuilder = OrderDraftItemsCompanion
    Function({
  Value<int> id,
  Value<int> draftId,
  Value<String> productCode,
  Value<String> productName,
  Value<String> unit,
  Value<int> quantityMicros,
  Value<int> priceMicros,
  Value<String?> note,
  Value<String?> productDataJson,
});

final class $$OrderDraftItemsTableReferences extends BaseReferences<
    _$AppDatabase, $OrderDraftItemsTable, LocalOrderItem> {
  $$OrderDraftItemsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $OrderDraftsTable _draftIdTable(_$AppDatabase db) => db.orderDrafts
      .createAlias('order_draft_items__draft_id__order_drafts__id');

  $$OrderDraftsTableProcessedTableManager get draftId {
    final $_column = $_itemColumn<int>('draft_id')!;

    final manager = $$OrderDraftsTableTableManager($_db, $_db.orderDrafts)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_draftIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$OrderDraftItemsTableFilterComposer
    extends Composer<_$AppDatabase, $OrderDraftItemsTable> {
  $$OrderDraftItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get productCode => $composableBuilder(
      column: $table.productCode, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get productName => $composableBuilder(
      column: $table.productName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get unit => $composableBuilder(
      column: $table.unit, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get quantityMicros => $composableBuilder(
      column: $table.quantityMicros,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get priceMicros => $composableBuilder(
      column: $table.priceMicros, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get productDataJson => $composableBuilder(
      column: $table.productDataJson,
      builder: (column) => ColumnFilters(column));

  $$OrderDraftsTableFilterComposer get draftId {
    final $$OrderDraftsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.draftId,
        referencedTable: $db.orderDrafts,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$OrderDraftsTableFilterComposer(
              $db: $db,
              $table: $db.orderDrafts,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$OrderDraftItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $OrderDraftItemsTable> {
  $$OrderDraftItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get productCode => $composableBuilder(
      column: $table.productCode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get productName => $composableBuilder(
      column: $table.productName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get unit => $composableBuilder(
      column: $table.unit, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get quantityMicros => $composableBuilder(
      column: $table.quantityMicros,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get priceMicros => $composableBuilder(
      column: $table.priceMicros, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get productDataJson => $composableBuilder(
      column: $table.productDataJson,
      builder: (column) => ColumnOrderings(column));

  $$OrderDraftsTableOrderingComposer get draftId {
    final $$OrderDraftsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.draftId,
        referencedTable: $db.orderDrafts,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$OrderDraftsTableOrderingComposer(
              $db: $db,
              $table: $db.orderDrafts,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$OrderDraftItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OrderDraftItemsTable> {
  $$OrderDraftItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get productCode => $composableBuilder(
      column: $table.productCode, builder: (column) => column);

  GeneratedColumn<String> get productName => $composableBuilder(
      column: $table.productName, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<int> get quantityMicros => $composableBuilder(
      column: $table.quantityMicros, builder: (column) => column);

  GeneratedColumn<int> get priceMicros => $composableBuilder(
      column: $table.priceMicros, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get productDataJson => $composableBuilder(
      column: $table.productDataJson, builder: (column) => column);

  $$OrderDraftsTableAnnotationComposer get draftId {
    final $$OrderDraftsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.draftId,
        referencedTable: $db.orderDrafts,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$OrderDraftsTableAnnotationComposer(
              $db: $db,
              $table: $db.orderDrafts,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$OrderDraftItemsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $OrderDraftItemsTable,
    LocalOrderItem,
    $$OrderDraftItemsTableFilterComposer,
    $$OrderDraftItemsTableOrderingComposer,
    $$OrderDraftItemsTableAnnotationComposer,
    $$OrderDraftItemsTableCreateCompanionBuilder,
    $$OrderDraftItemsTableUpdateCompanionBuilder,
    (LocalOrderItem, $$OrderDraftItemsTableReferences),
    LocalOrderItem,
    PrefetchHooks Function({bool draftId})> {
  $$OrderDraftItemsTableTableManager(
      _$AppDatabase db, $OrderDraftItemsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OrderDraftItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OrderDraftItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OrderDraftItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> draftId = const Value.absent(),
            Value<String> productCode = const Value.absent(),
            Value<String> productName = const Value.absent(),
            Value<String> unit = const Value.absent(),
            Value<int> quantityMicros = const Value.absent(),
            Value<int> priceMicros = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<String?> productDataJson = const Value.absent(),
          }) =>
              OrderDraftItemsCompanion(
            id: id,
            draftId: draftId,
            productCode: productCode,
            productName: productName,
            unit: unit,
            quantityMicros: quantityMicros,
            priceMicros: priceMicros,
            note: note,
            productDataJson: productDataJson,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int draftId,
            required String productCode,
            required String productName,
            required String unit,
            required int quantityMicros,
            required int priceMicros,
            Value<String?> note = const Value.absent(),
            Value<String?> productDataJson = const Value.absent(),
          }) =>
              OrderDraftItemsCompanion.insert(
            id: id,
            draftId: draftId,
            productCode: productCode,
            productName: productName,
            unit: unit,
            quantityMicros: quantityMicros,
            priceMicros: priceMicros,
            note: note,
            productDataJson: productDataJson,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$OrderDraftItemsTable, LocalOrderItem>(table),
                    $$OrderDraftItemsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({draftId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (draftId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.draftId,
                    referencedTable:
                        $$OrderDraftItemsTableReferences._draftIdTable(db),
                    referencedColumn:
                        $$OrderDraftItemsTableReferences._draftIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$OrderDraftItemsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $OrderDraftItemsTable,
    LocalOrderItem,
    $$OrderDraftItemsTableFilterComposer,
    $$OrderDraftItemsTableOrderingComposer,
    $$OrderDraftItemsTableAnnotationComposer,
    $$OrderDraftItemsTableCreateCompanionBuilder,
    $$OrderDraftItemsTableUpdateCompanionBuilder,
    (LocalOrderItem, $$OrderDraftItemsTableReferences),
    LocalOrderItem,
    PrefetchHooks Function({bool draftId})>;
typedef $$LocalOrdersTableCreateCompanionBuilder = LocalOrdersCompanion
    Function({
  required String orderId,
  required String environment,
  required String accountId,
  required String orderNumber,
  required String customerId,
  required String customerName,
  required String status,
  required String currency,
  Value<DateTime?> createdAt,
  Value<DateTime?> updatedAt,
  Value<int?> totalAmountMicros,
  required String jsonData,
  Value<int> rowid,
});
typedef $$LocalOrdersTableUpdateCompanionBuilder = LocalOrdersCompanion
    Function({
  Value<String> orderId,
  Value<String> environment,
  Value<String> accountId,
  Value<String> orderNumber,
  Value<String> customerId,
  Value<String> customerName,
  Value<String> status,
  Value<String> currency,
  Value<DateTime?> createdAt,
  Value<DateTime?> updatedAt,
  Value<int?> totalAmountMicros,
  Value<String> jsonData,
  Value<int> rowid,
});

class $$LocalOrdersTableFilterComposer
    extends Composer<_$AppDatabase, $LocalOrdersTable> {
  $$LocalOrdersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get orderId => $composableBuilder(
      column: $table.orderId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get environment => $composableBuilder(
      column: $table.environment, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get orderNumber => $composableBuilder(
      column: $table.orderNumber, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get customerId => $composableBuilder(
      column: $table.customerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get customerName => $composableBuilder(
      column: $table.customerName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get totalAmountMicros => $composableBuilder(
      column: $table.totalAmountMicros,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get jsonData => $composableBuilder(
      column: $table.jsonData, builder: (column) => ColumnFilters(column));
}

class $$LocalOrdersTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalOrdersTable> {
  $$LocalOrdersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get orderId => $composableBuilder(
      column: $table.orderId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get environment => $composableBuilder(
      column: $table.environment, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get orderNumber => $composableBuilder(
      column: $table.orderNumber, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get customerId => $composableBuilder(
      column: $table.customerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get customerName => $composableBuilder(
      column: $table.customerName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get totalAmountMicros => $composableBuilder(
      column: $table.totalAmountMicros,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get jsonData => $composableBuilder(
      column: $table.jsonData, builder: (column) => ColumnOrderings(column));
}

class $$LocalOrdersTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalOrdersTable> {
  $$LocalOrdersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get orderId =>
      $composableBuilder(column: $table.orderId, builder: (column) => column);

  GeneratedColumn<String> get environment => $composableBuilder(
      column: $table.environment, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get orderNumber => $composableBuilder(
      column: $table.orderNumber, builder: (column) => column);

  GeneratedColumn<String> get customerId => $composableBuilder(
      column: $table.customerId, builder: (column) => column);

  GeneratedColumn<String> get customerName => $composableBuilder(
      column: $table.customerName, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get totalAmountMicros => $composableBuilder(
      column: $table.totalAmountMicros, builder: (column) => column);

  GeneratedColumn<String> get jsonData =>
      $composableBuilder(column: $table.jsonData, builder: (column) => column);
}

class $$LocalOrdersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LocalOrdersTable,
    LocalOrder,
    $$LocalOrdersTableFilterComposer,
    $$LocalOrdersTableOrderingComposer,
    $$LocalOrdersTableAnnotationComposer,
    $$LocalOrdersTableCreateCompanionBuilder,
    $$LocalOrdersTableUpdateCompanionBuilder,
    (LocalOrder, BaseReferences<_$AppDatabase, $LocalOrdersTable, LocalOrder>),
    LocalOrder,
    PrefetchHooks Function()> {
  $$LocalOrdersTableTableManager(_$AppDatabase db, $LocalOrdersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalOrdersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalOrdersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalOrdersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> orderId = const Value.absent(),
            Value<String> environment = const Value.absent(),
            Value<String> accountId = const Value.absent(),
            Value<String> orderNumber = const Value.absent(),
            Value<String> customerId = const Value.absent(),
            Value<String> customerName = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
            Value<int?> totalAmountMicros = const Value.absent(),
            Value<String> jsonData = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalOrdersCompanion(
            orderId: orderId,
            environment: environment,
            accountId: accountId,
            orderNumber: orderNumber,
            customerId: customerId,
            customerName: customerName,
            status: status,
            currency: currency,
            createdAt: createdAt,
            updatedAt: updatedAt,
            totalAmountMicros: totalAmountMicros,
            jsonData: jsonData,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String orderId,
            required String environment,
            required String accountId,
            required String orderNumber,
            required String customerId,
            required String customerName,
            required String status,
            required String currency,
            Value<DateTime?> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
            Value<int?> totalAmountMicros = const Value.absent(),
            required String jsonData,
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalOrdersCompanion.insert(
            orderId: orderId,
            environment: environment,
            accountId: accountId,
            orderNumber: orderNumber,
            customerId: customerId,
            customerName: customerName,
            status: status,
            currency: currency,
            createdAt: createdAt,
            updatedAt: updatedAt,
            totalAmountMicros: totalAmountMicros,
            jsonData: jsonData,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$LocalOrdersTable, LocalOrder>(table),
                    BaseReferences<_$AppDatabase, $LocalOrdersTable,
                        LocalOrder>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalOrdersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $LocalOrdersTable,
    LocalOrder,
    $$LocalOrdersTableFilterComposer,
    $$LocalOrdersTableOrderingComposer,
    $$LocalOrdersTableAnnotationComposer,
    $$LocalOrdersTableCreateCompanionBuilder,
    $$LocalOrdersTableUpdateCompanionBuilder,
    (LocalOrder, BaseReferences<_$AppDatabase, $LocalOrdersTable, LocalOrder>),
    LocalOrder,
    PrefetchHooks Function()>;
typedef $$LocalCustomersTableCreateCompanionBuilder = LocalCustomersCompanion
    Function({
  required String id,
  required String environment,
  required String accountId,
  required String name,
  Value<String?> phone,
  Value<String?> email,
  Value<String?> address,
  Value<String?> category,
  Value<int> balanceMicros,
  Value<String> currency,
  required String jsonData,
  Value<int> rowid,
});
typedef $$LocalCustomersTableUpdateCompanionBuilder = LocalCustomersCompanion
    Function({
  Value<String> id,
  Value<String> environment,
  Value<String> accountId,
  Value<String> name,
  Value<String?> phone,
  Value<String?> email,
  Value<String?> address,
  Value<String?> category,
  Value<int> balanceMicros,
  Value<String> currency,
  Value<String> jsonData,
  Value<int> rowid,
});

class $$LocalCustomersTableFilterComposer
    extends Composer<_$AppDatabase, $LocalCustomersTable> {
  $$LocalCustomersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get environment => $composableBuilder(
      column: $table.environment, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get phone => $composableBuilder(
      column: $table.phone, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get address => $composableBuilder(
      column: $table.address, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get balanceMicros => $composableBuilder(
      column: $table.balanceMicros, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get jsonData => $composableBuilder(
      column: $table.jsonData, builder: (column) => ColumnFilters(column));
}

class $$LocalCustomersTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalCustomersTable> {
  $$LocalCustomersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get environment => $composableBuilder(
      column: $table.environment, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get phone => $composableBuilder(
      column: $table.phone, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get address => $composableBuilder(
      column: $table.address, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get balanceMicros => $composableBuilder(
      column: $table.balanceMicros,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get jsonData => $composableBuilder(
      column: $table.jsonData, builder: (column) => ColumnOrderings(column));
}

class $$LocalCustomersTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalCustomersTable> {
  $$LocalCustomersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get environment => $composableBuilder(
      column: $table.environment, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<int> get balanceMicros => $composableBuilder(
      column: $table.balanceMicros, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get jsonData =>
      $composableBuilder(column: $table.jsonData, builder: (column) => column);
}

class $$LocalCustomersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LocalCustomersTable,
    LocalCustomer,
    $$LocalCustomersTableFilterComposer,
    $$LocalCustomersTableOrderingComposer,
    $$LocalCustomersTableAnnotationComposer,
    $$LocalCustomersTableCreateCompanionBuilder,
    $$LocalCustomersTableUpdateCompanionBuilder,
    (
      LocalCustomer,
      BaseReferences<_$AppDatabase, $LocalCustomersTable, LocalCustomer>
    ),
    LocalCustomer,
    PrefetchHooks Function()> {
  $$LocalCustomersTableTableManager(
      _$AppDatabase db, $LocalCustomersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalCustomersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalCustomersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalCustomersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> environment = const Value.absent(),
            Value<String> accountId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> phone = const Value.absent(),
            Value<String?> email = const Value.absent(),
            Value<String?> address = const Value.absent(),
            Value<String?> category = const Value.absent(),
            Value<int> balanceMicros = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<String> jsonData = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalCustomersCompanion(
            id: id,
            environment: environment,
            accountId: accountId,
            name: name,
            phone: phone,
            email: email,
            address: address,
            category: category,
            balanceMicros: balanceMicros,
            currency: currency,
            jsonData: jsonData,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String environment,
            required String accountId,
            required String name,
            Value<String?> phone = const Value.absent(),
            Value<String?> email = const Value.absent(),
            Value<String?> address = const Value.absent(),
            Value<String?> category = const Value.absent(),
            Value<int> balanceMicros = const Value.absent(),
            Value<String> currency = const Value.absent(),
            required String jsonData,
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalCustomersCompanion.insert(
            id: id,
            environment: environment,
            accountId: accountId,
            name: name,
            phone: phone,
            email: email,
            address: address,
            category: category,
            balanceMicros: balanceMicros,
            currency: currency,
            jsonData: jsonData,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$LocalCustomersTable, LocalCustomer>(table),
                    BaseReferences<_$AppDatabase, $LocalCustomersTable,
                        LocalCustomer>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalCustomersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $LocalCustomersTable,
    LocalCustomer,
    $$LocalCustomersTableFilterComposer,
    $$LocalCustomersTableOrderingComposer,
    $$LocalCustomersTableAnnotationComposer,
    $$LocalCustomersTableCreateCompanionBuilder,
    $$LocalCustomersTableUpdateCompanionBuilder,
    (
      LocalCustomer,
      BaseReferences<_$AppDatabase, $LocalCustomersTable, LocalCustomer>
    ),
    LocalCustomer,
    PrefetchHooks Function()>;
typedef $$SyncMetadataTableCreateCompanionBuilder = SyncMetadataCompanion
    Function({
  required String key,
  required String environment,
  required String accountId,
  required DateTime lastSync,
  Value<int> rowid,
});
typedef $$SyncMetadataTableUpdateCompanionBuilder = SyncMetadataCompanion
    Function({
  Value<String> key,
  Value<String> environment,
  Value<String> accountId,
  Value<DateTime> lastSync,
  Value<int> rowid,
});

class $$SyncMetadataTableFilterComposer
    extends Composer<_$AppDatabase, $SyncMetadataTable> {
  $$SyncMetadataTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get environment => $composableBuilder(
      column: $table.environment, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastSync => $composableBuilder(
      column: $table.lastSync, builder: (column) => ColumnFilters(column));
}

class $$SyncMetadataTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncMetadataTable> {
  $$SyncMetadataTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get environment => $composableBuilder(
      column: $table.environment, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastSync => $composableBuilder(
      column: $table.lastSync, builder: (column) => ColumnOrderings(column));
}

class $$SyncMetadataTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncMetadataTable> {
  $$SyncMetadataTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get environment => $composableBuilder(
      column: $table.environment, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSync =>
      $composableBuilder(column: $table.lastSync, builder: (column) => column);
}

class $$SyncMetadataTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SyncMetadataTable,
    SyncMetadataData,
    $$SyncMetadataTableFilterComposer,
    $$SyncMetadataTableOrderingComposer,
    $$SyncMetadataTableAnnotationComposer,
    $$SyncMetadataTableCreateCompanionBuilder,
    $$SyncMetadataTableUpdateCompanionBuilder,
    (
      SyncMetadataData,
      BaseReferences<_$AppDatabase, $SyncMetadataTable, SyncMetadataData>
    ),
    SyncMetadataData,
    PrefetchHooks Function()> {
  $$SyncMetadataTableTableManager(_$AppDatabase db, $SyncMetadataTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncMetadataTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncMetadataTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncMetadataTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> environment = const Value.absent(),
            Value<String> accountId = const Value.absent(),
            Value<DateTime> lastSync = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncMetadataCompanion(
            key: key,
            environment: environment,
            accountId: accountId,
            lastSync: lastSync,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String environment,
            required String accountId,
            required DateTime lastSync,
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncMetadataCompanion.insert(
            key: key,
            environment: environment,
            accountId: accountId,
            lastSync: lastSync,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$SyncMetadataTable, SyncMetadataData>(table),
                    BaseReferences<_$AppDatabase, $SyncMetadataTable,
                        SyncMetadataData>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SyncMetadataTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SyncMetadataTable,
    SyncMetadataData,
    $$SyncMetadataTableFilterComposer,
    $$SyncMetadataTableOrderingComposer,
    $$SyncMetadataTableAnnotationComposer,
    $$SyncMetadataTableCreateCompanionBuilder,
    $$SyncMetadataTableUpdateCompanionBuilder,
    (
      SyncMetadataData,
      BaseReferences<_$AppDatabase, $SyncMetadataTable, SyncMetadataData>
    ),
    SyncMetadataData,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LocalProductsTableTableManager get localProducts =>
      $$LocalProductsTableTableManager(_db, _db.localProducts);
  $$OrderDraftsTableTableManager get orderDrafts =>
      $$OrderDraftsTableTableManager(_db, _db.orderDrafts);
  $$OrderDraftItemsTableTableManager get orderDraftItems =>
      $$OrderDraftItemsTableTableManager(_db, _db.orderDraftItems);
  $$LocalOrdersTableTableManager get localOrders =>
      $$LocalOrdersTableTableManager(_db, _db.localOrders);
  $$LocalCustomersTableTableManager get localCustomers =>
      $$LocalCustomersTableTableManager(_db, _db.localCustomers);
  $$SyncMetadataTableTableManager get syncMetadata =>
      $$SyncMetadataTableTableManager(_db, _db.syncMetadata);
}
