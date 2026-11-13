class UserDeviceModel {
  final String deviceId;
  final String userId;
  final String platform;
  final String appVersion;
  final DateTime? lastActiveAt;
  final bool isActive;

  const UserDeviceModel({
    required this.deviceId,
    required this.userId,
    required this.platform,
    required this.appVersion,
    required this.isActive,
    this.lastActiveAt,
  });

  factory UserDeviceModel.fromJson(Map<String, dynamic> json) =>
      UserDeviceModel(
        deviceId: (json['device_id'] ?? '').toString(),
        userId: (json['user_id'] ?? '').toString(),
        platform: (json['platform'] ?? '').toString(),
        appVersion: (json['app_version'] ?? '').toString(),
        lastActiveAt: DateTime.tryParse(
          (json['last_active_at'] ?? '').toString(),
        ),
        isActive: json['is_active'] == true ||
            json['is_active']?.toString().toLowerCase() == 'true' ||
            json['is_active']?.toString() == '1',
      );
}
