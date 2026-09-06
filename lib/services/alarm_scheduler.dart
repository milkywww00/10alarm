import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/alarm_item.dart';
import '../models/character_profile.dart';
import '../models/schedule_item.dart';
import '../models/message_bundle.dart';
import '../utils/message_formatter.dart';
import '../main.dart';
import '../screens/alarm_ring_screen.dart';
import 'storage_service.dart';
import 'notification_service.dart';
import 'ai_chat_service.dart';

import 'sound_service.dart';
import 'theme_service.dart';

// 안드로이드 백그라운드 격발을 위한 최상위 콜백 함수
@pragma('vm:entry-point')
void alarmFireCallback(int idHash) async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  await ThemeService.instance.init();

  // 1. 알람 확인
  final alarms = await StorageService.instance.getAlarms();
  final matchedAlarms = alarms.where((a) => a.id.hashCode.abs() == idHash).toList();
  if (matchedAlarms.isNotEmpty) {
    final alarm = matchedAlarms.first;
    if (alarm.isEnabled) {
      // 실제 알람 사운드 울림 시작
      await SoundService.instance.startAlarmRinging();

      final character = await StorageService.instance.getCharacterById(alarm.characterId);
      if (character != null) {
        List<String> burstMessages = [];
        int intervalSeconds = 2;

        if (alarm.bundleId == 'AI_AUTO') {
          final aiMsg = await AiChatService.instance.generateNotificationMessage(
            character: character,
            notificationType: '기상 모닝콜 알람',
          );
          await NotificationService.instance.showCharacterAlarmNotification(
            alarm: alarm.copyWith(message: aiMsg),
            character: character,
          );
        } else {
          if (alarm.bundleId != null && alarm.bundleId!.isNotEmpty) {
            final bundles = await StorageService.instance.getMessageBundlesByCharacter(character.id);
            if (alarm.bundleId == 'RANDOM' || alarm.bundleId!.startsWith('RANDOM:')) {
              List<MessageBundle> pool = bundles;
              if (alarm.bundleId!.startsWith('RANDOM:')) {
                final ids = alarm.bundleId!.substring(7).split(',').where((s) => s.isNotEmpty).toSet();
                final filtered = bundles.where((b) => ids.contains(b.id)).toList();
                if (filtered.isNotEmpty) pool = filtered;
              }
              if (pool.isNotEmpty) {
                final picked = pool[Random().nextInt(pool.length)];
                burstMessages = picked.messages;
                intervalSeconds = picked.intervalSeconds;
              }
            } else {
              final matched = bundles.where((b) => b.id == alarm.bundleId).toList();
              if (matched.isNotEmpty) {
                burstMessages = matched.first.messages;
                intervalSeconds = matched.first.intervalSeconds;
              }
            }
          }

          if (burstMessages.isNotEmpty) {
            await NotificationService.instance.showSequentialCharacterNotifications(
              baseId: idHash,
              character: character,
              messages: burstMessages,
              intervalSeconds: intervalSeconds,
              payload: '${character.id}#bundle_${alarm.id}',
            );
          } else {
            final effectiveMessage = (alarm.message.isNotEmpty && !alarm.message.startsWith('['))
                ? alarm.message
                : (character.defaultMorningMessage?.isNotEmpty == true
                    ? character.defaultMorningMessage!
                    : '좋은 아침이야, {호칭}! 오늘도 힘차게 시작해볼까?');
            await NotificationService.instance.showCharacterAlarmNotification(
              alarm: alarm.copyWith(message: effectiveMessage),
              character: character,
            );
          }
        }

        if (alarm.repeatDays.isNotEmpty) {
          AlarmScheduler.instance.scheduleAlarm(alarm);
        }
      }
    }
    return;
  }

  // 2. 캘린더 일정 확인
  final schedules = await StorageService.instance.getSchedules();
  final matchedSchedules = schedules.where((s) => s.id.hashCode.abs() == idHash).toList();
  if (matchedSchedules.isNotEmpty) {
    final schedule = matchedSchedules.first;
    if (!schedule.isCompleted) {
      final character = await StorageService.instance.getCharacterById(schedule.characterId);
      if (character != null) {
        List<String> burstMessages = [];
        int intervalSeconds = 2;

        if (schedule.bundleId == 'AI_AUTO') {
          final aiMsg = await AiChatService.instance.generateNotificationMessage(
            character: character,
            notificationType: '캘린더 일정 알림',
            detail: schedule.title,
          );
          await NotificationService.instance.showCharacterCustomNotification(
            id: idHash,
            character: character,
            message: aiMsg,
            title: '[일정] ${schedule.title}',
            payload: '${character.id}#schedule_${schedule.id}',
          );
        } else {
          if (schedule.bundleId != null && schedule.bundleId!.isNotEmpty) {
            final bundles = await StorageService.instance.getMessageBundlesByCharacter(character.id);
            if (schedule.bundleId == 'RANDOM' || schedule.bundleId!.startsWith('RANDOM:')) {
              List<MessageBundle> pool = bundles;
              if (schedule.bundleId!.startsWith('RANDOM:')) {
                final ids = schedule.bundleId!.substring(7).split(',').where((s) => s.isNotEmpty).toSet();
                final filtered = bundles.where((b) => ids.contains(b.id)).toList();
                if (filtered.isNotEmpty) pool = filtered;
              }
              if (pool.isNotEmpty) {
                final picked = pool[Random().nextInt(pool.length)];
                burstMessages = picked.messages;
                intervalSeconds = picked.intervalSeconds;
              }
            } else {
              final matched = bundles.where((b) => b.id == schedule.bundleId).toList();
              if (matched.isNotEmpty) {
                burstMessages = matched.first.messages;
                intervalSeconds = matched.first.intervalSeconds;
              }
            }
          }

          if (burstMessages.isNotEmpty) {
            final resolvedBurst = burstMessages
                .map((m) => MessageFormatter.format(m, character: character, scheduleTitle: schedule.title))
                .toList();
            await NotificationService.instance.showSequentialCharacterNotifications(
              baseId: idHash,
              character: character,
              messages: resolvedBurst,
              intervalSeconds: intervalSeconds,
              payload: '${character.id}#schedule_bundle_${schedule.id}',
            );
          } else {
            String msg = (character.defaultCalendarMessage?.isNotEmpty == true)
                ? character.defaultCalendarMessage!
                : (schedule.message.isNotEmpty ? schedule.message : '[일정 알림] {일정}');
            final resolvedMsg = MessageFormatter.format(msg, character: character, scheduleTitle: schedule.title);

            await NotificationService.instance.showCharacterCustomNotification(
              id: idHash,
              character: character,
              message: resolvedMsg,
              title: '[일정] ${schedule.title}',
              payload: '${character.id}#schedule_${schedule.id}',
            );
          }
        }
      }
    }
  }
}

