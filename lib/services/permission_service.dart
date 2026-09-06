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

  /// 절전 모드(배터리 최적화) 제외 여부 확인
  Future<bool> isBatteryOptimizationIgnored() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    return await Permission.ignoreBatteryOptimizations.isGranted;
  }

  /// 절전 모드(배터리 최적화) 제외 요청 (앱 종료 시에도 알람 울림 보장)
  Future<bool> requestIgnoreBatteryOptimization() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    final status = await Permission.ignoreBatteryOptimizations.request();
    return status.isGranted;
  }

  /// 다른 앱 위에 표시 (SYSTEM_ALERT_WINDOW) 권한 확인
  /// Android 10+ 및 삼성 기기에서 앱이 종료되어 있어도 알람 화면을 최상단에 띄우기 위해 필수
  Future<bool> isSystemAlertWindowGranted() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      final status = await Permission.systemAlertWindow.status;
      return status.isGranted;
    } catch (e) {
      debugPrint('isSystemAlertWindowGranted error: $e');
      return false;
    }
  }

  /// 다른 앱 위에 표시 권한 설정 요청
  Future<bool> requestSystemAlertWindow() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      final status = await Permission.systemAlertWindow.request();
      if (!status.isGranted) {
        // 일부 기기(삼성/샤오미 등)에서 request()가 설정창을 열지 않는 경우 대비 openAppSettings fallback
        await openAppSettings();
      }
      return await isSystemAlertWindowGranted();
    } catch (e) {
      debugPrint('requestSystemAlertWindow error: $e');
      await openAppSettings();
      return false;
    }
  }

  /// 기기 앱 설정 화면 열기
  Future<bool> openSettings() async {
    return await openAppSettings();
  }
}
