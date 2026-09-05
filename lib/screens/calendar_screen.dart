import 'package:flutter/material.dart';
import '../models/character_profile.dart';
import '../models/schedule_item.dart';
import '../services/storage_service.dart';
import '../services/alarm_scheduler.dart';
import '../widgets/character_avatar.dart';
import 'schedule_edit_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  List<ScheduleItem> _allSchedules = [];
  Map<String, CharacterProfile> _charactersMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final schedules = await StorageService.instance.getSchedules();
    final characters = await StorageService.instance.getCharacters();

    if (mounted) {
      setState(() {
        _allSchedules = schedules;
        _charactersMap = {for (var c in characters) c.id: c};
        _isLoading = false;
      });
    }
  }

  List<ScheduleItem> get _schedulesForSelectedDate {
    return _allSchedules.where((s) =>
        s.year == _selectedDate.year &&
        s.month == _selectedDate.month &&
        s.day == _selectedDate.day).toList();
  }

  bool _hasScheduleOn(int year, int month, int day) {
    return _allSchedules.any((s) => s.year == year && s.month == month && s.day == day);
  }

  Future<void> _navigateToAddSchedule() async {
    final result = await Navigator.push<ScheduleItem>(
      context,
      MaterialPageRoute(
        builder: (_) => ScheduleEditScreen(initialDate: _selectedDate),
      ),
    );
    if (result != null) {
      _loadData();
    }
  }

  Future<void> _navigateToEditSchedule(ScheduleItem schedule) async {
    final result = await Navigator.push<ScheduleItem>(
      context,
      MaterialPageRoute(
        builder: (_) => ScheduleEditScreen(
          initialDate: DateTime(schedule.year, schedule.month, schedule.day),
          schedule: schedule,
        ),
      ),
    );
    if (result != null) {
      _loadData();
    }
  }

  Future<void> _toggleSchedule(ScheduleItem schedule) async {
    await StorageService.instance.toggleScheduleCompleted(schedule.id);
    _loadData();
  }

  Future<void> _deleteSchedule(ScheduleItem schedule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('일정 삭제'),
        content: Text('\'${schedule.title}\' 일정을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AlarmScheduler.instance.cancelScheduleReminder(schedule);
      await StorageService.instance.deleteSchedule(schedule.id);
      _loadData();
    }
  }

  void _prevMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final daysInMonth = DateUtils.getDaysInMonth(_focusedMonth.year, _focusedMonth.month);
    final firstDayOfWeek = DateTime(_focusedMonth.year, _focusedMonth.month, 1).weekday % 7; // 0=Sun, 6=Sat

    return Scaffold(
      appBar: AppBar(
        title: const Text('일정 관리', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // 월 전환 헤더
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_focusedMonth.year}년 ${_focusedMonth.month}월',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: _prevMonth,
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: _nextMonth,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 요일 헤더
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: const ['일', '월', '화', '수', '목', '금', '토'].map((day) {
                final isSunday = day == '일';
                final isSaturday = day == '토';
                return SizedBox(
                  width: 38,
                  child: Text(
                    day,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isSunday
                          ? Colors.red
                          : (isSaturday ? Colors.blue : Colors.grey.shade600),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),

          // 달력 날짜 그리드
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: firstDayOfWeek + daysInMonth,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                childAspectRatio: 1.1,
              ),
              itemBuilder: (context, index) {
                if (index < firstDayOfWeek) {
                  return const SizedBox();
                }

                final dayNumber = index - firstDayOfWeek + 1;
                final cellDate = DateTime(_focusedMonth.year, _focusedMonth.month, dayNumber);
                final isSelected = cellDate.year == _selectedDate.year &&
                    cellDate.month == _selectedDate.month &&
                    cellDate.day == _selectedDate.day;
                final isToday = cellDate.year == DateTime.now().year &&
                    cellDate.month == DateTime.now().month &&
                    cellDate.day == DateTime.now().day;
                final hasEvent = _hasScheduleOn(cellDate.year, cellDate.month, cellDate.day);

                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedDate = cellDate);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : (isToday
                              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
                              : Colors.transparent),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$dayNumber',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: (isSelected || isToday) ? FontWeight.bold : FontWeight.normal,
                            color: isSelected
                                ? Colors.white
                                : (isToday ? theme.colorScheme.primary : theme.colorScheme.onSurface),
                          ),
                        ),
                        if (hasEvent)
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? Colors.white : theme.colorScheme.primary,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          const Divider(),

          // 선택 날짜 헤더
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_selectedDate.month}월 ${_selectedDate.day}일 일정',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_schedulesForSelectedDate.length}개',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),

          // 선택 날짜 일정 리스트
          Expanded(
            child: _schedulesForSelectedDate.isEmpty
                ? Center(
                    child: Text(
                      '등록된 일정이 없습니다.\n하단의 + 버튼을 눌러 일정을 추가해 보세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13, height: 1.5),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _schedulesForSelectedDate.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final schedule = _schedulesForSelectedDate[index];
                      final character = _charactersMap[schedule.characterId];

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: InkWell(
                          onTap: () => _navigateToEditSchedule(schedule),
                          borderRadius: BorderRadius.circular(14),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: schedule.isCompleted,
                                  onChanged: (_) => _toggleSchedule(schedule),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                ),
                                if (character != null) ...[
                                  CharacterAvatar(
                                    name: character.name,
                                    avatarPath: character.avatarPath,
                                    radius: 18,
                                  ),
                                  const SizedBox(width: 10),
                                ],
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        schedule.title,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          decoration: schedule.isCompleted
                                              ? TextDecoration.lineThrough
                                              : null,
                                          color: schedule.isCompleted
                                              ? Colors.grey.shade500
                                              : theme.colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(Icons.access_time_rounded, size: 12, color: Colors.grey.shade600),
                                          const SizedBox(width: 4),
                                          Text(
                                            schedule.timeFormatted,
                                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                          ),
                                          if (character != null) ...[
                                            const SizedBox(width: 8),
                                            Text(
                                              '• ${character.name} 알림',
                                              style: TextStyle(fontSize: 12, color: theme.colorScheme.primary),
                                            ),
                                          ],
                                        ],
                                      ),
                                      if (schedule.message.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          schedule.message,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.grey),
                                  onPressed: () => _deleteSchedule(schedule),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddSchedule,
        child: const Icon(Icons.add),
      ),
    );
  }
}
