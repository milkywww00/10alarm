import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static final PermissionService instance = PermissionService._();
  PermissionService._();

  Future<bool> requestEssentialPermissions() async {
    if (kIsWeb || !Platform.isAndroid) return true;

    // 1. 알림 권한 (Android 13+)
    final notifStatus = await Permission.notification.status;
    if (!notifStatus.isGranted) {
      await Permission.notification.request();
    }

    // 2. 정확한 알람 스케줄 권한 (Android 12+)
    final exactAlarmStatus = await Permission.scheduleExactAlarm.status;
    if (!exactAlarmStatus.isGranted) {
      await Permission.scheduleExactAlarm.request();
    }

    return true;
  }

  Future<bool> isNotificationGranted() async {
    return await Permission.notification.isGranted;
  }

  Future<bool> isExactAlarmGranted() async {
    if (!Platform.isAndroid) return true;
    return await Permission.scheduleExactAlarm.isGranted;
  }
}
