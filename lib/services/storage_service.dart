import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/character_profile.dart';
import '../models/alarm_item.dart';
import '../models/pomodoro_config.dart';
import '../models/stopwatch_config.dart';
import '../models/schedule_item.dart';
import '../models/message_bundle.dart';
import '../models/chat_message.dart';

class StorageService {
  static const String _keyCharacters = 'characters_v1';
  static const String _keyAlarms = 'alarms_v1';
  static const String _keyPomodoro = 'pomodoro_config_v1';
  static const String _keyStopwatch = 'stopwatch_config_v1';
  static const String _keySchedules = 'schedules_v1';
  static const String _keyBundles = 'message_bundles_v1';
  static const String _keyChatPrefix = 'chat_messages_v1_';

  static final StorageService instance = StorageService._();
  StorageService._();

  // In-memory caches for high-speed O(1) reads and zero unnecessary disk I/O
  List<CharacterProfile>? _cachedCharacters;
  List<AlarmItem>? _cachedAlarms;
  List<ScheduleItem>? _cachedSchedules;

  // ----- Character Profiles -----

  Future<List<CharacterProfile>> getCharacters() async {
    if (_cachedCharacters != null) {
      return List.from(_cachedCharacters!);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final listJson = prefs.getStringList(_keyCharacters);
      if (listJson == null || listJson.isEmpty) {
        _cachedCharacters = [];
        return [];
      }
      final List<CharacterProfile> list = [];
      for (final item in listJson) {
        try {
          list.add(CharacterProfile.fromJson(item));
        } catch (_) {}
      }
      _cachedCharacters = list;
      return List.from(list);
    } catch (_) {
      _cachedCharacters = [];
      return [];
    }
  }

  Future<void> saveCharacter(CharacterProfile character) async {
    final characters = await getCharacters();
    final index = characters.indexWhere((c) => c.id == character.id);
    if (index >= 0) {
      characters[index] = character;
    } else {
      characters.add(character);
    }
    _cachedCharacters = characters;

    final prefs = await SharedPreferences.getInstance();
    final listJson = characters.map((c) => c.toJson()).toList();
    await prefs.setStringList(_keyCharacters, listJson);
  }

  Future<void> deleteCharacter(String characterId) async {
    final characters = await getCharacters();
    characters.removeWhere((c) => c.id == characterId);
    _cachedCharacters = characters;

    final prefs = await SharedPreferences.getInstance();
    final listJson = characters.map((c) => c.toJson()).toList();
    await prefs.setStringList(_keyCharacters, listJson);

    // 연관된 알람도 함께 정리
    final alarms = await getAlarms();
    alarms.removeWhere((a) => a.characterId != characterId);
    _cachedAlarms = alarms;
    await prefs.setStringList(
      _keyAlarms,
      alarms.map((a) => a.toJson()).toList(),
    );
  }

  Future<CharacterProfile?> getCharacterById(String id) async {
    final characters = await getCharacters();
    try {
      return characters.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  // ----- Alarms -----

  Future<List<AlarmItem>> getAlarms() async {
    if (_cachedAlarms != null) {
      return List.from(_cachedAlarms!);
    }
    final prefs = await SharedPreferences.getInstance();
    final listJson = prefs.getStringList(_keyAlarms);
    if (listJson == null || listJson.isEmpty) {
      _cachedAlarms = [];
      return [];
    }
    final alarms = listJson.map((item) => AlarmItem.fromJson(item)).toList();
    _cachedAlarms = alarms;
    return List.from(alarms);
  }

  Future<void> saveAlarm(AlarmItem alarm) async {
    final alarms = await getAlarms();
    final index = alarms.indexWhere((a) => a.id == alarm.id);
    if (index >= 0) {
      alarms[index] = alarm;
    } else {
      alarms.add(alarm);
    }
    _cachedAlarms = alarms;

    final prefs = await SharedPreferences.getInstance();
    final listJson = alarms.map((a) => a.toJson()).toList();
    await prefs.setStringList(_keyAlarms, listJson);
  }

  Future<void> deleteAlarm(String alarmId) async {
    final alarms = await getAlarms();
    alarms.removeWhere((a) => a.id == alarmId);
    _cachedAlarms = alarms;

    final prefs = await SharedPreferences.getInstance();
    final listJson = alarms.map((a) => a.toJson()).toList();
    await prefs.setStringList(_keyAlarms, listJson);
  }

  // ----- Pomodoro Config -----

  Future<PomodoroConfig> getPomodoroConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyPomodoro);
    if (jsonStr == null || jsonStr.isEmpty) {
      return PomodoroConfig();
    }
    try {
      return PomodoroConfig.fromJson(jsonStr);
    } catch (_) {
      return PomodoroConfig();
    }
  }

