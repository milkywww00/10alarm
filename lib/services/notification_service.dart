import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:uuid/uuid.dart';
import '../models/alarm_item.dart';
import '../models/character_profile.dart';
import '../models/chat_message.dart';
import '../utils/message_formatter.dart';
import 'storage_service.dart';
import 'theme_service.dart';

import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'sound_service.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String channelId = 'fav_alarm_channel';
  static const String channelName = '최애 알람 채널';
  static const String channelDescription = '설정한 캐릭터의 가상 메시지 알람 알림입니다.';

  /// 알람음 이름 -> Android res/raw 리소스 파일명 매핑
  static String getRawResourceName(String soundName) {
    switch (soundName) {
      case '자명종':
      case '자명종 (클래식 트윈벨)':
        return 'mechanical_clock';
      case '새소리':
      case '새소리 (상쾌한 아침)':
        return 'garden_birds';
      case '피아노':
      case '피아노 (포근한 선율)':
        return 'gentle_piano';
      case '디지털 알람':
      case '디지털 알람 (전자식 비프)':
      case '비프음':
        return 'electronic_alarm';
      case '클래식 벨':
      case '벨소리':
        return 'classic_bell';
      case '심플 비프':
      case '전자음':
        return 'digital_beep';
      case '마림바':
      case '마림바 (경쾌한 멜로디)':
      case '기본 알람':
      case '기본 알람 벨':
      default:
        return 'cheerful_marimba';
    }
  }

  /// 해당 사운드가 지정된 고유 알람 채널을 Android 시스템에 생성/확보
  Future<String> ensureAlarmChannel(String soundName) async {
    if (kIsWeb) return channelId;

    final rawSoundName = getRawResourceName(soundName);
    final specificChannelId = 'alarm_v3_$rawSoundName';

    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      final channel = AndroidNotificationChannel(
        specificChannelId,
        '10Alarm 실시간 알람 ($soundName)',
        description: '10Alarm 실시간 기상 알람 및 음원 채널',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(rawSoundName),
        audioAttributesUsage: AudioAttributesUsage.alarm,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
        enableLights: true,
      );
      await androidPlugin.createNotificationChannel(channel);
    }
    return specificChannelId;
  }

  // 알림 클릭 시 화면 전환을 위한 콜백
  void Function(String? payload)? onNotificationTap;

  Future<void> init() async {
    tz.initializeTimeZones();
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _notificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.actionId == 'dismiss_alarm') {
          if (response.id != null) {
            _notificationsPlugin.cancel(id: response.id!);
          }
          SoundService.instance.stopAlarm();
          return;
        }
        if (response.id != null) {
          _notificationsPlugin.cancel(id: response.id!);
        }
        SoundService.instance.stopAlarm();
        if (onNotificationTap != null) {
          onNotificationTap!(response.payload);
        }
      },
    );

    if (!kIsWeb) {
      // Android 알림 채널 생성
      final androidNotificationChannel = AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        showBadge: true,
      );

      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidNotificationChannel);
    }
  }

  // 메신저 스타일 푸시 알림 발송 (테스트 또는 알람 격발 시)
  Future<void> showCharacterAlarmNotification({
    required AlarmItem alarm,
    required CharacterProfile character,
    String? soundName,
  }) async {
    final int notifId = alarm.id.hashCode.abs();
    final selectedSound = soundName ?? ThemeService.instance.alarmSoundNotifier.value;
    final channelIdToUse = await ensureAlarmChannel(selectedSound);
    final rawSoundName = getRawResourceName(selectedSound);

    // 사운드 서비스 동시 발동 (앱 내부 오디오 엔진)
    SoundService.instance.startAlarmRinging(soundName: selectedSound);

    AndroidBitmap<Object>? avatarBitmap;
    if (!kIsWeb && character.avatarPath != null && File(character.avatarPath!).existsSync()) {
      avatarBitmap = FilePathAndroidBitmap(character.avatarPath!);
    }

    final resolvedMessage = MessageFormatter.format(alarm.message, character: character);

    final characterPerson = Person(
      name: character.name,
      icon: avatarBitmap != null ? BitmapFilePathAndroidIcon(character.avatarPath!) : null,
      key: character.id,
    );

    final messagingStyle = MessagingStyleInformation(
      characterPerson,
      conversationTitle: character.name,
      groupConversation: false,
      messages: [
        Message(
          resolvedMessage,
          DateTime.now(),
          characterPerson,
        ),
      ],
    );

    final androidDetails = AndroidNotificationDetails(
      channelIdToUse,
      '10Alarm 실시간 알람 ($selectedSound)',
      channelDescription: '10Alarm 실시간 기상 알람 및 음원 채널',
      importance: Importance.max,
      priority: Priority.max,
      ticker: '${character.name}: $resolvedMessage',
      styleInformation: messagingStyle,
      largeIcon: avatarBitmap,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      sound: RawResourceAndroidNotificationSound(rawSoundName),
      audioAttributesUsage: AudioAttributesUsage.alarm,
      additionalFlags: Int32List.fromList(<int>[4]), // FLAG_INSISTENT: 사용자가 끌 때까지 무한 반복 루프 울림
      actions: const [
        AndroidNotificationAction(
          'dismiss_alarm',
          '알람 끄기',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          'open_chat',
          '답장하기',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: '$rawSoundName.caf',
      subtitle: character.name,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // payload로 characterId와 alarmId 전달
    final payload = '${character.id}#${alarm.id}';

    // 푸시 알림 메시지를 캐릭터 채팅 기록에 반영 (알람 수신 메시지 보존)
    await StorageService.instance.saveChatMessage(
      ChatMessage(
        id: const Uuid().v4(),
        characterId: character.id,
        text: resolvedMessage,
        isMe: false,
        timestamp: DateTime.now(),
      ),
    );

    await _notificationsPlugin.show(
      id: notifId,
      title: character.name,
      body: resolvedMessage,
      notificationDetails: notificationDetails,
      payload: payload,
    );
  }

  // 뽀모도로, 스톱워치, 캘린더 등 다양한 기능에서 활용 가능한 범용 캐릭터 알림
  Future<void> showCharacterCustomNotification({
    required int id,
    required CharacterProfile character,
    required String message,
    String? title,
    String? payload,
  }) async {
    final resolvedMessage = MessageFormatter.format(message, character: character);

    // 푸시 알림 메시지를 캐릭터 채팅 기록에 반영
    await StorageService.instance.saveChatMessage(
      ChatMessage(
        id: const Uuid().v4(),
        characterId: character.id,
        text: resolvedMessage,
        isMe: false,
        timestamp: DateTime.now(),
      ),
    );

    AndroidBitmap<Object>? avatarBitmap;
    if (!kIsWeb && character.avatarPath != null && File(character.avatarPath!).existsSync()) {
      avatarBitmap = FilePathAndroidBitmap(character.avatarPath!);
    }

    final characterPerson = Person(
      name: character.name,
      icon: avatarBitmap != null ? BitmapFilePathAndroidIcon(character.avatarPath!) : null,
      key: character.id,
    );

    final messagingStyle = MessagingStyleInformation(
      characterPerson,
      conversationTitle: character.name,
      groupConversation: false,
      messages: [
        Message(
          resolvedMessage,
          DateTime.now(),
          characterPerson,
        ),
      ],
    );

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      ticker: '${character.name}: $resolvedMessage',
      styleInformation: messagingStyle,
      largeIcon: avatarBitmap,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      subtitle: character.name,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      id: id,
      title: title ?? character.name,
      body: resolvedMessage,
      notificationDetails: notificationDetails,
      payload: payload ?? '${character.id}#generic',
    );
  }

  // 순차적으로 도착하는 연속 대화 푸시 알림 (대화 시나리오)
  Future<void> showSequentialCharacterNotifications({
    required int baseId,
    required CharacterProfile character,
    required List<String> messages,
    int intervalSeconds = 2,
    String? payload,
  }) async {
    if (messages.isEmpty) return;

    final resolvedMessages = messages.map((m) => MessageFormatter.format(m, character: character)).toList();
    final List<Message> accumulatedMessages = [];

    for (int i = 0; i < resolvedMessages.length; i++) {
      final msgText = resolvedMessages[i];

      // 각 순차 메시지를 캐릭터 채팅 기록에 자동 반영
      await StorageService.instance.saveChatMessage(
        ChatMessage(
          id: const Uuid().v4(),
          characterId: character.id,
          text: msgText,
          isMe: false,
          timestamp: DateTime.now().add(Duration(seconds: i * intervalSeconds)),
        ),
      );

      AndroidBitmap<Object>? avatarBitmap;
      if (!kIsWeb && character.avatarPath != null && File(character.avatarPath!).existsSync()) {
        avatarBitmap = FilePathAndroidBitmap(character.avatarPath!);
      }

      final characterPerson = Person(
        name: character.name,
        icon: avatarBitmap != null ? BitmapFilePathAndroidIcon(character.avatarPath!) : null,
        key: character.id,
      );

      accumulatedMessages.add(Message(
        msgText,
        DateTime.now(),
        characterPerson,
      ));

      final messagingStyle = MessagingStyleInformation(
        characterPerson,
        conversationTitle: character.name,
        groupConversation: false,
        messages: List.from(accumulatedMessages),
      );

      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        ticker: '${character.name}: $msgText',
        styleInformation: messagingStyle,
        largeIcon: avatarBitmap,
        fullScreenIntent: i == 0,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
      );

      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        subtitle: character.name,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.show(
        id: baseId,
        title: character.name,
        body: msgText,
        notificationDetails: notificationDetails,
        payload: payload ?? '${character.id}#bundle',
      );

      if (i < resolvedMessages.length - 1) {
        await Future.delayed(Duration(seconds: intervalSeconds));
      }
    }
  }

  /// OS 최상위 알람 클록 (AlarmManager.setAlarmClock) 스케줄링
  /// 앱이 종료(Killed)되어도 안드로이드 OS가 정각에 기기를 깨워 알람을 울림
  Future<void> scheduleAlarmClockNotification({
    required int id,
    required DateTime scheduledDate,
    required CharacterProfile character,
    required String message,
    String? payload,
    String? soundName,
  }) async {
    if (kIsWeb) return;

    final selectedSound = soundName ?? ThemeService.instance.alarmSoundNotifier.value;
    final channelIdToUse = await ensureAlarmChannel(selectedSound);
    final rawSoundName = getRawResourceName(selectedSound);

    final tzDateTime = tz.TZDateTime.from(scheduledDate, tz.local);
    final resolvedMessage = MessageFormatter.format(message, character: character);

    AndroidBitmap<Object>? avatarBitmap;
    if (character.avatarPath != null && File(character.avatarPath!).existsSync()) {
      avatarBitmap = FilePathAndroidBitmap(character.avatarPath!);
    }

    final characterPerson = Person(
      name: character.name,
      icon: avatarBitmap != null ? BitmapFilePathAndroidIcon(character.avatarPath!) : null,
      key: character.id,
    );

    final messagingStyle = MessagingStyleInformation(
      characterPerson,
      conversationTitle: character.name,
      groupConversation: false,
      messages: [
        Message(
          resolvedMessage,
          scheduledDate,
          characterPerson,
        ),
      ],
    );

    final androidDetails = AndroidNotificationDetails(
      channelIdToUse,
      '10Alarm 실시간 알람 ($selectedSound)',
      channelDescription: '10Alarm 실시간 기상 알람 및 음원 채널',
      importance: Importance.max,
      priority: Priority.max,
      ticker: '${character.name}: $resolvedMessage',
      styleInformation: messagingStyle,
      largeIcon: avatarBitmap,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      sound: RawResourceAndroidNotificationSound(rawSoundName),
      audioAttributesUsage: AudioAttributesUsage.alarm,
      additionalFlags: Int32List.fromList(<int>[4]), // FLAG_INSISTENT: 사용자가 끌 때까지 무한 반복 루프 울림
      actions: const [
        AndroidNotificationAction(
          'dismiss_alarm',
          '알람 끄기',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          'open_chat',
          '답장하기',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: '$rawSoundName.caf',
      subtitle: character.name,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.zonedSchedule(
      id: id,
      title: character.name,
      body: resolvedMessage,
      scheduledDate: tzDateTime,
      notificationDetails: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      payload: payload,
    );
  }

  Future<void> cancelAlarmNotification(int notifId) async {
    await _notificationsPlugin.cancel(id: notifId);
    await SoundService.instance.stopAlarm();
  }

  Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }
}
