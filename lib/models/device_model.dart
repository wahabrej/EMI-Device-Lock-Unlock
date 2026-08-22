class DeviceModel {
  final String deviceId;
  final String fcmToken;
  final bool isAdminActive;
  final bool isLocked;
  final String? registeredDate;

  DeviceModel({
    required this.deviceId,
    required this.fcmToken,
    this.isAdminActive = false,
    this.isLocked = false,
    this.registeredDate,
  });

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      deviceId: json['deviceId'] ?? '',
      fcmToken: json['fcmToken'] ?? '',
      isAdminActive: json['isAdminActive'] ?? false,
      isLocked: json['isLocked'] ?? false,
      registeredDate: json['registeredDate'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'fcmToken': fcmToken,
      'isAdminActive': isAdminActive,
      'isLocked': isLocked,
      'registeredDate': registeredDate,
    };
  }
}