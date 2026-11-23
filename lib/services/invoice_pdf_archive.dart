import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Each export creates an immutable new file in the account's private storage.
class InvoicePdfArchive {
  InvoicePdfArchive({
    required this.environment,
    required this.userId,
    required this.role,
    this.rootDirectory,
  });

  final String environment;
  final String userId;
  final String role;
  final Directory? rootDirectory;

  Future<Directory> _directory() async {
    if (userId.trim().isEmpty || role.trim().isEmpty) {
      throw StateError('لا يمكن أرشفة الفاتورة دون حساب معروف');
    }
    final root = rootDirectory ?? await getApplicationSupportDirectory();
    final scope = sha256
        .convert(utf8.encode(jsonEncode([environment, userId, role])))
        .toString();
    final directory = Directory(path.join(root.path, 'invoice_archive', scope));
    await directory.create(recursive: true);
    return directory;
  }

  Future<File> save({
    required Uint8List bytes,
    required String invoiceId,
    required String templateVersion,
  }) async {
    if (bytes.length < 5 ||
        ascii.decode(bytes.sublist(0, 5), allowInvalid: true) != '%PDF-' ||
        invoiceId.trim().isEmpty ||
        !RegExp(r'^[A-Za-z0-9._-]{1,40}$').hasMatch(templateVersion)) {
      throw const FormatException('بيانات أرشفة الفاتورة غير صالحة');
    }
    final directory = await _directory();
    final invoiceHash = sha256.convert(utf8.encode(invoiceId)).toString();
    final random = Random.secure();
    final nonce = List.generate(16, (_) => random.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    final name =
        '${invoiceHash}_${DateTime.now().toUtc().microsecondsSinceEpoch}'
        '_${templateVersion}_$nonce.pdf';
    final file = File(path.join(directory.path, name));
    await file.create(exclusive: true);
    try {
      await file.writeAsBytes(bytes, flush: true);
    } catch (_) {
      if (await file.exists()) await file.delete();
      rethrow;
    }
    return file;
  }

  Future<List<File>> list({String? invoiceId}) async {
    final directory = await _directory();
    final prefix =
        invoiceId == null ? null : '${sha256.convert(utf8.encode(invoiceId))}_';
    final files = await directory
        .list(followLinks: false)
        .where((entity) =>
            entity is File &&
            entity.path.endsWith('.pdf') &&
            (prefix == null || path.basename(entity.path).startsWith(prefix)))
        .cast<File>()
        .toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }
}
