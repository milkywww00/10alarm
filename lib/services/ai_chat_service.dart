import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/character_profile.dart';
import '../models/chat_message.dart';
import 'storage_service.dart';

class AiChatService {
  static final AiChatService instance = AiChatService._();
  AiChatService._();

  static const String _keyAiEnabled = 'ai_enabled_v1';
  static const String _keyProvider = 'ai_provider_v1';
  static const String _keyGeminiKey = 'ai_gemini_key_v1';
  static const String _keyOpenaiKey = 'ai_openai_key_v1';
  static const String _keyClaudeKey = 'ai_claude_key_v1';
  static const String _keyGeminiModel = 'ai_gemini_model_v1';

  final ValueNotifier<bool> isAiEnabledNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<String> providerNotifier = ValueNotifier<String>('gemini');
  final ValueNotifier<String> geminiKeyNotifier = ValueNotifier<String>('');
  final ValueNotifier<String> openaiKeyNotifier = ValueNotifier<String>('');
  final ValueNotifier<String> claudeKeyNotifier = ValueNotifier<String>('');
  final ValueNotifier<String> geminiModelNotifier = ValueNotifier<String>('auto');

  String get currentApiKey {
    if (providerNotifier.value == 'openai') {
      return openaiKeyNotifier.value.trim();
    } else if (providerNotifier.value == 'claude') {
      return claudeKeyNotifier.value.trim();
    }
    return geminiKeyNotifier.value.trim();
  }

