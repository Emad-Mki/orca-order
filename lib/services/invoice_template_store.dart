import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../app_config.dart';

const _columns = <String>[
  'index',
  'image',
  'name',
  'quantity',
  'unit',
  'price',
  'total',
  'note',
];
const _maxLogoBytes = 1024 * 1024;
const _maxCacheBytes = 2 * 1024 * 1024;

/// A validated, immutable invoice configuration.
class InvoiceTemplate {
  InvoiceTemplate._(this._config, this._logoBytes);

  final Map<String, dynamic> _config;
  final Uint8List? _logoBytes;

  String get version => _config['version'] as String;
  String get companyName => _config['company_name'] as String;
  String get companyDetails => _config['company_details'] as String;
  String get footer => _config['footer'] as String;
  String get primaryColor => _config['primary_color'] as String;
  num get fontSize => _config['font_size'] as num;
  num get margin => _config['margin'] as num;
  List<String> get columns => _config['columns'] as List<String>;
  Map<String, num> get columnWidths =>
      _config['column_widths'] as Map<String, num>;
  bool get showImages => _config['show_images'] as bool;
  bool get showNotes => _config['show_notes'] as bool;
  Uint8List? get logoBytes =>
      _logoBytes == null ? null : Uint8List.fromList(_logoBytes);

  /// Returns a detached JSON-compatible copy, including a custom logo if present.
  Map<String, dynamic> toMap() => {
        ..._config,
        'columns': List<String>.from(columns),
        'column_widths': Map<String, num>.from(columnWidths),
      };
}

/// Independent private cache. The caller supplies session-scoped fetching.
class InvoiceTemplateStore {
  InvoiceTemplateStore({
    required Future<Map<String, dynamic>> Function() fetch,
    required String scope,
    Future<Directory> Function()? directoryProvider,
    bool Function()? isActive,
  })  : _fetch = fetch,
        _scope = scope,
        _directoryProvider =
            directoryProvider ?? getApplicationSupportDirectory,
        _isActive = isActive ?? _alwaysActive;

  final Future<Map<String, dynamic>> Function() _fetch;
  final String _scope;
  final Future<Directory> Function() _directoryProvider;
  final bool Function() _isActive;
  Future<void>? _refreshing;
  static int _temporarySequence = 0;
  static final Map<String, Future<void>> _commits = {};

  static bool _alwaysActive() => true;

  Future<File> _cacheFile() async {
    final directory = await _directoryProvider();
    final key = sha256.convert(utf8.encode(_scope)).toString();
    return File(path.join(directory.path, 'invoice_template_$key.json'));
  }

  /// Returns the last valid cached template, or built-in defaults.
  Future<InvoiceTemplate> current() async {
    try {
      final file = await _cacheFile();
      if (await file.exists() && await file.length() <= _maxCacheBytes) {
        final decoded = jsonDecode(await file.readAsString());
        return await _parse(decoded);
      }
    } catch (error) {
      debugPrint('Invoice template cache read failed: ${error.runtimeType}');
    }
    return _parse(_defaults);
  }

  /// Fetches, validates and atomically replaces the last known good template.
  Future<void> refresh() {
    final running = _refreshing;
    if (running != null) return running;
    final future = _refresh();
    _refreshing = future;
    return future.whenComplete(() {
      if (identical(_refreshing, future)) _refreshing = null;
    });
  }

  Future<void> _refresh() async {
    final response = await _fetch();
    if (!_isActive()) return;
    if (response['ok'] == false || response['success'] == false) {
      throw const FormatException('Invoice template request failed');
    }
    final data = response['data'];
    final raw = response['template'] ?? (data is Map ? data['template'] : null);
    final template = await _parse(raw);
    if (!_isActive()) return;
    final contents = jsonEncode(template.toMap());
    if (utf8.encode(contents).length > _maxCacheBytes) {
      throw const FormatException('Invoice template too large');
    }
    final file = await _cacheFile();
    final previous = _commits[file.path];
    final done = Completer<void>();
    _commits[file.path] = done.future;
    try {
      if (previous != null) await previous;
      if (!_isActive()) return;
      await file.parent.create(recursive: true);
      final temporary = File(
          '${file.path}.$pid.${DateTime.now().microsecondsSinceEpoch}.${_temporarySequence++}.tmp');
      try {
        await temporary.writeAsString(contents, flush: true);
        if (!_isActive()) return;
        await temporary.rename(file.path);
      } finally {
        if (await temporary.exists()) await temporary.delete();
      }
    } finally {
      done.complete();
      if (identical(_commits[file.path], done.future)) {
        _commits.remove(file.path);
      }
    }
  }
}

const _defaults = <String, dynamic>{
  'version': 'builtin-1',
  'company_name': AppConfig.companyName,
  'company_details': '',
  'footer': '',
  'primary_color': '#00658F',
  'font_size': 9,
  'margin': 28,
  'columns': _columns,
  'column_widths': <String, num>{
    'index': .5,
    'image': 1,
    'name': 2.5,
    'quantity': .8,
    'unit': .8,
    'price': 1.2,
    'total': 1.2,
    'note': 1.2,
  },
  'show_images': true,
  'show_notes': true,
};

