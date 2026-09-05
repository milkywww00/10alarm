import 'package:flutter_test/flutter_test.dart';
import 'package:fav_alarm/models/character_profile.dart';
import 'package:fav_alarm/models/alarm_item.dart';
import 'package:fav_alarm/models/pomodoro_config.dart';
import 'package:fav_alarm/models/stopwatch_config.dart';
import 'package:fav_alarm/models/schedule_item.dart';
import 'package:fav_alarm/models/message_bundle.dart';
import 'package:fav_alarm/models/chat_message.dart';
import 'package:fav_alarm/utils/message_formatter.dart';

void main() {
  group('CharacterProfile Model Tests', () {
    test('toMap and fromMap should correctly serialize and deserialize', () {
      final now = DateTime.now();
      final profile = CharacterProfile(
        id: 'test-1',
        name: '최애',
        avatarPath: '/path/to/avatar.png',
        title: '가수',
        aiPersonaPrompt: '다정하고 친근한 어투로 대답해줘.',
        isAiEnabled: false,
        aiRelationship: '연인',
        aiTone: '다정한 반말',
        aiGreeting: '오늘 하루 어땠어?',
        aiBackground: '서로를 아끼는 비밀 연인',
        aiDialogueExamples: '나: "피곤해"\n최애: "토닥토닥"',
        createdAt: now,
      );

      final map = profile.toMap();
      final reconstructed = CharacterProfile.fromMap(map);

      expect(reconstructed.id, equals('test-1'));
      expect(reconstructed.name, equals('최애'));
      expect(reconstructed.avatarPath, equals('/path/to/avatar.png'));
      expect(reconstructed.title, equals('가수'));
      expect(reconstructed.aiPersonaPrompt, equals('다정하고 친근한 어투로 대답해줘.'));
      expect(reconstructed.isAiEnabled, isFalse);
      expect(reconstructed.aiRelationship, equals('연인'));
      expect(reconstructed.aiTone, equals('다정한 반말'));
      expect(reconstructed.aiGreeting, equals('오늘 하루 어땠어?'));
      expect(reconstructed.aiBackground, equals('서로를 아끼는 비밀 연인'));
      expect(reconstructed.aiDialogueExamples, equals('나: "피곤해"\n최애: "토닥토닥"'));
    });

    test('default isAiEnabled should be true', () {
      final profile = CharacterProfile(
        id: 'test-2',
        name: '최애2',
        createdAt: DateTime.now(),
      );

      expect(profile.isAiEnabled, isTrue);
      final reconstructed = CharacterProfile.fromMap(profile.toMap());
      expect(reconstructed.isAiEnabled, isTrue);
    });
  });

  group('ChatMessage Model Tests', () {
    test('ChatMessage should serialize and deserialize correctly', () {
      final now = DateTime.now();
      final chat = ChatMessage(
        id: 'chat-1',
        characterId: 'char-1',
        text: '안녕 최애야!',
        isMe: true,
        timestamp: now,
      );

      final map = chat.toMap();
      final reconstructed = ChatMessage.fromMap(map);

      expect(reconstructed.id, equals('chat-1'));
      expect(reconstructed.characterId, equals('char-1'));
      expect(reconstructed.text, equals('안녕 최애야!'));
      expect(reconstructed.isMe, isTrue);
      expect(reconstructed.isError, isFalse);
    });
  });

  group('AlarmItem Model Tests', () {
    test('timeFormatted should format morning time correctly', () {
      final alarm = AlarmItem(
        id: 'alarm-1',
        characterId: 'test-1',
        hour: 7,
        minute: 5,
        message: '좋은 아침!',
        createdAt: DateTime.now(),
      );

      expect(alarm.timeFormatted, equals('오전 7:05'));
      expect(alarm.repeatDaysFormatted, equals('한 번만'));
    });

    test('timeFormatted should format afternoon time correctly', () {
      final alarm = AlarmItem(
        id: 'alarm-2',
        characterId: 'test-1',
        hour: 23,
        minute: 30,
        repeatDays: [1, 2, 3, 4, 5],
        message: '잘 자!',
        createdAt: DateTime.now(),
      );

      expect(alarm.timeFormatted, equals('오후 11:30'));
      expect(alarm.repeatDaysFormatted, equals('주중 (월~금)'));
    });
  });

  group('Pomodoro & Stopwatch & Schedule Model Tests', () {
    test('PomodoroConfig should serialize and deserialize correctly', () {
      final config = PomodoroConfig(
        focusMinutes: 30,
        breakMinutes: 10,
        characterId: 'char-1',
        focusEndMessage: '집중 끝!',
        breakEndMessage: '휴식 끝!',
      );

      final jsonStr = config.toJson();
      final reconstructed = PomodoroConfig.fromJson(jsonStr);

      expect(reconstructed.focusMinutes, equals(30));
      expect(reconstructed.breakMinutes, equals(10));
      expect(reconstructed.characterId, equals('char-1'));
      expect(reconstructed.focusEndMessage, equals('집중 끝!'));
    });

    test('StopwatchConfig should serialize and deserialize correctly', () {
      final config = StopwatchConfig(
        targetMinutes: 60,
        isTargetEnabled: true,
        characterId: 'char-2',
        targetReachedMessage: '1시간 돌파!',
      );

      final jsonStr = config.toJson();
      final reconstructed = StopwatchConfig.fromJson(jsonStr);

      expect(reconstructed.targetMinutes, equals(60));
      expect(reconstructed.isTargetEnabled, isTrue);
      expect(reconstructed.characterId, equals('char-2'));
    });

    test('ScheduleItem should format date and time correctly', () {
      final schedule = ScheduleItem(
        id: 'sched-1',
        title: '팬미팅',
        year: 2026,
        month: 12,
        day: 25,
        hour: 14,
        minute: 0,
        characterId: 'char-1',
        message: '오늘 팬미팅 날이야!',
        createdAt: DateTime.now(),
      );

      expect(schedule.dateFormatted, equals('2026.12.25'));
      expect(schedule.timeFormatted, equals('오후 2:00'));
    });
  });

  group('MessageBundle & BundleId Tests', () {
    test('MessageBundle should serialize and deserialize correctly', () {
      final now = DateTime.now();
      final bundle = MessageBundle(
        id: 'bundle-1',
        characterId: 'char-1',
        title: '기상 시나리오',
        messages: ['일어났어?', '얼른 일어나~', '늦잠 자면 안 돼!'],
        intervalSeconds: 3,
        createdAt: now,
      );

      final map = bundle.toMap();
      final reconstructed = MessageBundle.fromMap(map);

      expect(reconstructed.id, equals('bundle-1'));
      expect(reconstructed.title, equals('기상 시나리오'));
      expect(reconstructed.messages.length, equals(3));
      expect(reconstructed.messages[0], equals('일어났어?'));
      expect(reconstructed.intervalSeconds, equals(3));
    });

    test('AlarmItem should support bundleId with RANDOM and custom IDs', () {
      final alarmRandom = AlarmItem(
        id: 'alarm-rand',
        characterId: 'char-1',
        hour: 8,
        minute: 0,
        bundleId: 'RANDOM',
        message: '랜덤 알람',
        createdAt: DateTime.now(),
      );

      final alarmSpecific = AlarmItem(
        id: 'alarm-spec',
        characterId: 'char-1',
        hour: 8,
        minute: 30,
        bundleId: 'bundle-123',
        message: '특정 묶음 알람',
        createdAt: DateTime.now(),
      );

      expect(alarmRandom.bundleId, equals('RANDOM'));
      expect(alarmSpecific.bundleId, equals('bundle-123'));

      final map = alarmRandom.toMap();
      final reconstructed = AlarmItem.fromMap(map);
      expect(reconstructed.bundleId, equals('RANDOM'));

      // Test RANDOM with specific subset of scenario IDs
      final alarmSelectedRandom = AlarmItem(
        id: 'alarm-rand-subset',
        characterId: 'char-1',
        hour: 9,
        minute: 0,
        bundleId: 'RANDOM:bundle-1,bundle-2',
        message: '선택 랜덤 알람',
        createdAt: DateTime.now(),
      );
      final subsetMap = alarmSelectedRandom.toMap();
      final subsetReconstructed = AlarmItem.fromMap(subsetMap);
      expect(subsetReconstructed.bundleId, equals('RANDOM:bundle-1,bundle-2'));
      expect(subsetReconstructed.bundleId!.startsWith('RANDOM:'), isTrue);
      final targetIds = subsetReconstructed.bundleId!.replaceFirst('RANDOM:', '').split(',');
      expect(targetIds, equals(['bundle-1', 'bundle-2']));
    });

    test('ScheduleItem, StopwatchConfig, PomodoroConfig should support bundleId serialization', () {
      final schedule = ScheduleItem(
        id: 's-1',
        title: '데이트',
        year: 2026,
        month: 10,
        day: 1,
        hour: 15,
        minute: 0,
        characterId: 'c-1',
        message: '데이트 날이야',
        bundleId: 'bundle-schedule',
        createdAt: DateTime.now(),
      );
      final sMap = schedule.toMap();
      final sRecon = ScheduleItem.fromMap(sMap);
      expect(sRecon.bundleId, equals('bundle-schedule'));

      final stopwatch = StopwatchConfig(
        targetMinutes: 45,
        isTargetEnabled: true,
        bundleId: 'RANDOM',
      );
      final swJson = stopwatch.toJson();
      final swRecon = StopwatchConfig.fromJson(swJson);
      expect(swRecon.targetMinutes, equals(45));
      expect(swRecon.bundleId, equals('RANDOM'));

      final pomodoro = PomodoroConfig(
        focusMinutes: 25,
        breakMinutes: 5,
        focusBundleId: 'bundle-focus',
        breakBundleId: 'RANDOM',
      );
      final pomoJson = pomodoro.toJson();
      final pomoRecon = PomodoroConfig.fromJson(pomoJson);
      expect(pomoRecon.focusBundleId, equals('bundle-focus'));
      expect(pomoRecon.breakBundleId, equals('RANDOM'));
    });
  });

  group('MessageFormatter & Character Title Tests', () {
    test('MessageFormatter replaces {호칭}, {이름}, {일정}, {시간} properly', () {
      final char = CharacterProfile(
        id: 'c1',
        name: '카즈하',
        title: '선배',
        defaultCalendarMessage: '{호칭}, 오늘 {일정} 있는 날이야!',
        createdAt: DateTime.now(),
      );

      expect(char.defaultCalendarMessage, isNotNull);

      // 호칭 치환
      final msg1 = MessageFormatter.format('좋은 아침, {호칭}!', character: char);
      expect(msg1, equals('좋은 아침, 선배!'));

      // 이름 치환
      final msg2 = MessageFormatter.format('{이름}이가 응원해, {호칭}!', character: char);
      expect(msg2, equals('카즈하이가 응원해, 선배!'));

      // 일정 치환
      final msg3 = MessageFormatter.format(char.defaultCalendarMessage!, character: char, scheduleTitle: '중요한 미팅');
      expect(msg3, equals('선배, 오늘 중요한 미팅 있는 날이야!'));

      // 호칭이 없는 경우 공백 처리
      final charNoTitle = CharacterProfile(
        id: 'c2',
        name: '아이유',
        createdAt: DateTime.now(),
      );
      final msg4 = MessageFormatter.format('안녕 {호칭}! 반가워', character: charNoTitle);
      expect(msg4, equals('안녕! 반가워'));
    });
  });

  group('AI_AUTO Bundle ID Configuration Tests', () {
    test('AlarmItem correctly holds and serializes AI_AUTO bundleId', () {
      final alarm = AlarmItem(
        id: 'alarm-ai-1',
        characterId: 'char-1',
        hour: 8,
        minute: 0,
        message: '좋은 아침',
        bundleId: 'AI_AUTO',
        createdAt: DateTime.now(),
      );

      final map = alarm.toMap();
      final recon = AlarmItem.fromMap(map);
      expect(recon.bundleId, equals('AI_AUTO'));
    });

    test('ScheduleItem correctly holds and serializes AI_AUTO bundleId', () {
      final schedule = ScheduleItem(
        id: 'sch-ai-1',
        characterId: 'char-1',
        title: '데이트',
        year: 2026,
        month: 9,
        day: 10,
        hour: 14,
        minute: 30,
        message: '데이트 준비해!',
        bundleId: 'AI_AUTO',
        createdAt: DateTime.now(),
      );

      final map = schedule.toMap();
      final recon = ScheduleItem.fromMap(map);
      expect(recon.bundleId, equals('AI_AUTO'));
    });

    test('StopwatchConfig correctly holds and serializes AI_AUTO bundleId', () {
      final config = StopwatchConfig(
        targetMinutes: 20,
        bundleId: 'AI_AUTO',
      );

      final jsonStr = config.toJson();
      final recon = StopwatchConfig.fromJson(jsonStr);
      expect(recon.bundleId, equals('AI_AUTO'));
    });

    test('PomodoroConfig correctly holds and serializes AI_AUTO bundleId', () {
      final config = PomodoroConfig(
        focusMinutes: 25,
        breakMinutes: 5,
        focusBundleId: 'AI_AUTO',
        breakBundleId: 'AI_AUTO',
      );

      final jsonStr = config.toJson();
      final recon = PomodoroConfig.fromJson(jsonStr);
      expect(recon.focusBundleId, equals('AI_AUTO'));
      expect(recon.breakBundleId, equals('AI_AUTO'));
    });

    test('ChatMessage.fromMap safely handles null or missing fields', () {
      final safeMsg = ChatMessage.fromMap({
        'id': null,
        'characterId': null,
        'text': null,
        'isMe': null,
        'timestamp': null,
        'isError': null,
      });

      expect(safeMsg.id.isNotEmpty, isTrue);
      expect(safeMsg.characterId, equals(''));
      expect(safeMsg.text, equals(''));
      expect(safeMsg.isMe, isFalse);
      expect(safeMsg.isError, isFalse);
      expect(safeMsg.timestamp, isNotNull);
    });
  });
}
