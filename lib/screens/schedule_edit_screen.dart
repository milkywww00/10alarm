import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/character_profile.dart';
import '../models/message_bundle.dart';
import '../models/schedule_item.dart';
import '../services/storage_service.dart';
import '../services/alarm_scheduler.dart';
import '../widgets/character_avatar.dart';
import '../widgets/message_mode_selector.dart';
import 'character_edit_screen.dart';

class ScheduleEditScreen extends StatefulWidget {
  final DateTime initialDate;
  final ScheduleItem? schedule;

  const ScheduleEditScreen({
    super.key,
    required this.initialDate,
    this.schedule,
  });

  @override
  State<ScheduleEditScreen> createState() => _ScheduleEditScreenState();
}

class _ScheduleEditScreenState extends State<ScheduleEditScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _messageController;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;

  List<CharacterProfile> _characters = [];
  String? _selectedCharacterId;

  String _messageMode = 'SINGLE';
  String? _selectedBundleId;
  List<MessageBundle> _bundles = [];

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.schedule != null) {
      _titleController = TextEditingController(text: widget.schedule!.title);
      _messageController = TextEditingController(text: widget.schedule!.message);
      _selectedDate = DateTime(widget.schedule!.year, widget.schedule!.month, widget.schedule!.day);
      _selectedTime = TimeOfDay(hour: widget.schedule!.hour, minute: widget.schedule!.minute);
      _selectedCharacterId = widget.schedule!.characterId;

      if (widget.schedule!.bundleId == 'AI_AUTO') {
        _messageMode = 'AI';
        _selectedBundleId = 'AI_AUTO';
      } else if (widget.schedule!.bundleId == 'RANDOM' || (widget.schedule!.bundleId != null && widget.schedule!.bundleId!.startsWith('RANDOM'))) {
        _messageMode = 'RANDOM';
        _selectedBundleId = widget.schedule!.bundleId;
      } else if (widget.schedule!.bundleId != null && widget.schedule!.bundleId!.isNotEmpty) {
        _messageMode = 'BUNDLE';
        _selectedBundleId = widget.schedule!.bundleId;
      } else {
        _messageMode = 'SINGLE';
      }
    } else {
      _titleController = TextEditingController();
      _messageController = TextEditingController();
      _selectedDate = widget.initialDate;
      _selectedTime = const TimeOfDay(hour: 9, minute: 0);
    }
    _loadData();
  }

  @override
  void dispose() {
    _titleController.dispose();
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
          if (widget.schedule == null &&
              list.first.defaultCalendarMessage != null &&
              list.first.defaultCalendarMessage!.isNotEmpty) {
            _messageController.text = list.first.defaultCalendarMessage!;
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
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
        const SnackBar(content: Text('알림을 보낼 캐릭터를 먼저 등록해 주세요.')),
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

    final id = widget.schedule?.id ?? const Uuid().v4();
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

    final scheduleItem = ScheduleItem(
      id: id,
      title: _titleController.text.trim(),
      year: _selectedDate.year,
      month: _selectedDate.month,
      day: _selectedDate.day,
      hour: _selectedTime.hour,
      minute: _selectedTime.minute,
      characterId: _selectedCharacterId!,
      message: _messageController.text.trim().isNotEmpty
          ? _messageController.text.trim()
          : (_messageMode == 'AI' ? '[AI 맞춤 일정 알림]' : (_messageMode == 'RANDOM' ? '[랜덤 시나리오]' : '[시나리오 일정 알림]')),
      bundleId: bundleId,
      isCompleted: widget.schedule?.isCompleted ?? false,
      createdAt: widget.schedule?.createdAt ?? DateTime.now(),
    );

    await StorageService.instance.saveSchedule(scheduleItem);
    await AlarmScheduler.instance.scheduleScheduleReminder(scheduleItem);

    if (mounted) {
      Navigator.pop(context, scheduleItem);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.schedule != null;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final dateStr = '${_selectedDate.year}년 ${_selectedDate.month}월 ${_selectedDate.day}일';
    final period = _selectedTime.period == DayPeriod.am ? '오전' : '오후';
    final hour = _selectedTime.hourOfPeriod == 0 ? 12 : _selectedTime.hourOfPeriod;
    final minute = _selectedTime.minute.toString().padLeft(2, '0');
    final timeStr = '$period $hour:$minute';

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? '일정 수정' : '새 일정 추가'),
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
              // 일정 제목 입력
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: '일정 제목',
                  hintText: '일정 이름을 입력하세요',
                  prefixIcon: const Icon(Icons.event_note_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return '일정 제목을 입력해 주세요';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // 날짜 & 시간 선택 행
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today_rounded, size: 18),
                      label: Text(dateStr, style: const TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(Icons.access_time_rounded, size: 18),
                      label: Text(timeStr, style: const TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 담당 캐릭터 선택
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('리마인드 캐릭터', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                  child: const Text('등록된 캐릭터가 없습니다. 상단의 \'캐릭터 등록\' 버튼으로 먼저 생성해 주세요.'),
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
                              Text(char.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedCharacterId = val);
                          _loadBundlesForCharacter(val);
                        }
                      },
                    ),
                  ),
                ),
              const SizedBox(height: 24),

              // 알림 메시지 / 시나리오 선택
              Builder(
                builder: (context) {
                  final selectedChar = _characters.where((c) => c.id == _selectedCharacterId).firstOrNull;
                  return MessageModeSelector(
                    label: '알림 메시지 설정',
                    currentMode: _messageMode,
                    onModeChanged: (mode) => setState(() => _messageMode = mode),
                    messageController: _messageController,
                    hint: '오늘 {일정} 있는 날이야, {호칭}! 잊지 않았지?',
                    character: selectedChar,
                    bundles: _bundles,
                    selectedBundleId: _selectedBundleId,
                    onBundleSelected: (bId) => setState(() => _selectedBundleId = bId),
                    showScheduleTag: true,
                    maxLines: 3,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
