import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/alarm_item.dart';
import '../models/character_profile.dart';
import '../models/message_bundle.dart';
import '../services/storage_service.dart';
import '../services/alarm_scheduler.dart';
import '../widgets/character_avatar.dart';
import '../widgets/message_mode_selector.dart';
import 'character_edit_screen.dart';

class AlarmEditScreen extends StatefulWidget {
  final AlarmItem? alarm;

  const AlarmEditScreen({super.key, this.alarm});

  @override
  State<AlarmEditScreen> createState() => _AlarmEditScreenState();
}

class _AlarmEditScreenState extends State<AlarmEditScreen> {
  final _formKey = GlobalKey<FormState>();

  late TimeOfDay _selectedTime;
  List<CharacterProfile> _characters = [];
  String? _selectedCharacterId;
  final Set<int> _selectedDays = {};
  late TextEditingController _messageController;

  // 발송 모드: 'SINGLE' (기본 문구), 'RANDOM' (시나리오 중 랜덤), 'BUNDLE' (지정 시나리오)
  String _messageMode = 'SINGLE';
  String? _selectedBundleId;
  List<MessageBundle> _bundles = [];

  bool _isLoading = true;
  bool _isSaving = false;

  final List<Map<String, dynamic>> _daysOfWeek = [
    {'day': 1, 'name': '월'},
    {'day': 2, 'name': '화'},
    {'day': 3, 'name': '수'},
    {'day': 4, 'name': '목'},
    {'day': 5, 'name': '금'},
    {'day': 6, 'name': '토'},
    {'day': 7, 'name': '일'},
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    if (widget.alarm != null) {
      _selectedTime = TimeOfDay(hour: widget.alarm!.hour, minute: widget.alarm!.minute);
      _selectedCharacterId = widget.alarm!.characterId;
      _selectedDays.addAll(widget.alarm!.repeatDays);
      _messageController = TextEditingController(text: widget.alarm!.message);

      if (widget.alarm!.bundleId == 'AI_AUTO') {
        _messageMode = 'AI';
        _selectedBundleId = 'AI_AUTO';
      } else if (widget.alarm!.bundleId == 'RANDOM' || (widget.alarm!.bundleId != null && widget.alarm!.bundleId!.startsWith('RANDOM'))) {
        _messageMode = 'RANDOM';
        _selectedBundleId = widget.alarm!.bundleId;
      } else if (widget.alarm!.bundleId != null && widget.alarm!.bundleId!.isNotEmpty) {
        _messageMode = 'BUNDLE';
        _selectedBundleId = widget.alarm!.bundleId;
      } else {
        _messageMode = 'SINGLE';
      }
    } else {
      _selectedTime = TimeOfDay(hour: now.hour, minute: (now.minute + 5) % 60);
      _messageController = TextEditingController();
    }
    _loadData();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final list = await StorageService.instance.getCharacters();
    if (mounted) {
      setState(() {
        _characters = list;
        if (_selectedCharacterId == null && list.isNotEmpty) {
          _selectedCharacterId = list.first.id;
          if (widget.alarm == null &&
              list.first.defaultMorningMessage != null &&
              list.first.defaultMorningMessage!.isNotEmpty) {
            _messageController.text = list.first.defaultMorningMessage!;
          }
        }
      });

      if (_selectedCharacterId != null) {
        await _loadBundlesForCharacter(_selectedCharacterId!);
      }

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadBundlesForCharacter(String charId) async {
    final bundles = await StorageService.instance.getMessageBundlesByCharacter(charId);
    if (mounted) {
      setState(() {
        _bundles = bundles;
        if (_messageMode == 'BUNDLE') {
          if (_selectedBundleId == null || !bundles.any((b) => b.id == _selectedBundleId)) {
            _selectedBundleId = bundles.isNotEmpty ? bundles.first.id : null;
          }
        }
      });
    }
  }

  void _onCharacterChanged(String? val) async {
    if (val == null) return;
    setState(() {
      _selectedCharacterId = val;
      final selectedChar = _characters.where((c) => c.id == val).firstOrNull;
      if (selectedChar?.defaultMorningMessage != null &&
          selectedChar!.defaultMorningMessage!.isNotEmpty &&
          _messageController.text.trim().isEmpty) {
        _messageController.text = selectedChar.defaultMorningMessage!;
      }
    });
    await _loadBundlesForCharacter(val);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      initialEntryMode: TimePickerEntryMode.dial,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _createNewCharacter() async {
    final newChar = await Navigator.push<CharacterProfile>(
      context,
      MaterialPageRoute(builder: (_) => const CharacterEditScreen()),
    );
    if (newChar != null) {
      await _loadData();
      setState(() => _selectedCharacterId = newChar.id);
    }
  }

  Future<void> _save() async {
    if (_characters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('알람을 보낼 캐릭터를 먼저 등록해 주세요.')),
      );
      return;
    }

    if (_messageMode == 'BUNDLE') {
      if (_selectedBundleId == null || _bundles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('발송할 대화 시나리오를 선택해 주세요.')),
        );
        return;
      }
    } else if (_messageMode == 'RANDOM') {
      if (_bundles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('캐릭터에 등록된 대화 시나리오가 없습니다. 먼저 캐릭터 설정에서 시나리오를 추가해 주세요.')),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    final id = widget.alarm?.id ?? const Uuid().v4();
    final String? bundleId;
    if (_messageMode == 'AI') {
      bundleId = 'AI_AUTO';
    } else if (_messageMode == 'RANDOM') {
      bundleId = (_selectedBundleId != null && _selectedBundleId!.startsWith('RANDOM') ? _selectedBundleId! : 'RANDOM');
    } else if (_messageMode == 'BUNDLE') {
      bundleId = _selectedBundleId;
    } else {
      bundleId = null;
    }

    final alarmItem = AlarmItem(
      id: id,
      characterId: _selectedCharacterId!,
      hour: _selectedTime.hour,
      minute: _selectedTime.minute,
      repeatDays: _selectedDays.toList()..sort(),
      message: _messageController.text.trim().isNotEmpty
          ? _messageController.text.trim()
          : (_messageMode == 'AI' ? '[AI 맞춤 모닝콜]' : (_messageMode == 'RANDOM' ? '[랜덤 시나리오]' : '[시나리오 알람]')),
      bundleId: bundleId,
      isEnabled: widget.alarm?.isEnabled ?? true,
      createdAt: widget.alarm?.createdAt ?? DateTime.now(),
    );

    await StorageService.instance.saveAlarm(alarmItem);
    await AlarmScheduler.instance.scheduleAlarm(alarmItem);

    if (mounted) {
      Navigator.pop(context, alarmItem);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.alarm != null;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final selectedChar = _characters.where((c) => c.id == _selectedCharacterId).firstOrNull;

    final period = _selectedTime.period == DayPeriod.am ? '오전' : '오후';
    final displayHour = _selectedTime.hourOfPeriod == 0 ? 12 : _selectedTime.hourOfPeriod;
    final displayMinute = _selectedTime.minute.toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? '알람 편집' : '새 알람 설정'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('저장', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 시간 선택 카드
              Card(
                elevation: 0,
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: InkWell(
                  onTap: _pickTime,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16),
                    child: Column(
                      children: [
                        Text(
                          '알람 시간 설정',
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              period,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$displayHour:$displayMinute',
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                                letterSpacing: -1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '터치하여 시간 변경',
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.primary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 반복 요일 선택
              const Text('반복 요일', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _daysOfWeek.map((dayMap) {
                  final int day = dayMap['day'] as int;
                  final String name = dayMap['name'] as String;
                  final bool isSelected = _selectedDays.contains(day);

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedDays.remove(day);
                        } else {
                          _selectedDays.add(day);
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isSelected ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          name,
                          style: TextStyle(
                            color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Text(
                _selectedDays.isEmpty ? '요일을 선택하지 않으면 1회만 울립니다.' : '선택한 요일마다 반복됩니다.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),

              // 캐릭터 선택
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('발신 캐릭터', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  TextButton.icon(
                    onPressed: _createNewCharacter,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('캐릭터 등록', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_characters.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '등록된 캐릭터가 없습니다. 상단의 \'캐릭터 등록\' 버튼을 눌러 먼저 생성해 주세요.',
                          style: TextStyle(fontSize: 13, color: Colors.amber.shade900),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedCharacterId,
                      items: _characters.map((char) {
                        return DropdownMenuItem<String>(
                          value: char.id,
                          child: Row(
                            children: [
                              CharacterAvatar(
                                name: char.name,
                                avatarPath: char.avatarPath,
                                radius: 16,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                char.name,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              if (char.title != null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '(${char.title})',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: _onCharacterChanged,
                    ),
                  ),
                ),
              const SizedBox(height: 24),

              // 알림 메시지 설정 (기본 문구 vs 랜덤 시나리오 vs 시나리오 선택)
              MessageModeSelector(
                label: '알림 메시지 설정',
                currentMode: _messageMode,
                onModeChanged: (mode) => setState(() => _messageMode = mode),
                messageController: _messageController,
                hint: '좋은 아침이야, {호칭}! 오늘도 힘내자~',
                character: selectedChar,
                bundles: _bundles,
                selectedBundleId: _selectedBundleId,
                onBundleSelected: (bId) => setState(() => _selectedBundleId = bId),
                maxLines: 3,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

