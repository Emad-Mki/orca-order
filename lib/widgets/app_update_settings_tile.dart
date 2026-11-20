import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/app_update_dialog.dart';
import '../services/app_update_service.dart';

class AppUpdateSettingsTile extends StatelessWidget {
  const AppUpdateSettingsTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppUpdateService>(
      builder: (context, updater, _) {
        final available = updater.status == AppUpdateStatus.available ||
            updater.status == AppUpdateStatus.paused ||
            updater.status == AppUpdateStatus.ready;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.system_update_alt_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'تحديث التطبيق',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (updater.status == AppUpdateStatus.checking)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('الإصدار الحالي: ${updater.installedVersionName}'),
                Text('رقم البناء: ${updater.installedBuildNumber}'),
                Text(
                  updater.lastSuccessfulCheckAt == null
                      ? 'لم ينجح فحص تحديث بعد'
                      : 'آخر فحص ناجح: '
                          '${updater.lastSuccessfulCheckAt!.toLocal()}',
                ),
                if (updater.installationConfirmed) ...[
                  const SizedBox(height: 6),
                  Text(
                    'تم تثبيت الإصدار ${updater.installedVersionName} بنجاح.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
                if (updater.status == AppUpdateStatus.noUpdate)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text('التطبيق محدّث.'),
                  ),
                if (updater.errorMessage != null &&
                    updater.status == AppUpdateStatus.error) ...[
                  const SizedBox(height: 6),
                  Text(
                    updater.errorMessage!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: updater.status == AppUpdateStatus.checking
                          ? null
                          : () async {
                              await updater.checkForUpdates(manual: true);
                              if (!context.mounted) return;
                              if (updater.status == AppUpdateStatus.available) {
                                await showDialog<void>(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (_) => AppUpdateDialog(
                                    requiredUpdate: updater.isRequired,
                                  ),
                                );
                              } else if (updater.status ==
                                  AppUpdateStatus.noUpdate) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('التطبيق محدّث إلى آخر إصدار.'),
                                  ),
                                );
                              } else if (updater.errorMessage != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(updater.errorMessage!),
                                  ),
                                );
                              }
                            },
                      icon: const Icon(Icons.refresh),
                      label: const Text('التحقق من وجود تحديث'),
                    ),
                    if (available)
                      FilledButton.tonal(
                        onPressed: () => showDialog<void>(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => AppUpdateDialog(
                            requiredUpdate: updater.isRequired,
                          ),
                        ),
                        child: Text(updater.status == AppUpdateStatus.ready
                            ? 'متابعة التثبيت'
                            : 'عرض التحديث'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