  bool get isConfigured => currentApiKey.isNotEmpty;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    isAiEnabledNotifier.value = prefs.getBool(_keyAiEnabled) ?? true;
    providerNotifier.value = prefs.getString(_keyProvider) ?? 'gemini';
    geminiKeyNotifier.value = prefs.getString(_keyGeminiKey) ?? '';
    openaiKeyNotifier.value = prefs.getString(_keyOpenaiKey) ?? '';
    claudeKeyNotifier.value = prefs.getString(_keyClaudeKey) ?? '';
    geminiModelNotifier.value = prefs.getString(_keyGeminiModel) ?? 'auto';
  }

  Future<void> setAiEnabled(bool enabled) async {
    isAiEnabledNotifier.value = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAiEnabled, enabled);
  }

  Future<void> setProvider(String provider) async {
    providerNotifier.value = provider;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyProvider, provider);
  }

  Future<void> setGeminiModel(String model) async {
    geminiModelNotifier.value = model;
    _cachedGeminiModel = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGeminiModel, model);
  }

  Future<void> setGeminiKey(String key) async {
    final clean = key.trim();
    geminiKeyNotifier.value = clean;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGeminiKey, clean);
  }

  Future<void> setOpenaiKey(String key) async {
    final clean = key.trim();
    openaiKeyNotifier.value = clean;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyOpenaiKey, clean);
  }

  Future<void> setClaudeKey(String key) async {
    final clean = key.trim();
    claudeKeyNotifier.value = clean;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyClaudeKey, clean);
  }

  // API 연결 테스트 함수
  Future<Map<String, dynamic>> testConnection({
    required String provider,
    required String apiKey,
  }) async {
    final key = apiKey.trim();
    if (key.isEmpty) {
      return {'success': false, 'message': 'API 키를 입력해주세요.'};
    }

    try {
      if (provider == 'gemini') {
        _cachedGeminiModel = null;
        final model = await _resolveGeminiModel(key);
        return {
          'success': true,
          'message': 'Google Gemini API 연결 성공! (활성 모델: $model)',
        };
      } else if (provider == 'openai') {
        // OpenAI
        final url = Uri.parse('https://api.openai.com/v1/chat/completions');
        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $key',
          },
          body: jsonEncode({
            'model': 'gpt-4o-mini',
            'messages': [
              {'role': 'user', 'content': 'Hello'}
            ],
            'max_tokens': 10,
          }),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          return {'success': true, 'message': 'OpenAI API 연결 성공!'};
        } else {
          final errBody = jsonDecode(utf8.decode(response.bodyBytes));
          final errMsg = errBody['error']?['message'] ?? '응답 코드 ${response.statusCode}';
          return {'success': false, 'message': '연결 실패: $errMsg'};
        }
      } else {
        // Claude
        final url = Uri.parse('https://api.anthropic.com/v1/messages');
        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': key,
            'anthropic-version': '2023-06-01',
            'anthropic-dangerous-direct-browser-access': 'true',
          },
          body: jsonEncode({
            'model': 'claude-3-5-haiku-20241022',
            'messages': [
              {'role': 'user', 'content': 'Hello'}
            ],
            'max_tokens': 10,
          }),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          return {'success': true, 'message': 'Anthropic Claude API 연결 성공!'};
        } else {
          final errBody = jsonDecode(utf8.decode(response.bodyBytes));
          final errMsg = errBody['error']?['message'] ?? '응답 코드 ${response.statusCode}';
          return {'success': false, 'message': '연결 실패: $errMsg'};
        }
      }
    } catch (e) {
      if (kIsWeb) {
        return {
          'success': false,
          'message': '웹 브라우저 보안 정책(CORS)으로 인해 브라우저에서는 AI API 직접 호출이 차단됩니다. 스마트폰 앱(APK)에서는 제한 없이 100% 정상 연결 및 작동합니다.',
        };
      }
      return {'success': false, 'message': '네트워크 오류: $e'};
    }
  }

  // 캐릭터 종합 시스템 프롬프트 생성 (호칭, 이름, 페르소나, 실제 알람/일정/시간관리/현재시각 주입)
  Future<String> buildSystemPrompt({
    required CharacterProfile character,
    String? contextInfo,
  }) async {
    final userTitle = (character.title != null && character.title!.trim().isNotEmpty)
        ? character.title!.trim()
        : '사용자';

    final relationship = (character.aiRelationship != null && character.aiRelationship!.trim().isNotEmpty)
        ? character.aiRelationship!.trim()
        : '친근한 사이';

    final tone = (character.aiTone != null && character.aiTone!.trim().isNotEmpty)
        ? character.aiTone!.trim()
        : '다정하고 친근한 어조';

    final background = (character.aiBackground != null && character.aiBackground!.trim().isNotEmpty)
        ? character.aiBackground!.trim()
        : '';

    final customPrompt = (character.aiPersonaPrompt != null && character.aiPersonaPrompt!.trim().isNotEmpty)
        ? character.aiPersonaPrompt!.trim()
        : '다정하고 따뜻하게 대답해줘. 친근한 어투를 사용해.';

    final dialogueExamples = (character.aiDialogueExamples != null && character.aiDialogueExamples!.trim().isNotEmpty)
        ? character.aiDialogueExamples!.trim()
        : '';

    // 실제 등록된 알람, 일정, 시간관리 정보 조회
    final alarms = await StorageService.instance.getAlarms();
    final characterAlarms = alarms.where((a) => a.characterId == character.id).toList();

    final schedules = await StorageService.instance.getSchedules();
    final characterSchedules = schedules.where((s) => s.characterId == character.id && !s.isCompleted).toList();

    final pomodoro = await StorageService.instance.getPomodoroConfig();
    final stopwatch = await StorageService.instance.getStopwatchConfig();

    String alarmSummary = '설정된 알람 없음';
    if (characterAlarms.isNotEmpty) {
      alarmSummary = characterAlarms.map((a) {
        final repeat = a.repeatDaysFormatted;
        final status = a.isEnabled ? '활성화됨' : '꺼짐';
        return '• ${a.timeFormatted} ($repeat, $status) - 기본 문구: "${a.message}"';
      }).join('\n');
    }

    String scheduleSummary = '예정된 일정 없음';
    if (characterSchedules.isNotEmpty) {
      scheduleSummary = characterSchedules.take(5).map((s) {
        return '• ${s.dateFormatted} ${s.timeFormatted}: "${s.title}" (메시지: "${s.message}")';
      }).join('\n');
    }

    final now = DateTime.now();
    final weekdays = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];
    final weekdayStr = weekdays[now.weekday - 1];
    final currentTimeStr = '${now.year}년 ${now.month}월 ${now.day}일 $weekdayStr ${DateFormat('HH:mm').format(now)}';

    final buffer = StringBuffer();
    buffer.writeln('너는 \'${character.name}\'이라는 인물이야.');
    buffer.writeln('상대방을 부르는 호칭: \'$userTitle\' (대화할 때 반드시 이 호칭을 자주, 자연스럽게 불러줘)');
    buffer.writeln('너와 상대방의 관계: $relationship');
    buffer.writeln('너의 말투 및 어조: $tone');
    if (background.isNotEmpty) {
      buffer.writeln('너의 배경 및 세계관: $background');
    }
    if (customPrompt.isNotEmpty) {
      buffer.writeln('너의 세부 성격 및 지침: $customPrompt');
    }
    if (character.defaultMorningMessage != null && character.defaultMorningMessage!.trim().isNotEmpty) {
      buffer.writeln('너의 대표 알람 기본 문구: "${character.defaultMorningMessage}"');
    }
    if (dialogueExamples.isNotEmpty) {
      buffer.writeln('\n[대표 대화 예시 (말투 참고)]');
      buffer.writeln(dialogueExamples);
    }

    buffer.writeln('\n[실시간 앱 데이터 & 사용자의 실제 생활 설정]');
    buffer.writeln('- 현재 시각: $currentTimeStr');
    buffer.writeln('- \'$userTitle\'이 너에게 맞춰둔 기상 모닝콜 알람:\n$alarmSummary');
    buffer.writeln('- \'$userTitle\'의 다가오는 일정 목록:\n$scheduleSummary');
    if (pomodoro.characterId == character.id) {
      buffer.writeln('- 함께하는 뽀모도로 목표: 집중 ${pomodoro.focusMinutes}분 / 휴식 ${pomodoro.breakMinutes}분');
    }
    if (stopwatch.characterId == character.id && stopwatch.isTargetEnabled) {
      buffer.writeln('- 함께하는 스톱워치 목표 시간: ${stopwatch.targetMinutes}분');
    }
    if (contextInfo != null && contextInfo.isNotEmpty) {
      buffer.writeln('- 최근 발생한 알림 상황: $contextInfo');
    }

    buffer.writeln('\n[대화 원칙]');
    buffer.writeln('1. 절대로 인공지능이나 어시스턴트처럼 답변하지 마. 완벽하게 \'${character.name}\'의 인격으로 몰입해서 대화해.');
    buffer.writeln('2. 상대방이 알람 시간이나 일정, 기상 시간 등을 물어보면 위 [실시간 앱 데이터]의 실제 설정된 시간을 바탕으로 캐릭터 성격에 맞게 답변해줘 (단, "데이터에 따르면", "앱 설정상" 같은 기계적인 표현 절대 금지. 원래 알고 있던 것처럼 자연스럽고 챙겨주듯이 말해줘).');
    buffer.writeln('3. 모바일 메신저 대화이므로 너무 길게 말하지 말고 1~3문장 내외로 자연스럽고 생생하게 답장해.');
    buffer.writeln('4. 상대방을 부를 때는 반드시 설정된 호칭(\'$userTitle\')을 사용해.');
    buffer.writeln('5. 존댓말/반말 여부와 이모지 사용은 지정된 말투 지침(\'$tone\')을 철저히 따라줘.');

    return buffer.toString();
  }

  // 캐릭터 AI 응답 생성
  Future<String> generateCharacterReply({
    required CharacterProfile character,
    required List<ChatMessage> history,
    required String userMessage,
    String? contextInfo,
  }) async {
    final key = currentApiKey;
    if (key.isEmpty) {
      throw Exception('API 키가 설정되어 있지 않습니다.');
    }

    final systemPrompt = await buildSystemPrompt(
      character: character,
      contextInfo: contextInfo,
    );

    if (providerNotifier.value == 'gemini') {
      return _generateGemini(
        key: key,
        systemPrompt: systemPrompt,
        history: history,
        userMessage: userMessage,
      );
    } else if (providerNotifier.value == 'openai') {
      return _generateOpenai(
        key: key,
        systemPrompt: systemPrompt,
        history: history,
        userMessage: userMessage,
      );
    } else {
      return _generateClaude(
        key: key,
        systemPrompt: systemPrompt,
        history: history,
        userMessage: userMessage,
      );
    }
  }

  String? _cachedGeminiModel;

  /// Google AI Studio의 ListModels API를 통해 활성화된 모델 목록을 동적으로 탐색합니다.
  Future<String> _resolveGeminiModel(String key) async {
    final userSelected = geminiModelNotifier.value;
    if (userSelected != 'auto' && userSelected.isNotEmpty) {
      final clean = userSelected.startsWith('models/') ? userSelected.replaceFirst('models/', '') : userSelected;
      _cachedGeminiModel = clean;
      return clean;
    }

    if (_cachedGeminiModel != null && _cachedGeminiModel!.isNotEmpty) {
      return _cachedGeminiModel!;
    }

    final versions = ['v1beta', 'v1'];
    for (final v in versions) {
      try {
        final url = Uri.parse('https://generativelanguage.googleapis.com/$v/models?key=$key');
        final response = await http.get(url).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          final rawModels = (data['models'] as List?)?.cast<Map<String, dynamic>>() ?? [];

          final candidates = rawModels.where((m) {
            final methods = m['supportedGenerationMethods'] as List?;
            return methods != null && methods.contains('generateContent');
          }).map((m) => (m['name'] as String? ?? '')).where((n) => n.isNotEmpty).toList();

          if (candidates.isNotEmpty) {
            final chosen = candidates.firstWhere(
              (name) => name.contains('gemini-2.0-flash'),
              orElse: () => candidates.firstWhere(
                (name) => name.contains('gemini-1.5-flash') && !name.contains('8b'),
                orElse: () => candidates.firstWhere(
                  (name) => name.contains('gemini-1.5-flash-8b'),
                  orElse: () => candidates.firstWhere(
                    (name) => name.contains('gemini-1.5-pro'),
                    orElse: () => candidates.first,
                  ),
                ),
              ),
            );

            final clean = chosen.startsWith('models/') ? chosen.replaceFirst('models/', '') : chosen;
            _cachedGeminiModel = clean;
            return clean;
          }
        } else if (response.statusCode == 400 || response.statusCode == 403) {
          final errBody = jsonDecode(utf8.decode(response.bodyBytes));
          final errMsg = errBody['error']?['message'] ?? 'API 키 인증 실패';
          throw Exception(errMsg);
        }
      } catch (e) {
        if (kIsWeb) rethrow;
        if (e is Exception && e.toString().contains('API_KEY')) rethrow;
      }
    }

    return 'gemini-1.5-flash';
  }

  Future<http.Response> _sendGeminiRequest({
    required String key,
    required Map<String, dynamic> body,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final model = await _resolveGeminiModel(key);

    for (final v in ['v1beta', 'v1']) {
      try {
        final url = Uri.parse('https://generativelanguage.googleapis.com/$v/models/$model:generateContent?key=$key');
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ).timeout(timeout);

        if (response.statusCode == 200) {
          return response;
        }

        if (response.statusCode == 400 || response.statusCode == 403) {
          return response;
        }

        if (response.statusCode == 404) {
          continue;
        }

        return response;
      } catch (e) {
        if (kIsWeb) rethrow;
      }
    }

    // 최후 백업 요청
    final fallbackUrl = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$key');
    return await http.post(
      fallbackUrl,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ).timeout(timeout);
  }

  Future<String> _generateGemini({
    required String key,
    required String systemPrompt,
    required List<ChatMessage> history,
    required String userMessage,
  }) async {
    // 최근 대화 N개 가져오기
    final recentHistory = history.length > 8 ? history.sublist(history.length - 8) : history;

    final contents = <Map<String, dynamic>>[];

    // 이전 대화 기록 매핑
    for (final msg in recentHistory) {
      if (msg.isError) continue;
      contents.add({
        'role': msg.isMe ? 'user' : 'model',
        'parts': [
          {'text': msg.text}
        ],
      });
    }

    // 최신 사용자 메시지 추가
    contents.add({
      'role': 'user',
      'parts': [
        {'text': userMessage}
      ],
    });

    final body = {
      'system_instruction': {
        'parts': [
          {'text': systemPrompt}
        ]
      },
      'contents': contents,
      'generationConfig': {
        'temperature': 0.85,
        'maxOutputTokens': 250,
      }
    };

    final response = await _sendGeminiRequest(
      key: key,
      body: body,
      timeout: const Duration(seconds: 15),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final candidates = data['candidates'] as List?;
      if (candidates != null && candidates.isNotEmpty) {
        final content = candidates[0]['content'];
        final parts = content?['parts'] as List?;
        if (parts != null && parts.isNotEmpty) {
          final reply = parts[0]['text'] as String?;
          if (reply != null && reply.trim().isNotEmpty) {
            return reply.trim();
          }
        }
      }
      return '...응?';
    } else {
      final errBody = jsonDecode(utf8.decode(response.bodyBytes));
      final errMsg = errBody['error']?['message'] ?? '상태 코드 ${response.statusCode}';
      throw Exception('Gemini 호출 실패: $errMsg');
    }
  }

  Future<String> _generateOpenai({
    required String key,
    required String systemPrompt,
    required List<ChatMessage> history,
    required String userMessage,
  }) async {
    final url = Uri.parse('https://api.openai.com/v1/chat/completions');

    final recentHistory = history.length > 8 ? history.sublist(history.length - 8) : history;

    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': systemPrompt},
    ];

    for (final msg in recentHistory) {
      if (msg.isError) continue;
      messages.add({
        'role': msg.isMe ? 'user' : 'assistant',
        'content': msg.text,
      });
    }

    messages.add({
      'role': 'user',
      'content': userMessage,
    });

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $key',
      },
      body: jsonEncode({
        'model': 'gpt-4o-mini',
        'messages': messages,
        'temperature': 0.85,
        'max_tokens': 250,
      }),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final choices = data['choices'] as List?;
      if (choices != null && choices.isNotEmpty) {
        final reply = choices[0]['message']?['content'] as String?;
        if (reply != null && reply.trim().isNotEmpty) {
          return reply.trim();
        }
      }
      return '...응?';
    } else {
      final errBody = jsonDecode(utf8.decode(response.bodyBytes));
      final errMsg = errBody['error']?['message'] ?? '상태 코드 ${response.statusCode}';
      throw Exception('OpenAI 호출 실패: $errMsg');
    }
  }

  Future<String> _generateClaude({
    required String key,
    required String systemPrompt,
    required List<ChatMessage> history,
    required String userMessage,
  }) async {
    final url = Uri.parse('https://api.anthropic.com/v1/messages');

    final recentHistory = history.length > 8 ? history.sublist(history.length - 8) : history;

    final messages = <Map<String, dynamic>>[];

    for (final msg in recentHistory) {
      if (msg.isError) continue;
      messages.add({
        'role': msg.isMe ? 'user' : 'assistant',
        'content': msg.text,
      });
    }

    messages.add({
      'role': 'user',
      'content': userMessage,
    });

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': key,
        'anthropic-version': '2023-06-01',
        'anthropic-dangerous-direct-browser-access': 'true',
      },
      body: jsonEncode({
        'model': 'claude-3-5-haiku-20241022',
        'system': systemPrompt,
        'messages': messages,
        'max_tokens': 250,
      }),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final contentList = data['content'] as List?;
      if (contentList != null && contentList.isNotEmpty) {
        final text = contentList[0]['text'] as String?;
        if (text != null && text.trim().isNotEmpty) {
          return text.trim();
        }
      }
      return '...응?';
    } else {
      final errBody = jsonDecode(utf8.decode(response.bodyBytes));
      final errMsg = errBody['error']?['message'] ?? '상태 코드 ${response.statusCode}';
      throw Exception('Claude 호출 실패: $errMsg');
    }
  }

  // 알림 발생 시 AI가 페르소나에 맞게 동적 알림 문구 1문장 생성
  Future<String> generateNotificationMessage({
    required CharacterProfile character,
    required String notificationType,
    String? detail,
  }) async {
    final key = currentApiKey;
    if (key.isEmpty) {
      throw Exception('API 키가 설정되어 있지 않습니다.');
    }

    final userTitle = (character.title != null && character.title!.trim().isNotEmpty)
        ? character.title!.trim()
        : '사용자';

    final relationship = (character.aiRelationship != null && character.aiRelationship!.trim().isNotEmpty)
        ? character.aiRelationship!.trim()
        : '친근한 사이';

    final tone = (character.aiTone != null && character.aiTone!.trim().isNotEmpty)
        ? character.aiTone!.trim()
        : '다정하고 친근한 어조';

    final background = (character.aiBackground != null && character.aiBackground!.trim().isNotEmpty)
        ? character.aiBackground!.trim()
        : '';

    final persona = (character.aiPersonaPrompt != null && character.aiPersonaPrompt!.trim().isNotEmpty)
        ? character.aiPersonaPrompt!.trim()
        : '다정하고 따뜻하게';

    final prompt = '''
너는 '${character.name}'이야.
상대방을 부르는 호칭: '$userTitle'
너와 상대방의 관계: $relationship
너의 말투 및 어조: $tone
${background.isNotEmpty ? "배경/성격: $background" : ""}
세부 지침: $persona

알림 상황:
- 지금 상대방 스마트폰에 도착할 푸시 알림: [$notificationType]
${detail != null ? "- 상세 내용: $detail" : ""}

지침:
1. 상대방의 스마트폰 잠금화면 푸시 알림으로 전송될 메시지 딱 1문장(최대 40자 내외)만 즉시 작성해.
2. 따옴표(""), 이모지 설명, 메타 설명 없이 오직 알림 본문 텍스트만 출력해.
3. 캐릭터의 고유 어투('$tone')와 상대방 호칭('$userTitle')을 자연스럽게 살려줘.
''';

    if (providerNotifier.value == 'gemini') {
      final response = await _sendGeminiRequest(
        key: key,
        body: {
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.85,
            'maxOutputTokens': 100,
          }
        },
        timeout: const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final candidates = data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'];
          final parts = content?['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            final text = parts[0]['text'] as String?;
            if (text != null && text.trim().isNotEmpty) {
              return text.trim().replaceAll('"', '');
            }
          }
        }
      }
      throw Exception('Gemini 알림 문구 생성 실패');
    } else if (providerNotifier.value == 'openai') {
      final url = Uri.parse('https://api.openai.com/v1/chat/completions');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $key',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
          'temperature': 0.85,
          'max_tokens': 100,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final choices = data['choices'] as List?;
        if (choices != null && choices.isNotEmpty) {
          final text = choices[0]['message']?['content'] as String?;
          if (text != null && text.trim().isNotEmpty) {
            return text.trim().replaceAll('"', '');
          }
        }
      }
      throw Exception('OpenAI 알림 문구 생성 실패');
    } else {
      // Claude
      final url = Uri.parse('https://api.anthropic.com/v1/messages');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': key,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': 'claude-3-5-haiku-20241022',
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
          'max_tokens': 100,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final contentList = data['content'] as List?;
        if (contentList != null && contentList.isNotEmpty) {
          final text = contentList[0]['text'] as String?;
          if (text != null && text.trim().isNotEmpty) {
            return text.trim().replaceAll('"', '');
          }
        }
      }
      throw Exception('Claude 알림 문구 생성 실패');
    }
  }
}
