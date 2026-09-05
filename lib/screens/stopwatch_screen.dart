import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/character_profile.dart';
import '../models/message_bundle.dart';
import '../models/stopwatch_config.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/ai_chat_service.dart';
import '../utils/message_formatter.dart';
import '../widgets/character_avatar.dart';
import '../widgets/message_mode_selector.dart';

class StopwatchScreen extends StatefulWidget {
  const StopwatchScreen({super.key});

  @override
  State<StopwatchScreen> createState() => _StopwatchScreenState();
}

class _StopwatchScreenState extends State<StopwatchScreen> {
  StopwatchConfig _config = StopwatchConfig();
  List<CharacterProfile> _characters = [];
  CharacterProfile? _selectedCharacter;

  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  final List<String> _laps = [];
  bool _targetAlertTriggered = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final config = await StorageService.instance.getStopwatchConfig();
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
      });
    }
  }

  void _startStopwatch() {
    _stopwatch.start();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      setState(() {});
      _checkTargetReached();
    });
  }

  void _pauseStopwatch() {
    _stopwatch.stop();
    _timer?.cancel();
    setState(() {});
  }

  void _resetStopwatch() {
    _stopwatch.reset();
    _timer?.cancel();
    setState(() {
      _laps.clear();
      _targetAlertTriggered = false;
    });
  }

  void _recordLap() {
    if (!_stopwatch.isRunning) return;
    setState(() {
      _laps.insert(0, _formattedTime);
    });
  }

  void _checkTargetReached() async {
    if (!_config.isTargetEnabled || _targetAlertTriggered) return;

    final targetMillis = _config.targetMinutes * 60 * 1000;
    if (_stopwatch.elapsedMilliseconds >= targetMillis) {
      _targetAlertTriggered = true;

      if (_selectedCharacter != null) {
        final bundleId = _config.bundleId;
        if (bundleId == 'AI_AUTO') {
          String msg;
          try {
            msg = await AiChatService.instance.generateNotificationMessage(
              character: _selectedCharacter!,
              notificationType: '스톱워치 ${_config.targetMinutes}분 목표 시간 달성 축하',
              detail: '스톱워치 목표 시간 ${_config.targetMinutes}분 달성 완료',
            );
          } catch (_) {
            msg = (_selectedCharacter!.defaultStopwatchCongratsMessage?.isNotEmpty == true)
                ? _selectedCharacter!.defaultStopwatchCongratsMessage!
                : _config.targetReachedMessage;
          }
          await NotificationService.instance.showCharacterCustomNotification(
            id: 9992,
            character: _selectedCharacter!,
            message: msg,
            title: '⏱️ ${_config.targetMinutes}분 달성 완료!',
            payload: '${_selectedCharacter!.id}#stopwatch',
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
              baseId: 9992,
              character: _selectedCharacter!,
              messages: formattedMessages,
              intervalSeconds: targetBundle.intervalSeconds,
              payload: '${_selectedCharacter!.id}#stopwatch',
            );
          } else {
            final msg = (_selectedCharacter!.defaultStopwatchCongratsMessage?.isNotEmpty == true)
                ? _selectedCharacter!.defaultStopwatchCongratsMessage!
                : _config.targetReachedMessage;
            await NotificationService.instance.showCharacterCustomNotification(
              id: 9992,
              character: _selectedCharacter!,
              message: msg,
              title: '⏱️ ${_config.targetMinutes}분 달성 완료!',
              payload: '${_selectedCharacter!.id}#stopwatch',
            );
          }
        } else {
          final msg = (_selectedCharacter!.defaultStopwatchCongratsMessage?.isNotEmpty == true)
              ? _selectedCharacter!.defaultStopwatchCongratsMessage!
              : _config.targetReachedMessage;
          await NotificationService.instance.showCharacterCustomNotification(
            id: 9992,
            character: _selectedCharacter!,
            message: msg,
            title: '⏱️ ${_config.targetMinutes}분 달성 완료!',
            payload: '${_selectedCharacter!.id}#stopwatch',
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('목표 시간 ${_config.targetMinutes}분에 도달했습니다!'),
          ),
        );
      }
    }
  }

  String get _formattedTime {
    final millis = _stopwatch.elapsedMilliseconds;
    final hundreds = (millis ~/ 10) % 100;
    final seconds = (millis ~/ 1000) % 60;
    final minutes = (millis ~/ (1000 * 60)) % 60;
    final hours = millis ~/ (1000 * 60 * 60);

    final hStr = hours.toString().padLeft(2, '0');
    final mStr = minutes.toString().padLeft(2, '0');
    final sStr = seconds.toString().padLeft(2, '0');
    final cStr = hundreds.toString().padLeft(2, '0');

    if (hours > 0) {
      return '$hStr:$mStr:$sStr.$cStr';
    }
    return '$mStr:$sStr.$cStr';
  }

  void _openSettingsDialog() async {
    int targetMin = _config.targetMinutes;
    bool isEnabled = _config.isTargetEnabled;
    String? charId = _selectedCharacter?.id;
    final targetMinController = TextEditingController(text: targetMin.toString());
    final msgController = TextEditingController(text: _config.targetReachedMessage);

    String messageMode = 'SINGLE';
    String? selectedBundleId;
    if (_config.bundleId == 'AI_AUTO') {
      messageMode = 'AI';
      selectedBundleId = 'AI_AUTO';
    } else if (_config.bundleId == 'RANDOM' || (_config.bundleId != null && _config.bundleId!.startsWith('RANDOM'))) {
      messageMode = 'RANDOM';
      selectedBundleId = _config.bundleId;
    } else if (_config.bundleId != null && _config.bundleId!.isNotEmpty) {
      messageMode = 'BUNDLE';
      selectedBundleId = _config.bundleId;
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
                        '스톱워치 목표 설정',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  SwitchListTile(
                    title: const Text('목표 시간 알림 사용', style: TextStyle(fontWeight: FontWeight.w600)),
                    value: isEnabled,
                    onChanged: (val) {
                      setModalState(() => isEnabled = val);
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),

                  if (isEnabled) ...[
                    // 목표 시간 직접 숫자 입력
                    const Text('목표 시간 설정', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: targetMinController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: '목표 시간 (분)',
                              hintText: '예: 30',
                              suffixText: '분',
                              prefixIcon: const Icon(Icons.timer_outlined),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                            onChanged: (val) {
                              final parsed = int.tryParse(val);
                              if (parsed != null && parsed > 0) {
                                targetMin = parsed;
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 빠른 시간 선택 칩
                    Wrap(
                      spacing: 8,
                      children: [5, 10, 15, 30, 60].map((mins) {
                        return ActionChip(
                          label: Text('$mins분'),
                          onPressed: () {
                            setModalState(() {
                              targetMin = mins;
                              targetMinController.text = mins.toString();
                            });
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 16),
                    const Text('축하 캐릭터', style: TextStyle(fontWeight: FontWeight.w600)),
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
                              if (messageMode == 'BUNDLE' && !newBundles.any((b) => b.id == selectedBundleId)) {
                                selectedBundleId = newBundles.isNotEmpty ? newBundles.first.id : null;
                              }
                            });
                          }
                        },
                      ),

                    const SizedBox(height: 16),
                    MessageModeSelector(
                      label: '목표 달성 시 알림 메시지',
                      currentMode: messageMode,
                      onModeChanged: (mode) => setModalState(() => messageMode = mode),
                      messageController: msgController,
                      hint: '목표 시간 달성! 정말 대단해, {호칭}!',
                      character: currentChar,
                      bundles: bundles,
                      selectedBundleId: selectedBundleId,
                      onBundleSelected: (bId) => setModalState(() => selectedBundleId = bId),
                      showTimeTag: true,
                    ),
                  ],

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        final parsedMin = int.tryParse(targetMinController.text.trim()) ?? targetMin;
                        final finalMin = parsedMin > 0 ? parsedMin : 10;
                        final String? bundleId;
                        if (messageMode == 'AI') {
                          bundleId = 'AI_AUTO';
                        } else if (messageMode == 'RANDOM') {
                          bundleId = (selectedBundleId != null && selectedBundleId!.startsWith('RANDOM') ? selectedBundleId : 'RANDOM');
                        } else if (messageMode == 'BUNDLE') {
                          bundleId = selectedBundleId;
                        } else {
                          bundleId = null;
                        }

                        final newConfig = StopwatchConfig(
                          targetMinutes: finalMin,
                          isTargetEnabled: isEnabled,
                          characterId: charId,
                          targetReachedMessage: msgController.text.trim().isNotEmpty
                              ? msgController.text.trim()
                              : '목표 시간 달성! 정말 대단해.',
                          bundleId: bundleId,
                        );
                        await StorageService.instance.saveStopwatchConfig(newConfig);
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
    final isRunning = _stopwatch.isRunning;

    return Scaffold(
      appBar: AppBar(
        title: const Text('스톱워치', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: '목표 설정',
            onPressed: _openSettingsDialog,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          children: [
            // 목표 시간 표시 뱃지
            if (_config.isTargetEnabled) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.flag_rounded, size: 16, color: theme.colorScheme.onSecondaryContainer),
                    const SizedBox(width: 6),
                    Text(
                      '목표: ${_config.targetMinutes}분 달성 시 알림',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                    if (_selectedCharacter != null) ...[
                      const SizedBox(width: 8),
                      CharacterAvatar(
                        name: _selectedCharacter!.name,
                        avatarPath: _selectedCharacter!.avatarPath,
                        radius: 10,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // 대형 디지털 타이머
            Center(
              child: Text(
                _formattedTime,
                style: const TextStyle(
                  fontSize: 54,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // 컨트롤 버튼
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  onPressed: _resetStopwatch,
                  icon: const Icon(Icons.refresh_rounded),
                  iconSize: 28,
                  tooltip: '초기화',
                ),
                const SizedBox(width: 20),
                FilledButton(
                  onPressed: isRunning ? _pauseStopwatch : _startStopwatch,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 28),
                      const SizedBox(width: 8),
                      Text(
                        isRunning ? '정지' : '시작',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                IconButton.filledTonal(
                  onPressed: isRunning ? _recordLap : null,
                  icon: const Icon(Icons.flag_circle_rounded),
                  iconSize: 28,
                  tooltip: '랩 기록',
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),

            // 랩 타임 목록
            Expanded(
              child: _laps.isEmpty
                  ? Center(
                      child: Text(
                        '기록된 랩 타임이 없습니다.',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _laps.length,
                      itemBuilder: (context, index) {
                        final lapIndex = _laps.length - index;
                        final lapTime = _laps[index];
                        return ListTile(
                          dense: true,
                          leading: Text(
                            '#$lapIndex',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          title: Text(
                            lapTime,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
