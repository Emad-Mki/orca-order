import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

String invoiceImageScope(String environment, String userId, String role) =>
    jsonEncode([environment, userId, role]);

/// Private, per-invoice image snapshots; reading never accesses the network.
class InvoiceProductImages {
  InvoiceProductImages({
    required this.scope,
    this.directory,
    Future<Uint8List> Function(Uri)? download,
  }) : _download = download ?? _downloadImage;

  final String scope;
  final Directory? directory;
  final Future<Uint8List> Function(Uri) _download;
  static const int maxBytes = 2 * 1024 * 1024;
  static final Map<String, Future<void>> _writes = {};

  Future<File> _file(String invoiceId, String code) async {
    final root = directory ?? await getApplicationSupportDirectory();
    final account = sha256.convert(utf8.encode(scope));
    final image = sha256.convert(utf8.encode(jsonEncode([invoiceId, code])));
    return File(
        path.join(root.path, 'invoice_images', '$account', '$image.img'));
  }

  static Future<Uint8List> _downloadImage(Uri url) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      var current = url;
      for (var redirects = 0; redirects < 4; redirects++) {
        if (current.scheme != 'https' || current.userInfo.isNotEmpty) {
          throw const FormatException('Invalid image URL');
        }
        final request = await client.getUrl(current);
        request.followRedirects = false;
        final response =
            await request.close().timeout(const Duration(seconds: 12));
        if (response.isRedirect) {
          final location = response.headers.value(HttpHeaders.locationHeader);
          if (location == null) throw const FormatException('Invalid redirect');
          await response.drain<void>();
          current = current.resolve(location);
          continue;
        }
        if (response.statusCode != HttpStatus.ok ||
            response.contentLength > maxBytes) {
          throw const FormatException('Invalid image response');
        }
        final output = BytesBuilder(copy: false);
        var size = 0;
        await for (final chunk
            in response.timeout(const Duration(seconds: 12))) {
          size += chunk.length;
          if (size > maxBytes) throw const FormatException('Image too large');
          output.add(chunk);
        }
        return output.takeBytes();
      }
      throw const FormatException('Too many image redirects');
    } finally {
      client.close(force: true);
    }
  }

  static Future<void> _validate(Uint8List bytes) async {
    final png = bytes.length >= 8 &&
        const [137, 80, 78, 71, 13, 10, 26, 10]
            .asMap()
            .entries
            .every((entry) => bytes[entry.key] == entry.value);
    final jpeg = bytes.length >= 4 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255 &&
        bytes[bytes.length - 2] == 255 &&
        bytes.last == 217;
    if (bytes.length > maxBytes || (!png && !jpeg)) {
      throw const FormatException('Invalid invoice image');
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    try {
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      try {
        if (descriptor.width < 1 ||
            descriptor.height < 1 ||
            descriptor.width > 4096 ||
            descriptor.height > 4096 ||
            descriptor.width * descriptor.height > 16000000) {
          throw const FormatException('Invalid invoice image dimensions');
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
  }

  Future<void> cache(String invoiceId, Map<String, String> urls) async {
    if (invoiceId.isEmpty || scope.isEmpty) {
      throw ArgumentError('Invalid scope');
    }
    for (final entry in urls.entries) {
      if (entry.key.isEmpty) continue;
      final url = Uri.tryParse(entry.value);
      if (url == null || url.scheme != 'https' || url.userInfo.isNotEmpty) {
        debugPrint('Invoice image URL is invalid; using placeholder');
        continue;
      }
      final file = await _file(invoiceId, entry.key);
      if (await file.exists()) continue;
      final key = file.path;
      if (_writes.containsKey(key)) {
        try {
          await _writes[key];
        } catch (error) {
          debugPrint(
              'Invoice image unavailable; using placeholder: ${error.runtimeType}');
        }
        continue;
      }
      final operation = () async {
        final bytes = await _download(url);
        await _validate(bytes);
        await file.parent.create(recursive: true);
        final temp =
            File('$key.$pid.${DateTime.now().microsecondsSinceEpoch}.tmp');
        try {
          await temp.writeAsBytes(bytes, flush: true);
          if (!await file.exists()) await temp.rename(file.path);
        } finally {
          if (await temp.exists()) await temp.delete();
        }
      }();
      _writes[key] = operation;
      try {
        await operation;
      } catch (error) {
        debugPrint(
            'Invoice image unavailable; using placeholder: ${error.runtimeType}');
      } finally {
        if (identical(_writes[key], operation)) _writes.remove(key);
      }
    }
  }

  Future<Map<String, Uint8List>> read(
      String invoiceId, Iterable<String> codes) async {
    final result = <String, Uint8List>{};
    for (final code in codes.toSet()) {
      final file = await _file(invoiceId, code);
      try {
        if (!await file.exists() || await file.length() > maxBytes) continue;
        final bytes = await file.readAsBytes();
        await _validate(bytes);
        result[code] = bytes;
      } catch (error) {
        debugPrint(
            'Invoice image cache invalid; using placeholder: ${error.runtimeType}');
      }
    }
    return result;
  }
}