Future<InvoiceTemplate> _parse(dynamic input) async {
  if (input is! Map) throw const FormatException('Invalid invoice template');
  final version = input['version'];
  if (version is! String ||
      !RegExp(r'^[A-Za-z0-9._-]{1,40}$').hasMatch(version)) {
    throw const FormatException('Invalid invoice template version');
  }
  for (final field in ['company_name', 'company_details', 'footer']) {
    if (input[field] is! String) throw FormatException('Invalid $field');
  }
  final controls = RegExp(r'[\x00-\x1f\x7f-\x9f\u2028\u2029]');
  final multilineControls = RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]');
  if (controls.hasMatch(input['company_name'] as String) ||
      (input['company_name'] as String).length > 200 ||
      controls.hasMatch(input['footer'] as String) ||
      (input['footer'] as String).length > 120 ||
      multilineControls.hasMatch(input['company_details'] as String) ||
      (input['company_details'] as String).length > 2000) {
    throw const FormatException('Invalid invoice template text');
  }
  final color = input['primary_color'];
  if (color is! String || !RegExp(r'^#[A-Fa-f0-9]{6}$').hasMatch(color)) {
    throw const FormatException('Invalid primary_color');
  }
  void checkNumber(String field, num min, num max) {
    final value = input[field];
    if (value is! num || !value.isFinite || value < min || value > max) {
      throw FormatException('Invalid $field');
    }
  }

  checkNumber('font_size', 8, 14);
  checkNumber('margin', 20, 50);
  final columns = input['columns'];
  if (columns is! List ||
      columns.length != _columns.length ||
      columns.any((value) => value is! String || !_columns.contains(value)) ||
      columns.toSet().length != _columns.length) {
    throw const FormatException('Invalid columns');
  }
  final widths = input['column_widths'];
  if (widths is! Map ||
      widths.length != _columns.length ||
      !_columns.every((key) {
        final value = widths[key];
        return value is num && value.isFinite && value >= .4 && value <= 4;
      })) {
    throw const FormatException('Invalid column_widths');
  }
  if (input['show_images'] is! bool || input['show_notes'] is! bool) {
    throw const FormatException('Invalid invoice visibility');
  }
  final visible = _columns.where((column) =>
      (column != 'image' || input['show_images'] == true) &&
      (column != 'note' || input['show_notes'] == true));
  final totalWidth = visible.fold<double>(
      0, (sum, column) => sum + (widths[column] as num).toDouble());
  final availableWidth = 595.2756 - 2 * (input['margin'] as num);
  if (visible.any((column) =>
      availableWidth * (widths[column] as num) / totalWidth < 28 - 1e-9)) {
    throw const FormatException('Invoice column is too narrow');
  }
  Uint8List? bytes;
  final logo = input['logo_base64'];
  if (input.containsKey('logo_base64')) {
    if (logo is! String || logo.length > ((_maxLogoBytes + 2) ~/ 3) * 4) {
      throw const FormatException('Invalid invoice logo');
    }
    try {
      bytes = base64Decode(logo);
      if (bytes.length > _maxLogoBytes || !_hasImageSignature(bytes)) {
        throw const FormatException('Invalid invoice logo');
      }
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      try {
        final descriptor = await ui.ImageDescriptor.encoded(buffer);
        try {
          if (descriptor.width <= 0 ||
              descriptor.height <= 0 ||
              descriptor.width > 4096 ||
              descriptor.height > 4096 ||
              descriptor.width * descriptor.height > 16000000) {
            throw const FormatException('Invoice logo dimensions too large');
          }
          final codec = await descriptor.instantiateCodec();
          try {
            final frame = await codec.getNextFrame();
            frame.image.dispose();
          } finally {
            codec.dispose();
          }
        } finally {
          descriptor.dispose();
        }
      } finally {
        buffer.dispose();
      }
    } catch (_) {
      throw const FormatException('Invalid invoice logo');
    }
  } else {
    try {
      final asset = await rootBundle.load('assets/images/logo.png');
      bytes =
          asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes);
    } catch (error) {
      debugPrint(
          'Invoice template asset logo unavailable: ${error.runtimeType}');
    }
  }
  final config = <String, dynamic>{
    'version': version,
    'company_name': input['company_name'],
    'company_details': input['company_details'],
    'footer': input['footer'],
    'primary_color': color,
    'font_size': input['font_size'],
    'margin': input['margin'],
    'columns': List<String>.unmodifiable(columns.cast<String>()),
    'column_widths': Map<String, num>.unmodifiable({
      for (final key in _columns) key: widths[key] as num,
    }),
    'show_images': input['show_images'],
    'show_notes': input['show_notes'],
    if (logo != null) 'logo_base64': logo,
  };
  return InvoiceTemplate._(Map.unmodifiable(config), bytes);
}

bool _hasImageSignature(Uint8List bytes) {
  const png = <int>[137, 80, 78, 71, 13, 10, 26, 10];
  if (bytes.length >= png.length &&
      List.generate(png.length, (i) => i).every((i) => bytes[i] == png[i])) {
    return true;
  }
  return bytes.length >= 4 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff &&
      bytes[bytes.length - 2] == 0xff &&
      bytes.last == 0xd9;
}
