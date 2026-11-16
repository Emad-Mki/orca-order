import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_update_service.dart';

class AppUpdateDialog extends StatelessWidget {
  final bool requiredUpdate;

  const AppUpdateDialog({super.key, required this.requiredUpdate});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !requiredUpdate,
      child: Consumer<AppUpdateService>(
        builder: (context, updater, _) {
          final manifest = updater.manifest;
          if (manifest == null) {
            return AlertDialog(
              title: const Text('تحديث التطبيق'),
              content: Text(updater.errorMessage ?? 'لا تتوفر بيانات التحديث'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إغلاق'),
                ),
                FilledButton(
                  onPressed: () => updater.checkForUpdates(manual: true),
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            );
          }

          final theme = Theme.of(context);
          final active = updater.status == AppUpdateStatus.downloading ||
              updater.status == AppUpdateStatus.verifying;
          return AlertDialog(
            icon: Icon(
              updater.status == AppUpdateStatus.ready
                  ? Icons.verified_outlined
                  : Icons.system_update_alt_rounded,
              color: theme.colorScheme.primary,
              size: 34,
            ),
            title: Text(
              updater.status == AppUpdateStatus.ready
                  ? 'التحديث جاهز للتثبيت'
                  : requiredUpdate
                      ? 'يلزم تحديث التطبيق'
                      : 'يتوفر إصدار جديد',
              textAlign: TextAlign.center,
            ),
            content: SizedBox(
              width: math.min(420.0, MediaQuery.sizeOf(context).width - 72),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'الإصدار ${manifest.versionName}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      requiredUpdate
                          ? 'هذا الإصدار مطلوب لمتابعة استخدام التطبيق. لن تُحذف بياناتك أو جلستك.'
                          : 'يمكنك تثبيت التحديث الآن أو تأجيله.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 180),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          manifest.releaseNotes,
                          style: theme.textTheme.bodyMedium,
                          softWrap: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'حجم الملف: ${_formatBytes(manifest.sizeBytes)}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (updater.status == AppUpdateStatus.downloading) ...[
                      const SizedBox(height: 18),
                      LinearProgressIndicator(value: updater.progress),
                      const SizedBox(height: 8),
                      Text(
                        updater.progress == null
                            ? 'تم تنزيل ${_formatBytes(updater.downloadedBytes)}'
                            : '${(updater.progress! * 100).round()}٪  ·  ${_formatBytes(updater.downloadedBytes)} من ${_formatBytes(manifest.sizeBytes)}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    if (updater.status == AppUpdateStatus.verifying) ...[
                      const SizedBox(height: 18),
                      const LinearProgressIndicator(),
                      const SizedBox(height: 8),
                      const Text('جارٍ التحقق من سلامة الملف وتوقيعه',
                          textAlign: TextAlign.center),
                    ],
                    if (updater.errorMessage != null &&
                        (updater.status == AppUpdateStatus.error ||
                            updater.errorStage == 'check')) ...[
                      const SizedBox(height: 12),
                      Text(
                        updater.errorMessage!,
                        style: TextStyle(color: theme.colorScheme.error),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    if (updater.status == AppUpdateStatus.ready) ...[
                      const SizedBox(height: 12),
                      Text(
                        'سيفتح مثبت Android لتأكيد التثبيت. لا يُعد التحديث مكتملًا حتى يُثبت النظام الإصدار الجديد.',
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                    if (updater.installPermissionRequired) ...[
                      const SizedBox(height: 12),
                      Text(
                        'اسمح لتطبيق Orca Order بتثبيت التطبيقات من إعدادات Android، ثم ارجع واضغط «تثبيت الآن». لا يبدأ التثبيت دون موافقتك.',
                        style: TextStyle(color: theme.colorScheme.primary),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actions: [
              if (!requiredUpdate)
                TextButton(
                  onPressed: () async {
                    await updater.dismissOptionalUpdate();
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Text(active ? 'إخفاء' : 'لاحقًا'),
                )
              else if (active)
                TextButton(
                  onPressed: updater.status == AppUpdateStatus.downloading
                      ? updater.cancelDownload
                      : null,
                  child: const Text('إيقاف التنزيل'),
                )
              else
                const SizedBox.shrink(),
              _primaryAction(context, updater, active),
            ],
          );
        },
      ),
    );
  }

  Widget _primaryAction(
    BuildContext context,
    AppUpdateService updater,
    bool active,
  ) {
    switch (updater.status) {
      case AppUpdateStatus.ready:
        return FilledButton.icon(
          onPressed: () async {
            try {
              final launched = await updater.installReadyApk();
              if (launched && context.mounted) Navigator.pop(context);
            } catch (error) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('تعذر فتح مثبت Android: $error')),
              );
            }
          },
          icon: const Icon(Icons.install_mobile),
          label: const Text('تثبيت الآن'),
        );
      case AppUpdateStatus.downloading:
      case AppUpdateStatus.verifying:
        return FilledButton(
          onPressed: null,
          child: Text(updater.status == AppUpdateStatus.verifying
              ? 'جارٍ التحقق...'
              : 'جارٍ التنزيل...'),
        );
      case AppUpdateStatus.paused:
        return FilledButton.icon(
          onPressed: updater.downloadUpdate,
          icon: const Icon(Icons.play_arrow),
          label: const Text('استئناف التنزيل'),
        );
      case AppUpdateStatus.error:
        return FilledButton.icon(
          onPressed: updater.errorStage == 'check'
              ? () => updater.checkForUpdates(manual: true)
              : updater.downloadUpdate,
          icon: const Icon(Icons.refresh),
          label: const Text('إعادة المحاولة'),
        );
      default:
        return FilledButton.icon(
          onPressed: active ? null : updater.downloadUpdate,
          icon: const Icon(Icons.download),
          label: const Text('تحديث الآن'),
        );
    }
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes بايت';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} كيلوبايت';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} ميغابايت';
  }
}
