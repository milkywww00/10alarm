import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fav_alarm/main.dart';
import 'package:fav_alarm/models/character_profile.dart';
import 'package:fav_alarm/models/chat_message.dart';
import 'package:fav_alarm/screens/chat_list_screen.dart';
import 'package:fav_alarm/services/storage_service.dart';
import 'package:fav_alarm/widgets/message_mode_selector.dart';

void main() {
  testWidgets('App smoke test loads TenAlarmApp', (WidgetTester tester) async {
    await tester.pumpWidget(const TenAlarmApp());
    expect(find.byType(TenAlarmApp), findsOneWidget);
  });

  testWidgets('MessageModeSelector in AI mode does NOT show scenario missing warning', (WidgetTester tester) async {
    final char = CharacterProfile(
      id: 'c1',
      name: '테스트캐릭터',
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageModeSelector(
            label: '알림 메시지 설정',
            currentMode: 'AI',
            onModeChanged: (_) {},
            messageController: TextEditingController(),
            hint: '기본 힌트',
            character: char,
            bundles: const [],
            selectedBundleId: null,
            onBundleSelected: (_) {},
          ),
        ),
      ),
    );

    // AI 맞춤 생성 알림 카드가 노출되어야 함
    expect(find.text('AI 맞춤 생성 알림'), findsOneWidget);

    // 시나리오 관련 경고문은 절대로 노출되지 않아야 함
    expect(find.textContaining('등록된 대화 시나리오가 없습니다'), findsNothing);
  });

  testWidgets('MessageModeSelector in BUNDLE mode with no bundles shows scenario missing warning', (WidgetTester tester) async {
    final char = CharacterProfile(
      id: 'c1',
      name: '테스트캐릭터',
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageModeSelector(
            label: '알림 메시지 설정',
            currentMode: 'BUNDLE',
            onModeChanged: (_) {},
            messageController: TextEditingController(),
            hint: '기본 힌트',
            character: char,
            bundles: const [],
            selectedBundleId: null,
            onBundleSelected: (_) {},
          ),
        ),
      ),
    );

    // BUNDLE 모드에서는 시나리오가 없을 때 경고문 노출
    expect(find.textContaining('등록된 대화 시나리오가 없습니다'), findsOneWidget);
  });

  testWidgets('ChatListScreen loads empty state without error', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ChatListScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(ErrorWidget), findsNothing);
    expect(find.text('메시지 대화'), findsOneWidget);
  });

  testWidgets('ChatListScreen with character and message renders without ErrorWidget', (WidgetTester tester) async {
    final char = CharacterProfile(
      id: 'char_test_1',
      name: '홍길동',
      title: '친구',
      aiRelationship: '소꿉친구',
      createdAt: DateTime.now(),
    );
    await StorageService.instance.saveCharacter(char);

    final msg = ChatMessage(
      id: 'msg_1',
      characterId: 'char_test_1',
      text: '안녕! 잘 잤어?',
      isMe: false,
      timestamp: DateTime.now(),
    );
    await StorageService.instance.saveChatMessage(msg);

    await tester.pumpWidget(
      const MaterialApp(
        home: ChatListScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(ErrorWidget), findsNothing);
    expect(find.text('메시지 대화'), findsOneWidget);
    expect(find.text('홍길동'), findsOneWidget);
    expect(find.text('안녕! 잘 잤어?'), findsOneWidget);
  });
}