  Future<void> savePomodoroConfig(PomodoroConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPomodoro, config.toJson());
  }

  // ----- Stopwatch Config -----

  Future<StopwatchConfig> getStopwatchConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyStopwatch);
    if (jsonStr == null || jsonStr.isEmpty) {
      return StopwatchConfig();
    }
    try {
      return StopwatchConfig.fromJson(jsonStr);
    } catch (_) {
      return StopwatchConfig();
    }
  }

  Future<void> saveStopwatchConfig(StopwatchConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyStopwatch, config.toJson());
  }

  // ----- Calendar Schedules -----

  Future<List<ScheduleItem>> getSchedules() async {
    if (_cachedSchedules != null) {
      return List.from(_cachedSchedules!);
    }
    final prefs = await SharedPreferences.getInstance();
    final listJson = prefs.getStringList(_keySchedules);
    if (listJson == null || listJson.isEmpty) {
      _cachedSchedules = [];
      return [];
    }
    final schedules = listJson.map((item) => ScheduleItem.fromJson(item)).toList();
    _cachedSchedules = schedules;
    return List.from(schedules);
  }

  Future<void> saveSchedule(ScheduleItem schedule) async {
    final schedules = await getSchedules();
    final index = schedules.indexWhere((s) => s.id == schedule.id);
    if (index >= 0) {
      schedules[index] = schedule;
    } else {
      schedules.add(schedule);
    }
    _cachedSchedules = schedules;

    final prefs = await SharedPreferences.getInstance();
    final listJson = schedules.map((s) => s.toJson()).toList();
    await prefs.setStringList(_keySchedules, listJson);
  }

  Future<void> deleteSchedule(String scheduleId) async {
    final schedules = await getSchedules();
    schedules.removeWhere((s) => s.id == scheduleId);
    _cachedSchedules = schedules;

    final prefs = await SharedPreferences.getInstance();
    final listJson = schedules.map((s) => s.toJson()).toList();
    await prefs.setStringList(_keySchedules, listJson);
  }

  Future<void> toggleScheduleCompleted(String scheduleId) async {
    final schedules = await getSchedules();
    final index = schedules.indexWhere((s) => s.id == scheduleId);
    if (index >= 0) {
      final current = schedules[index];
      schedules[index] = current.copyWith(isCompleted: !current.isCompleted);
      _cachedSchedules = schedules;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _keySchedules,
        schedules.map((s) => s.toJson()).toList(),
      );
    }
  }

  // ----- Message Bundles -----

  Future<List<MessageBundle>> getMessageBundles() async {
    final prefs = await SharedPreferences.getInstance();
    final listJson = prefs.getStringList(_keyBundles);
    if (listJson == null || listJson.isEmpty) {
      return [];
    }
    return listJson.map((item) => MessageBundle.fromJson(item)).toList();
  }

  Future<List<MessageBundle>> getMessageBundlesByCharacter(String characterId) async {
    final bundles = await getMessageBundles();
    return bundles.where((b) => b.characterId == characterId).toList();
  }

  Future<void> saveMessageBundle(MessageBundle bundle) async {
    final prefs = await SharedPreferences.getInstance();
    final bundles = await getMessageBundles();
    final index = bundles.indexWhere((b) => b.id == bundle.id);
    if (index >= 0) {
      bundles[index] = bundle;
    } else {
      bundles.add(bundle);
    }
    final listJson = bundles.map((b) => b.toJson()).toList();
    await prefs.setStringList(_keyBundles, listJson);
  }

  Future<void> deleteMessageBundle(String bundleId) async {
    final prefs = await SharedPreferences.getInstance();
    final bundles = await getMessageBundles();
    bundles.removeWhere((b) => b.id == bundleId);
    final listJson = bundles.map((b) => b.toJson()).toList();
    await prefs.setStringList(_keyBundles, listJson);
  }

  // ----- Chat Messages -----

  Future<List<ChatMessage>> getChatMessages(String characterId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listJson = prefs.getStringList('$_keyChatPrefix$characterId');
      if (listJson == null || listJson.isEmpty) {
        return [];
      }
      final List<ChatMessage> list = [];
      for (final item in listJson) {
        try {
          list.add(ChatMessage.fromJson(item));
        } catch (_) {}
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<void> saveChatMessage(ChatMessage message) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyChatPrefix${message.characterId}';
    final messages = await getChatMessages(message.characterId);
    messages.add(message);
    // 최대 최근 100개 유지
    if (messages.length > 100) {
      messages.removeRange(0, messages.length - 100);
    }
    final listJson = messages.map((m) => m.toJson()).toList();
    await prefs.setStringList(key, listJson);
  }

  Future<void> clearChatMessages(String characterId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyChatPrefix$characterId');
  }

  // ----- Permanent Image Storage -----

  Future<String> saveImagePermanently(File sourceFile) async {
    final appDir = await getApplicationDocumentsDirectory();
    final rawExt = sourceFile.path.split('.').last.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final safeExt = ['jpg', 'jpeg', 'png', 'webp'].contains(rawExt) ? rawExt : 'png';
    final newFileName = 'avatar_${const Uuid().v4()}.$safeExt';
    final targetPath = '${appDir.path}/$newFileName';
    final savedFile = await sourceFile.copy(targetPath);
    return savedFile.path;
  }
}
