import 'package:flutter/material.dart';

void popAfterGuard(
  BuildContext context, {
  required VoidCallback allowPop,
  Object? result,
}) {
  allowPop();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (context.mounted) Navigator.of(context).pop(result);
  });
}
