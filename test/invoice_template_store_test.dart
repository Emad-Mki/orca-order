import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orca_order/services/invoice_template_store.dart';
import 'package:path/path.dart' as path;

Map<String, dynamic> validTemplate() => {
      'version': 'v1.2-test',
      'company_name': 'Company',
      'company_details': 'Details',
      'footer': 'Footer',
      'primary_color': '#A1b2C3',
      'font_size': 8,
      'margin': 50,
      'columns': [
        'index',
        'image',
        'name',
        'quantity',
        'unit',
        'price',
        'total',
        'note',
      ],
      'column_widths': {
        'index': .8,
        'image': 1,
        'name': 4,
        'quantity': 1,
        'unit': 1,
        'price': 1,
        'total': 1,
        'note': 1,
      },
      'show_images': true,
      'show_notes': false,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;

  setUp(() async {
    directory = Directory(path.join('build', 'invoice_template_tests',
        DateTime.now().microsecondsSinceEpoch.toString()));
    await directory.create(recursive: true);
  });
  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  InvoiceTemplateStore store(
    Future<Map<String, dynamic>> Function() fetch, {
    String scope = 'test-account',
    bool Function()? isActive,
  }) =>
      InvoiceTemplateStore(
        fetch: fetch,
        scope: scope,
        directoryProvider: () async => directory,
        isActive: isActive,
      );

  test('defaults and persisted cache use the bundled logo', () async {
    var fetched = false;
    final first = store(() async {
      fetched = true;
      return {'template': validTemplate()};
    });
    final defaults = await first.current();
    expect(fetched, isFalse);
    expect(defaults.version, 'orca-invoice-a4-v1');
    expect(defaults.logoBytes, isNotEmpty);
    await first.refresh();
    final reloaded =
        await store(() async => throw StateError('offline')).current();
    expect(reloaded.version, 'v1.2-test');
    expect(reloaded.companyName, 'Company');
    expect(reloaded.primaryColor, '#A1b2C3');
    expect(reloaded.columnWidths['index'], .8);
    expect(reloaded.logoBytes, isNotEmpty);
    expect(reloaded.toMap().containsKey('logo_base64'), isFalse);
    expect(() => reloaded.columns.add('extra'), throwsUnsupportedError);
  });

  test('valid custom PNG is persisted and logo bytes are defensive copies',
      () async {
    final asset = await rootBundle.load('assets/images/logo.png');
    final bytes =
        asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes);
    final template = validTemplate()..['logo_base64'] = base64Encode(bytes);
    final cache = store(() async => {'template': template});
    await cache.refresh();
    final result = await cache.current();
    final logo = result.logoBytes!;
    expect(logo, orderedEquals(bytes));
    logo[0] = 0;
    expect(result.logoBytes![0], bytes[0]);
  });

  test('valid JPEG replaces an existing cached template', () async {
    const jpeg =
        '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAARCAABAAEDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwDi6KKK+ZP3E//Z';
    var template = validTemplate();
    final cache = store(() async => {'template': template});
    await cache.refresh();
    template = validTemplate()
      ..['version'] = 'v2'
      ..['logo_base64'] = jpeg;
    await cache.refresh();
    final loaded = await cache.current();
    expect(loaded.version, 'v2');
    expect(loaded.logoBytes, orderedEquals(base64Decode(jpeg)));
    expect(directory.listSync().whereType<File>().length, 1);
  });

  test('invalid response never replaces last good cache', () async {
    Map<String, dynamic> response = {'template': validTemplate()};
    final cache = store(() async => response);
    await cache.refresh();
    final invalids = <Map<String, dynamic> Function()>[
      () => validTemplate()..['version'] = '',
      () => validTemplate()..['version'] = 'bad version',
      () => validTemplate()..['version'] = 'bad\n',
      () => validTemplate()..['version'] = 'x' * 41,
      () => validTemplate()..['company_name'] = 1,
      () => validTemplate()..['company_name'] = 'x' * 201,
      () => validTemplate()..['company_name'] = 'Company\nName',
      () => validTemplate()..['company_name'] = 'Company\tName',
      () => validTemplate()..['company_name'] = 'Company\u0085Name',
      () => validTemplate()..['company_details'] = null,
      () => validTemplate()..['company_details'] = 'x' * 2001,
      () => validTemplate()..['company_details'] = 'a\u0000b',
      () => validTemplate()..['company_details'] = 'a\u000bb',
      () => validTemplate()..['company_details'] = 'a\u000cb',
      () => validTemplate()..['company_details'] = 'a\u001fb',
      () => validTemplate()..['company_details'] = 'a\u007fb',
      () => validTemplate()..['footer'] = false,
      () => validTemplate()..['footer'] = 'x' * 121,
      () => validTemplate()..['footer'] = 'footer\ntext',
      () => validTemplate()..['footer'] = 'footer\ttext',
      () => validTemplate()..['footer'] = 'footer\u2028text',
      () => validTemplate()..['primary_color'] = '#ffff',
      () => validTemplate()..['font_size'] = 7.99,
      () => validTemplate()..['font_size'] = double.nan,
      () => validTemplate()..['margin'] = 50.1,
      () => validTemplate()..['columns'] = List.filled(8, 'name'),
      () => validTemplate()..['columns'] = ['name'],
      () => validTemplate()..['column_widths'] = {'name': 1},
      () => validTemplate()..['column_widths']['index'] = .39,
      () => validTemplate()..['column_widths']['index'] = double.infinity,
      () => validTemplate()..['show_images'] = 1,
      () => validTemplate()..['show_notes'] = null,
      () => validTemplate()..['logo_base64'] = null,
      () => validTemplate()..['logo_base64'] = 'not base64!',
      () => validTemplate()
        ..['logo_base64'] = base64Encode([137, 80, 78, 71, 13, 10, 26, 10]),
      () => validTemplate()
        ..['logo_base64'] = base64Encode(List.filled(1048577, 0)),
    ];
    for (final makeInvalid in invalids) {
      response = {'template': makeInvalid()};
      await expectLater(cache.refresh(), throwsFormatException);
      expect((await cache.current()).version, 'v1.2-test');
    }
    response = {'ok': false, 'template': validTemplate()};
    await expectLater(cache.refresh(), throwsFormatException);
    response = {};
    await expectLater(cache.refresh(), throwsFormatException);
    expect((await cache.current()).version, 'v1.2-test');
  });

  test('offline, corrupt cache, isolation and inactive refresh', () async {
    final a = store(() async => {'template': validTemplate()}, scope: 'a');
    await a.refresh();
    final b = store(() async => throw StateError('offline'), scope: 'b');
    expect((await b.current()).version, 'orca-invoice-a4-v1');
    await expectLater(b.refresh(), throwsStateError);
    expect((await a.current()).version, 'v1.2-test');
    final file = directory.listSync().whereType<File>().single;
    await file.writeAsString('{broken');
    expect((await a.current()).version, 'orca-invoice-a4-v1');

    final pending = Completer<Map<String, dynamic>>();
    var active = true;
    final c = store(() => pending.future, scope: 'c', isActive: () => active);
    final refresh = c.refresh();
    active = false;
    pending.complete({'template': validTemplate()});
    await refresh;
    expect((await c.current()).version, 'orca-invoice-a4-v1');
  });

  test('concurrent refreshes share one fetch', () async {
    final pending = Completer<Map<String, dynamic>>();
    var calls = 0;
    final cache = store(() {
      calls++;
      return pending.future;
    });
    final first = cache.refresh();
    final second = cache.refresh();
    expect(calls, 1);
    pending.complete({
      'data': {'template': validTemplate()}
    });
    await Future.wait([first, second]);
    expect((await cache.current()).version, 'v1.2-test');
  });

  test('session change during disk lookup prevents old session commit',
      () async {
    final pendingDirectory = Completer<Directory>();
    final directoryRequested = Completer<void>();
    var active = true;
    final cache = InvoiceTemplateStore(
      scope: 'account',
      fetch: () async => {'template': validTemplate()},
      isActive: () => active,
      directoryProvider: () {
        directoryRequested.complete();
        return pendingDirectory.future;
      },
    );
    final refresh = cache.refresh();
    await directoryRequested.future;
    active = false;
    pendingDirectory.complete(directory);
    await refresh;
    expect(directory.listSync(), isEmpty);
  });

  test('storage failure keeps previous template intact', () async {
    var fail = false;
    final cache = InvoiceTemplateStore(
      scope: 'account',
      fetch: () async => {'template': validTemplate()},
      directoryProvider: () async {
        if (fail) throw const FileSystemException('unavailable');
        return directory;
      },
    );
    await cache.refresh();
    fail = true;
    await expectLater(cache.refresh(), throwsA(isA<FileSystemException>()));
    fail = false;
    expect((await cache.current()).version, 'v1.2-test');
  });

  test('accepts text limits and multiline company details', () async {
    final template = validTemplate()
      ..['company_name'] = 'x' * 200
      ..['footer'] = 'x' * 120
      ..['company_details'] = '${'x' * 1997}\r\n\t';
    final cache = store(() async => {'template': template});
    await cache.refresh();
    final result = await cache.current();
    expect(result.footer.length, 120);
    expect(result.companyDetails.length, 2000);
    expect(result.companyName.length, 200);
    expect(result.companyDetails, endsWith('\r\n\t'));
  });

  test('rejects visible widths below 28 points without replacing cache',
      () async {
    var template = validTemplate();
    final cache = store(() async => {'template': template});
    await cache.refresh();

    // At margin 50, seven other unit widths make this the exact threshold.
    final threshold = 28 * 7 / (595.2756 - 100 - 28);
    Map<String, dynamic> boundary(double indexWidth) => validTemplate()
      ..['show_notes'] = true
      ..['column_widths'] = {
        'index': indexWidth,
        'image': 1,
        'name': 1,
        'quantity': 1,
        'unit': 1,
        'price': 1,
        'total': 1,
        'note': 1,
      };
    template = boundary(threshold - 0.000001)..['version'] = 'too-narrow';
    await expectLater(cache.refresh(), throwsFormatException);
    expect((await cache.current()).version, 'v1.2-test');

    template = boundary(threshold + 0.000001)..['version'] = 'wide-enough';
    await cache.refresh();
    expect((await cache.current()).version, 'wide-enough');

    template = boundary(threshold - 0.000001)
      ..['margin'] = 20
      ..['version'] = 'smaller-margin';
    await cache.refresh();
    expect((await cache.current()).version, 'smaller-margin');
  });

  test('hidden image and note do not count toward visible widths', () async {
    final template = validTemplate()
      ..['show_images'] = false
      ..['show_notes'] = false
      ..['column_widths'] = {
        'index': .4,
        'image': 4,
        'name': 1,
        'quantity': 1,
        'unit': 1,
        'price': 1,
        'total': 1,
        'note': 4,
      };
    final cache = store(() async => {'template': template});
    await cache.refresh();
    for (final flag in ['show_images', 'show_notes']) {
      template[flag] = true;
      await expectLater(cache.refresh(), throwsFormatException);
      template[flag] = false;
    }

    // Hidden narrow columns themselves must not be checked.
    template['column_widths'] = {
      'index': 2,
      'image': .4,
      'name': 2,
      'quantity': 2,
      'unit': 2,
      'price': 2,
      'total': 2,
      'note': .4,
    };
    await cache.refresh();
    for (final flag in ['show_images', 'show_notes']) {
      template[flag] = true;
      await expectLater(cache.refresh(), throwsFormatException);
      template[flag] = false;
    }
  });

  test('accepts 28 point boundary despite floating point roundoff', () async {
    final template = validTemplate()
      ..['margin'] = 47.6378
      ..['show_images'] = false
      ..['show_notes'] = false
      ..['column_widths'] = {
        'index': .42,
        'image': 1,
        'name': 1.416,
        'quantity': 1.416,
        'unit': 1.416,
        'price': 1.416,
        'total': 1.416,
        'note': 1,
      };
    final cache = store(() async => {'template': template});
    await cache.refresh();
    expect((await cache.current()).columnWidths['index'], .42);
  });
}
