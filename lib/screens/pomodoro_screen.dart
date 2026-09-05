import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/character_profile.dart';
import '../models/message_bundle.dart';
import '../models/pomodoro_config.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/ai_chat_service.dart';
import '../utils/message_formatter.dart';
import '../widgets/character_avatar.dart';
import '../widgets/message_mode_selector.dart';

class PomodoroScreen extends StatefulWidget {
  const PomodoroScreen({super.key});

  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen> {
  PomodoroConfig _config = PomodoroConfig();
  List<CharacterProfile> _characters = [];
  CharacterProfile? _selectedCharacter;

  bool _isFocusMode = true; // true: 집중, false: 휴식
  bool _isRunning = false;
  late int _remainingSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = _config.focusMinutes * 60;
    _loadData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final config = await StorageService.instance.getPomodoroConfig();
    final characters = await StorageService.instance.getCharacters();
    CharacterProfile? char;
    if (config.characterId != null) {
      char = characters.where((c) => c.id == config.characterId).firstOrNull;
    }
    char ??= characters.firstOrNull;

    if (mounted) {
      setState(() {
        _config = config;
        _characters = characters;
        _selectedCharacter = char;
        if (!_isRunning) {
          _remainingSeconds = (_isFocusMode ? _config.focusMinutes : _config.breakMinutes) * 60;
        }
      });
    }
  }