class AlarmScheduler {
  static final AlarmScheduler instance = AlarmScheduler._();
  AlarmScheduler._();

  Timer? _foregroundTicker;
  String? _lastTriggeredMinute;

  Future<void> init() async {
    if (!kIsWeb && Platform.isAndroid) {
      await AndroidAlarmManager.initialize();
    }
    _startForegroundTicker();
  }

  /// 앱이 켜져있을 때(포그라운드) 정각에 알람 화면과 사운드를 즉시 작동시키는 실시간 타이머
  void _startForegroundTicker() {
    _foregroundTicker?.cancel();
    _foregroundTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      _checkForegroundTriggers();
    });
  }

  Future<void> _checkForegroundTriggers() async {
    final now = DateTime.now();
    final minuteKey = '${now.year}-${now.month}-${now.day} ${now.hour}:${now.minute}';
    if (_lastTriggeredMinute == minuteKey) return;

    // 1. 활성화된 알람 체크
    final alarms = await StorageService.instance.getAlarms();
    for (final alarm in alarms) {
      if (!alarm.isEnabled) continue;
      if (alarm.hour == now.hour && alarm.minute == now.minute) {
        if (alarm.repeatDays.isEmpty || alarm.repeatDays.contains(now.weekday)) {
          _lastTriggeredMinute = minuteKey;
          await _triggerForegroundAlarm(alarm);
          return;
        }
      }
    }
  }

  Future<void> _triggerForegroundAlarm(AlarmItem alarm) async {
    final character = await StorageService.instance.getCharacterById(alarm.characterId);
    if (character == null) return;

    final effectiveMessage = (alarm.message.isNotEmpty && !alarm.message.startsWith('['))
        ? alarm.message
        : (character.defaultMorningMessage?.isNotEmpty == true
            ? character.defaultMorningMessage!
            : '좋은 아침이야, {호칭}! 오늘도 힘차게 시작해볼까?');

    // 1. 알람 화면(AlarmRingScreen)을 화면 최상단에 자동으로 즉각 전환 & 알람 사운드 무한 루프 울림
    final navContext = navigatorKey.currentContext;
    if (navContext != null) {
      Navigator.push(
        navContext,
        MaterialPageRoute(
          builder: (_) => AlarmRingScreen(
            character: character,
            alarm: alarm,
            message: effectiveMessage,
          ),
        ),
      );
    } else {
      SoundService.instance.startAlarmRinging();
    }

    // 2. 캐릭터의 푸시 알림은 알람 울림과 '완전히 별개'로 상태바/채팅에 전송
    await NotificationService.instance.showCharacterAlarmNotification(
      alarm: alarm,
      character: character,
      soundName: ThemeService.instance.alarmSoundNotifier.value,
    );
  }

  // 다음 알람 실행 일시 계산
  DateTime calculateNextTriggerTime(int hour, int minute, List<int> repeatDays) {
    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, hour, minute);

    if (repeatDays.isEmpty) {
      // 1회성 알람: 오늘 설정 시각이 이미 지났다면 내일로 예약
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
      return scheduled;
    }

    // 요일 반복 알람 (1=월, 7=일)
    for (int i = 0; i < 7; i++) {
      final candidate = DateTime(now.year, now.month, now.day, hour, minute).add(Duration(days: i));
      if (candidate.isAfter(now) && repeatDays.contains(candidate.weekday)) {
        return candidate;
      }
    }

    return scheduled.add(const Duration(days: 7));
  }

  Future<void> scheduleAlarm(AlarmItem alarm) async {
    if (!alarm.isEnabled) return;

    final int alarmCode = alarm.id.hashCode.abs();
    final nextTime = calculateNextTriggerTime(alarm.hour, alarm.minute, alarm.repeatDays);

    final character = await StorageService.instance.getCharacterById(alarm.characterId);
    if (character != null) {
      final effectiveMessage = (alarm.message.isNotEmpty && !alarm.message.startsWith('['))
          ? alarm.message
          : (character.defaultMorningMessage?.isNotEmpty == true
              ? character.defaultMorningMessage!
              : '좋은 아침이야, {호칭}! 오늘도 힘차게 시작해볼까?');

      // 1. Android OS 최상위 알람 클록 등록 (AlarmManager.setAlarmClock)
      // 앱이 완전히 종료(Killed)되거나 Doze 절전 모드 상태여도 OS가 100% 화면을 깨우고 알람 울림
      await NotificationService.instance.scheduleAlarmClockNotification(
        id: alarmCode,
        scheduledDate: nextTime,
        character: character,
        message: effectiveMessage,
        payload: '${character.id}#${alarm.id}',
        soundName: ThemeService.instance.alarmSoundNotifier.value,
      );
    }

    // 2. 백그라운드 오디오 엔진 동시 격발
    if (!kIsWeb && Platform.isAndroid) {
      await AndroidAlarmManager.oneShotAt(
        nextTime,
        alarmCode,
        alarmFireCallback,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
        allowWhileIdle: true,
      );
    }
  }

  Future<void> cancelAlarm(AlarmItem alarm) async {
    final int alarmCode = alarm.id.hashCode.abs();
    if (!kIsWeb && Platform.isAndroid) {
      await AndroidAlarmManager.cancel(alarmCode);
    }
    await NotificationService.instance.cancelAlarmNotification(alarmCode);
  }

  // 캘린더 일정 알람 스케줄링
  Future<void> scheduleScheduleReminder(ScheduleItem schedule) async {
    if (schedule.isCompleted) return;

    final targetTime = schedule.scheduledDateTime;
    if (targetTime.isBefore(DateTime.now())) return;

    final int scheduleCode = schedule.id.hashCode.abs();
    if (!kIsWeb && Platform.isAndroid) {
      await AndroidAlarmManager.oneShotAt(
        targetTime,
        scheduleCode,
        alarmFireCallback,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
        allowWhileIdle: true,
      );
    }
  }

  Future<void> cancelScheduleReminder(ScheduleItem schedule) async {
    final int scheduleCode = schedule.id.hashCode.abs();
    if (!kIsWeb && Platform.isAndroid) {
      await AndroidAlarmManager.cancel(scheduleCode);
    }
    await NotificationService.instance.cancelAlarmNotification(scheduleCode);
  }

  // 즉시 테스트 발송 (미리보기)
  Future<void> triggerPreview(AlarmItem alarm, CharacterProfile character) async {
    if (alarm.bundleId == 'AI_AUTO') {
      final aiMsg = await AiChatService.instance.generateNotificationMessage(
        character: character,
        notificationType: '기상 모닝콜 알람',
      );
      await NotificationService.instance.showCharacterAlarmNotification(
        alarm: alarm.copyWith(message: aiMsg),
        character: character,
      );
      return;
    }

    List<String> burstMessages = [];
    int intervalSeconds = 2;

    if (alarm.bundleId != null && alarm.bundleId!.isNotEmpty) {
      final bundles = await StorageService.instance.getMessageBundlesByCharacter(character.id);
      if (alarm.bundleId == 'RANDOM') {
        if (bundles.isNotEmpty) {
          final picked = bundles[Random().nextInt(bundles.length)];
          burstMessages = picked.messages;
          intervalSeconds = picked.intervalSeconds;
        }
      } else {
        final matched = bundles.where((b) => b.id == alarm.bundleId).toList();
        if (matched.isNotEmpty) {
          burstMessages = matched.first.messages;
          intervalSeconds = matched.first.intervalSeconds;
        }
      }
    }

    if (burstMessages.isNotEmpty) {
      await NotificationService.instance.showSequentialCharacterNotifications(
        baseId: alarm.id.hashCode.abs(),
        character: character,
        messages: burstMessages,
        intervalSeconds: intervalSeconds,
        payload: '${character.id}#bundle_${alarm.id}',
      );
    } else {
      final effectiveMessage = (alarm.message.isNotEmpty && !alarm.message.startsWith('['))
          ? alarm.message
          : (character.defaultMorningMessage?.isNotEmpty == true
              ? character.defaultMorningMessage!
              : '좋은 아침이야, {호칭}! 오늘도 힘차게 시작해볼까?');
      await NotificationService.instance.showCharacterAlarmNotification(
        alarm: alarm.copyWith(message: effectiveMessage),
        character: character,
      );
    }
  }
}
