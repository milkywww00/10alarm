import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  static final ThemeService instance = ThemeService._();
  ThemeService._();

  static const String _keyThemeMode = 'theme_mode_v1';
  static const String _keyThemeColor = 'theme_color_v1';
  static const String _keyAlarmSound = 'alarm_sound_v1';
  static const String _keyCustomSounds = 'custom_alarm_sounds_v1';
  static const String _keyVibrate = 'alarm_vibrate_v1';

  final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);
  final ValueNotifier<Color> themeColorNotifier = ValueNotifier<Color>(const Color(0xFF6750A4));
  final ValueNotifier<String> alarmSoundNotifier = ValueNotifier<String>('기본 알람');
  final ValueNotifier<bool> vibrateNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<List<Map<String, String>>> customSoundsNotifier = ValueNotifier<List<Map<String, String>>>([]);

  // 깔끔하고 직관적인 프리셋 컬러 팔레트
  static const List<Map<String, dynamic>> presetColors = [
    {'name': '퍼플', 'color': Color(0xFF6750A4)},
    {'name': '핑크', 'color': Color(0xFFE91E63)},
    {'name': '블루', 'color': Color(0xFF1E88E5)},
    {'name': '민트', 'color': Color(0xFF00897B)},
    {'name': '코랄', 'color': Color(0xFFFF7043)},
    {'name': '옐로우', 'color': Color(0xFFFFA000)},
    {'name': '네이비', 'color': Color(0xFF3949AB)},
    {'name': '차콜', 'color': Color(0xFF455A64)},
  ];

  // 깔끔하고 직관적인 기본 알림음 프리셋
  static const List<String> alarmSounds = [
    '기본 알람',
    '피아노',
    '실로폰',
    '오르골',
    '차임벨',
    '벨소리',
    '하모니카',
    '팡파르',
    '핑퐁',
    '자명종',
    '비프음',
  ];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final modeStr = prefs.getString(_keyThemeMode);
    if (modeStr == 'light') {
      themeModeNotifier.value = ThemeMode.light;
    } else if (modeStr == 'dark') {
      themeModeNotifier.value = ThemeMode.dark;
    } else {
      themeModeNotifier.value = ThemeMode.system;
    }

    final colorValue = prefs.getInt(_keyThemeColor);
    if (colorValue != null) {
      themeColorNotifier.value = Color(colorValue);
    }

    // 커스텀 사운드 목록 복원
    final customSoundsJson = prefs.getString(_keyCustomSounds);
    if (customSoundsJson != null) {
      try {
        final List decoded = json.decode(customSoundsJson);
        customSoundsNotifier.value = decoded.map((e) => Map<String, String>.from(e as Map)).toList();
      } catch (_) {}
    }

    final sound = prefs.getString(_keyAlarmSound);
    if (sound != null) {
      // 기존 명칭 마이그레이션 호환
      if (sound == '기본 알람 벨' || sound == '모닝 차임 (기본)') {
        alarmSoundNotifier.value = '기본 알람';
      } else {
        alarmSoundNotifier.value = sound;
      }
    }
    await prefs.setString(_keyAlarmSound, alarmSoundNotifier.value);

    final vibrate = prefs.getBool(_keyVibrate);
    if (vibrate != null) {
      vibrateNotifier.value = vibrate;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeModeNotifier.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, mode.name);
  }

  Future<void> setThemeColor(Color color) async {
    themeColorNotifier.value = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyThemeColor, color.toARGB32());
  }

  Future<void> setAlarmSound(String sound) async {
    alarmSoundNotifier.value = sound;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAlarmSound, sound);
  }

  // 직접 업로드한 커스텀 알림음 추가
  Future<void> addCustomSound(String name, String path) async {
    final current = List<Map<String, String>>.from(customSoundsNotifier.value);
    // 중복 제거
    current.removeWhere((item) => item['name'] == name);
    current.add({'name': name, 'path': path});

    customSoundsNotifier.value = current;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCustomSounds, json.encode(current));

    // 추가 즉시 해당 사운드로 자동 선택
    await setAlarmSound(name);
  }

  // 커스텀 알림음 삭제
  Future<void> deleteCustomSound(String name) async {
    final current = List<Map<String, String>>.from(customSoundsNotifier.value);
    current.removeWhere((item) => item['name'] == name);
    customSoundsNotifier.value = current;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCustomSounds, json.encode(current));

    // 현재 선택된 사운드가 삭제된 것이라면 기본음으로 복구
    if (alarmSoundNotifier.value == name) {
      await setAlarmSound('기본 알람');
    }
  }

  Future<void> setVibrate(bool vibrate) async {
    vibrateNotifier.value = vibrate;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyVibrate, vibrate);
  }
}
