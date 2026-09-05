import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:uuid/uuid.dart';
import '../models/alarm_item.dart';
import '../models/character_profile.dart';
import '../models/chat_message.dart';
import '../utils/message_formatter.dart';
import 'storage_service.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String channelId = 'fav_alarm_channel';
  static const String channelName = '최애 알람 채널';
  static const String channelDescription = '설정한 캐릭터의 가상 메시지 알람 알림입니다.';

  // 알림 클릭 시 화면 전환을 위한 콜백
  void Function(String? payload)? onNotificationTap;

  Future<void> init() async {
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
  }) async {
    final int notifId = alarm.id.hashCode.abs();

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

    // payload로 characterId와 alarmId 전달
    final payload = '${character.id}#${alarm.id}';

    // 푸시 알림 메시지를 캐릭터 채팅 기록에 자동 반영
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

    // 푸시 알림 메시지를 캐릭터 채팅 기록에 자동 반영
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

  Future<void> cancelAlarmNotification(int notifId) async {
    await _notificationsPlugin.cancel(id: notifId);
  }

  Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }
}