  void _startTimer() {
    if (_isRunning) return;
    setState(() => _isRunning = true);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _onTimeFinished();
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _remainingSeconds = (_isFocusMode ? _config.focusMinutes : _config.breakMinutes) * 60;
    });
  }

  void _skipSession() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _isFocusMode = !_isFocusMode;
      _remainingSeconds = (_isFocusMode ? _config.focusMinutes : _config.breakMinutes) * 60;
    });
  }

  void _onTimeFinished() async {
    _timer?.cancel();
    setState(() => _isRunning = false);

    // 알림 발송
    if (_selectedCharacter != null) {
      final isFocus = _isFocusMode;
      final bundleId = isFocus ? _config.focusBundleId : _config.breakBundleId;
      final charDefault = isFocus
          ? _selectedCharacter!.defaultPomodoroFocusEndMessage
          : _selectedCharacter!.defaultPomodoroBreakEndMessage;
      final message = (charDefault != null && charDefault.isNotEmpty)
          ? charDefault
          : (isFocus ? _config.focusEndMessage : _config.breakEndMessage);
      final title = isFocus ? '🍅 집중 완료!' : '☕ 휴식 완료!';

      if (bundleId == 'AI_AUTO') {
        String msg;
        try {
          msg = await AiChatService.instance.generateNotificationMessage(
            character: _selectedCharacter!,
            notificationType: isFocus ? '뽀모도로 집중 완료' : '뽀모도로 휴식 완료',
            detail: isFocus ? '집중 ${_config.focusMinutes}분 완료' : '휴식 ${_config.breakMinutes}분 완료',
          );
        } catch (_) {
          msg = message;
        }
        await NotificationService.instance.showCharacterCustomNotification(
          id: isFocus ? 9991 : 9993,
          character: _selectedCharacter!,
          message: msg,
          title: title,
          payload: '${_selectedCharacter!.id}#pomodoro',
        );
      } else if (bundleId != null && bundleId.isNotEmpty) {
        final bundles = await StorageService.instance.getMessageBundlesByCharacter(_selectedCharacter!.id);
        MessageBundle? targetBundle;
        if (bundleId == 'RANDOM' || bundleId.startsWith('RANDOM:')) {
          List<MessageBundle> pool = bundles;
          if (bundleId.startsWith('RANDOM:')) {
            final ids = bundleId.substring(7).split(',').where((s) => s.isNotEmpty).toSet();
            final filtered = bundles.where((b) => ids.contains(b.id)).toList();
            if (filtered.isNotEmpty) pool = filtered;
          }
          if (pool.isNotEmpty) {
            final rand = Random();
            targetBundle = pool[rand.nextInt(pool.length)];
          }
        } else {
          targetBundle = bundles.where((b) => b.id == bundleId).firstOrNull;
        }

        if (targetBundle != null && targetBundle.messages.isNotEmpty) {
          final formattedMessages = targetBundle.messages
              .map((m) => MessageFormatter.format(m, character: _selectedCharacter!))
              .toList();
          await NotificationService.instance.showSequentialCharacterNotifications(
            baseId: isFocus ? 9991 : 9993,
            character: _selectedCharacter!,
            messages: formattedMessages,
            intervalSeconds: targetBundle.intervalSeconds,
            payload: '${_selectedCharacter!.id}#pomodoro',
          );
        } else {
          await NotificationService.instance.showCharacterCustomNotification(
            id: isFocus ? 9991 : 9993,
            character: _selectedCharacter!,
            message: message,
            title: title,
            payload: '${_selectedCharacter!.id}#pomodoro',
          );
        }
      } else {
        await NotificationService.instance.showCharacterCustomNotification(
          id: isFocus ? 9991 : 9993,
          character: _selectedCharacter!,
          message: message,
          title: title,
          payload: '${_selectedCharacter!.id}#pomodoro',
        );
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isFocusMode ? '집중 세션이 완료되었습니다!' : '휴식 세션이 완료되었습니다!'),
        ),
      );
    }

    // 다음 모드로 전환
    setState(() {
      _isFocusMode = !_isFocusMode;
      _remainingSeconds = (_isFocusMode ? _config.focusMinutes : _config.breakMinutes) * 60;
    });
  }

  void _openSettingsDialog() async {
    int focusMin = _config.focusMinutes;
    int breakMin = _config.breakMinutes;
    String? charId = _selectedCharacter?.id;
    final focusMsgController = TextEditingController(text: _config.focusEndMessage);
    final breakMsgController = TextEditingController(text: _config.breakEndMessage);

    String focusMode = 'SINGLE';
    String? focusBundleId;
    if (_config.focusBundleId == 'AI_AUTO') {
      focusMode = 'AI';
      focusBundleId = 'AI_AUTO';
    } else if (_config.focusBundleId == 'RANDOM' || (_config.focusBundleId != null && _config.focusBundleId!.startsWith('RANDOM'))) {
      focusMode = 'RANDOM';
      focusBundleId = _config.focusBundleId;
    } else if (_config.focusBundleId != null && _config.focusBundleId!.isNotEmpty) {
      focusMode = 'BUNDLE';
      focusBundleId = _config.focusBundleId;
    }

    String breakMode = 'SINGLE';
    String? breakBundleId;
    if (_config.breakBundleId == 'AI_AUTO') {
      breakMode = 'AI';
      breakBundleId = 'AI_AUTO';
    } else if (_config.breakBundleId == 'RANDOM' || (_config.breakBundleId != null && _config.breakBundleId!.startsWith('RANDOM'))) {
      breakMode = 'RANDOM';
      breakBundleId = _config.breakBundleId;
    } else if (_config.breakBundleId != null && _config.breakBundleId!.isNotEmpty) {
      breakMode = 'BUNDLE';
      breakBundleId = _config.breakBundleId;
    }

    List<MessageBundle> bundles = [];
    if (charId != null) {
      bundles = await StorageService.instance.getMessageBundlesByCharacter(charId);
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final currentChar = _characters.where((c) => c.id == charId).firstOrNull;

          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '뽀모도로 설정',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 집중 시간 슬라이더
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('집중 시간', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text('$focusMin분', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Slider(
                    value: focusMin.toDouble(),
                    min: 5,
                    max: 60,
                    divisions: 11,
                    onChanged: (val) {
                      setModalState(() => focusMin = val.round());
                    },
                  ),

                  // 휴식 시간 슬라이더
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('휴식 시간', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text('$breakMin분', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Slider(
                    value: breakMin.toDouble(),
                    min: 1,
                    max: 30,
                    divisions: 29,
                    onChanged: (val) {
                      setModalState(() => breakMin = val.round());
                    },
                  ),

                  // 캐릭터 선택
                  const SizedBox(height: 8),
                  const Text('응원 캐릭터', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  if (_characters.isEmpty)
                    const Text('등록된 캐릭터가 없습니다.', style: TextStyle(color: Colors.grey, fontSize: 13))
                  else
                    DropdownButtonFormField<String>(
                      initialValue: charId,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: _characters.map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Row(
                          children: [
                            CharacterAvatar(name: c.name, avatarPath: c.avatarPath, radius: 12),
                            const SizedBox(width: 8),
                            Text(c.name),
                          ],
                        ),
                      )).toList(),
                      onChanged: (val) async {
                        if (val != null) {
                          final newBundles = await StorageService.instance.getMessageBundlesByCharacter(val);
                          setModalState(() {
                            charId = val;
                            bundles = newBundles;
                            if (focusMode == 'BUNDLE' && !newBundles.any((b) => b.id == focusBundleId)) {
                              focusBundleId = newBundles.isNotEmpty ? newBundles.first.id : null;
                            }
                            if (breakMode == 'BUNDLE' && !newBundles.any((b) => b.id == breakBundleId)) {
                              breakBundleId = newBundles.isNotEmpty ? newBundles.first.id : null;
                            }
                          });
                        }
                      },
                    ),

                  const SizedBox(height: 20),
                  // 집중 완료 알림 메시지 설정
                  MessageModeSelector(
                    label: '집중 완료 시 알림 메시지',
                    currentMode: focusMode,
                    onModeChanged: (mode) => setModalState(() => focusMode = mode),
                    messageController: focusMsgController,
                    hint: '집중 시간 종료! 잠시 휴식해, {호칭}!',
                    character: currentChar,
                    bundles: bundles,
                    selectedBundleId: focusBundleId,
                    onBundleSelected: (bId) => setModalState(() => focusBundleId = bId),
                    showTimeTag: true,
                  ),

                  const SizedBox(height: 20),
                  // 휴식 완료 알림 메시지 설정
                  MessageModeSelector(
                    label: '휴식 완료 시 알림 메시지',
                    currentMode: breakMode,
                    onModeChanged: (mode) => setModalState(() => breakMode = mode),
                    messageController: breakMsgController,
                    hint: '휴식 시간 종료! 다시 집중해볼까, {호칭}?',
                    character: currentChar,
                    bundles: bundles,
                    selectedBundleId: breakBundleId,
                    onBundleSelected: (bId) => setModalState(() => breakBundleId = bId),
                    showTimeTag: true,
                  ),

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        final String? finalFocusBundleId;
                        if (focusMode == 'AI') {
                          finalFocusBundleId = 'AI_AUTO';
                        } else if (focusMode == 'RANDOM') {
                          finalFocusBundleId = (focusBundleId != null && focusBundleId!.startsWith('RANDOM') ? focusBundleId : 'RANDOM');
                        } else if (focusMode == 'BUNDLE') {
                          finalFocusBundleId = focusBundleId;
                        } else {
                          finalFocusBundleId = null;
                        }

                        final String? finalBreakBundleId;
                        if (breakMode == 'AI') {
                          finalBreakBundleId = 'AI_AUTO';
                        } else if (breakMode == 'RANDOM') {
                          finalBreakBundleId = (breakBundleId != null && breakBundleId!.startsWith('RANDOM') ? breakBundleId : 'RANDOM');
                        } else if (breakMode == 'BUNDLE') {
                          finalBreakBundleId = breakBundleId;
                        } else {
                          finalBreakBundleId = null;
                        }

                        final newConfig = PomodoroConfig(
                          focusMinutes: focusMin,
                          breakMinutes: breakMin,
                          characterId: charId,
                          focusEndMessage: focusMsgController.text.trim().isNotEmpty
                              ? focusMsgController.text.trim()
                              : '집중 시간 종료! 잠시 휴식해.',
                          breakEndMessage: breakMsgController.text.trim().isNotEmpty
                              ? breakMsgController.text.trim()
                              : '휴식 시간 종료! 다시 집중해볼까?',
                          focusBundleId: finalFocusBundleId,
                          breakBundleId: finalBreakBundleId,
                        );
                        await StorageService.instance.savePomodoroConfig(newConfig);
                        if (context.mounted) Navigator.pop(ctx);
                        _loadData();
                      },
                      child: const Text('설정 저장'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalSeconds = (_isFocusMode ? _config.focusMinutes : _config.breakMinutes) * 60;
    final progress = totalSeconds > 0 ? (_remainingSeconds / totalSeconds).clamp(0.0, 1.0) : 0.0;

    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(
        title: const Text('뽀모도로 타이머', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: '설정',
            onPressed: _openSettingsDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            children: [
              // 모드 배지 (집중 / 휴식)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _isFocusMode
                      ? theme.colorScheme.primaryContainer
                      : Colors.green.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isFocusMode ? Icons.self_improvement_rounded : Icons.coffee_rounded,
                      size: 18,
                      color: _isFocusMode
                          ? theme.colorScheme.onPrimaryContainer
                          : Colors.green.shade800,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isFocusMode ? '집중 세션' : '휴식 시간',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _isFocusMode
                            ? theme.colorScheme.onPrimaryContainer
                            : Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // 중앙 프로그레스 링 타이머
              Center(
                child: SizedBox(
                  width: 250,
                  height: 250,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 240,
                        height: 240,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 12,
                          strokeCap: StrokeCap.round,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _isFocusMode ? theme.colorScheme.primary : Colors.green,
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_selectedCharacter != null) ...[
                            CharacterAvatar(
                              name: _selectedCharacter!.name,
                              avatarPath: _selectedCharacter!.avatarPath,
                              radius: 24,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _selectedCharacter!.name,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          Text(
                            '$minutes:$seconds',
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              fontFeatures: [],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 48),

              // 하단 컨트롤 버튼
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    onPressed: _resetTimer,
                    icon: const Icon(Icons.refresh_rounded),
                    iconSize: 28,
                    tooltip: '초기화',
                  ),
                  const SizedBox(width: 20),
                  FilledButton(
                    onPressed: _isRunning ? _pauseTimer : _startTimer,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 28),
                        const SizedBox(width: 8),
                        Text(
                          _isRunning ? '일시정지' : '시작',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  IconButton.filledTonal(
                    onPressed: _skipSession,
                    icon: const Icon(Icons.skip_next_rounded),
                    iconSize: 28,
                    tooltip: '세션 넘기기',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
