import 'package:flutter/material.dart';
import '../models/alarm_item.dart';
import '../models/character_profile.dart';
import '../services/storage_service.dart';
import '../services/alarm_scheduler.dart';
import '../services/notification_service.dart';
import '../services/permission_service.dart';
import '../widgets/alarm_card.dart';
import '../widgets/empty_state_view.dart';
import 'alarm_edit_screen.dart';
import 'character_list_screen.dart';
import 'time_management_screen.dart';
import 'calendar_screen.dart';
import 'chat_simulation_screen.dart';
import 'chat_list_screen.dart';
import 'settings_screen.dart';
import 'alarm_ring_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentTabIndex = 0;
  List<AlarmItem> _alarms = [];
  Map<String, CharacterProfile> _charactersMap = {};
  bool _isLoading = true;
  bool _isBatteryIgnored = true;
  bool _isOverlayGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
    _initApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    try {
      final bStatus = await PermissionService.instance.isBatteryOptimizationIgnored();
      final oStatus = await PermissionService.instance.isSystemAlertWindowGranted();
      if (mounted) {
        setState(() {
          _isBatteryIgnored = bStatus;
          _isOverlayGranted = oStatus;
        });
      }
    } catch (e) {
      debugPrint('권한 상태 확인 오류: $e');
    }
  }

  Future<void> _initApp() async {
    await PermissionService.instance.requestEssentialPermissions();
    await _checkPermissions();
    NotificationService.instance.onNotificationTap = _handleNotificationTap;
    await _loadData();

    // 앱이 종료되어 있던 상태에서 전체화면 알람이나 푸시로 실행되었는지 확인
    final launchDetails = await NotificationService.instance.getLaunchDetails();
    if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
      final payload = launchDetails.notificationResponse?.payload;
      if (payload != null) {
        _handleNotificationTap(payload);
      }
    }
  }

  Future<void> _loadData() async {
    final alarms = await StorageService.instance.getAlarms();
    final characters = await StorageService.instance.getCharacters();

    if (mounted) {
      setState(() {
        _alarms = alarms;
        _charactersMap = {for (var c in characters) c.id: c};
        _isLoading = false;
      });
    }
  }

  void _handleNotificationTap(String? payload) async {
    if (payload == null) return;
    final parts = payload.split('#');
    if (parts.isEmpty) return;

    final characterId = parts[0];
    final targetId = parts.length > 1 ? parts[1] : null;

    final character = await StorageService.instance.getCharacterById(characterId);
    if (character == null) return;

    String initialMsg = '좋은 아침이야!';
    AlarmItem? matchedAlarm;

    if (targetId != null) {
      if (targetId.startsWith('schedule_')) {
        final scheduleId = targetId.replaceFirst('schedule_', '');
        final schedules = await StorageService.instance.getSchedules();
        final sFound = schedules.where((s) => s.id == scheduleId).toList();
        if (sFound.isNotEmpty) {
          initialMsg = sFound.first.message;
        }
      } else if (targetId == 'pomodoro') {
        final config = await StorageService.instance.getPomodoroConfig();
        initialMsg = config.focusEndMessage;
      } else if (targetId == 'stopwatch') {
        final config = await StorageService.instance.getStopwatchConfig();
        initialMsg = config.targetReachedMessage;
      } else {
        final alarms = await StorageService.instance.getAlarms();
        final found = alarms.where((a) => a.id == targetId).toList();
        if (found.isNotEmpty) {
          matchedAlarm = found.first;
          initialMsg = matchedAlarm.message;
        }
      }
    }

    if (mounted) {
      if (targetId != null &&
          (targetId.startsWith('schedule_') ||
              targetId == 'pomodoro' ||
              targetId == 'stopwatch')) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatSimulationScreen(
              character: character,
              alarm: matchedAlarm,
              initialMessage: initialMsg,
            ),
          ),
        );
      } else {
        // 알람 울림 화면으로 진입 (알람음 울림 및 해제 제어)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AlarmRingScreen(
              character: character,
              alarm: matchedAlarm,
              message: initialMsg,
            ),
          ),
        );
      }
    }
  }

  Future<void> _navigateToAddAlarm() async {
    final characters = await StorageService.instance.getCharacters();
    if (!mounted) return;

    if (characters.isEmpty) {
      final shouldCreate = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('캐릭터 등록 필요'),
          content: const Text('알람을 보내줄 캐릭터가 아직 없습니다.\n먼저 캐릭터를 등록하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('캐릭터 등록하기'),
            ),
          ],
        ),
      );

      if (shouldCreate == true && mounted) {
        setState(() => _currentTabIndex = 4);
      }
      return;
    }

    if (!mounted) return;
    final result = await Navigator.push<AlarmItem>(
      context,
      MaterialPageRoute(builder: (_) => const AlarmEditScreen()),
    );
    if (result != null) {
      _loadData();
    }
  }

  Future<void> _navigateToEditAlarm(AlarmItem alarm) async {
    if (!mounted) return;
    final result = await Navigator.push<AlarmItem>(
      context,
      MaterialPageRoute(builder: (_) => AlarmEditScreen(alarm: alarm)),
    );
    if (result != null) {
      _loadData();
    }
  }

  Future<void> _toggleAlarm(AlarmItem alarm, bool isEnabled) async {
    final updated = alarm.copyWith(isEnabled: isEnabled);
    await StorageService.instance.saveAlarm(updated);
    if (isEnabled) {
      await AlarmScheduler.instance.scheduleAlarm(updated);
    } else {
      await AlarmScheduler.instance.cancelAlarm(updated);
    }
    _loadData();
  }

  Future<void> _deleteAlarm(AlarmItem alarm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('알람 삭제'),
        content: Text('${alarm.timeFormatted} 알람을 삭제하시겠습니까?'),
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
      await AlarmScheduler.instance.cancelAlarm(alarm);
      await StorageService.instance.deleteAlarm(alarm.id);
      _loadData();
    }
  }

  Future<void> _previewAlarm(AlarmItem alarm) async {
    final character = _charactersMap[alarm.characterId];
    if (character == null) return;

    final effectiveMsg = (alarm.message.isNotEmpty && !alarm.message.startsWith('['))
        ? alarm.message
        : (character.defaultMorningMessage?.isNotEmpty == true
            ? character.defaultMorningMessage!
            : '좋은 아침이야, {호칭}! 오늘도 힘차게 시작해볼까?');

    await AlarmScheduler.instance.triggerPreview(alarm.copyWith(message: effectiveMsg), character);

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AlarmRingScreen(
            character: character,
            alarm: alarm,
            message: effectiveMsg,
          ),
        ),
      );
    }
  }

  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    Widget bodyWidget;
    PreferredSizeWidget? appBarWidget;
    Widget? fabWidget;

    switch (_currentTabIndex) {
      case 0:
        appBarWidget = AppBar(
          title: const Text('알람 목록', style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: '설정',
              onPressed: _navigateToSettings,
            ),
          ],
        );
        bodyWidget = _buildAlarmTab();
        fabWidget = _alarms.isNotEmpty
            ? FloatingActionButton.extended(
                onPressed: _navigateToAddAlarm,
                icon: const Icon(Icons.add_alarm_rounded),
                label: const Text('알람 추가'),
              )
            : null;
        break;
      case 1:
        bodyWidget = const TimeManagementScreen();
        break;
      case 2:
        bodyWidget = const CalendarScreen();
        break;
      case 3:
        bodyWidget = const ChatListScreen();
        break;
      case 4:
      default:
        appBarWidget = AppBar(
          title: const Text('캐릭터 관리', style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: '설정',
              onPressed: _navigateToSettings,
            ),
          ],
        );
        bodyWidget = const CharacterListScreen();
        break;
    }

    return Scaffold(
      appBar: appBarWidget,
      body: bodyWidget,
      floatingActionButton: fabWidget,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTabIndex,
        onDestinationSelected: (index) {
          setState(() => _currentTabIndex = index);
          _loadData();
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.alarm_rounded),
            selectedIcon: Icon(Icons.alarm_on_rounded),
            label: '알람',
          ),
          NavigationDestination(
            icon: Icon(Icons.hourglass_bottom_rounded),
            selectedIcon: Icon(Icons.hourglass_full_rounded),
            label: '시간관리',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: '캘린더',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: '채팅',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: '캐릭터',
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionBanners() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!_isBatteryIgnored)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.battery_alert_rounded, color: Colors.amber.shade800, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '앱이 꺼져 있어도 알람이 100% 울리려면\n\'배터리 제한 없음\' 설정이 필요해요.',
                    style: TextStyle(fontSize: 12, color: Colors.amber.shade900, height: 1.3),
                  ),
                ),
                FilledButton.tonal(
                  onPressed: () async {
                    await PermissionService.instance.requestIgnoreBatteryOptimization();
                    await _checkPermissions();
                  },
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: const Text('설정하기', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        if (!_isOverlayGranted)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade300, width: 1.5),
            ),
            child: Row(
              children: [
                Icon(Icons.layers_rounded, color: Colors.blue.shade800, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '앱이 꺼져있을 때 화면에 알람을 바로 띄우려면\n\'다른 앱 위에 표시\' 권한을 켜주세요.',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade900, height: 1.3, fontWeight: FontWeight.bold),
                  ),
                ),
                FilledButton(
                  onPressed: () async {
                    await PermissionService.instance.requestSystemAlertWindow();
                    await _checkPermissions();
                  },
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: Colors.blue.shade700,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: const Text('허용하기', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildAlarmTab() {
    final banners = _buildPermissionBanners();
    final hasBanners = !_isBatteryIgnored || !_isOverlayGranted;

    if (_alarms.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return RefreshIndicator(
            onRefresh: () async {
              await _checkPermissions();
              await _loadData();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      if (hasBanners) banners,
                      Expanded(
                        child: EmptyStateView(
                          icon: Icons.alarm_rounded,
                          title: '등록된 알람이 없습니다',
                          description: '내가 좋아하는 캐릭터를 등록하고,\n아침마다 설레는 모닝콜 메시지를 받아보세요.',
                          buttonText: '첫 알람 만들기',
                          onButtonPressed: _navigateToAddAlarm,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _checkPermissions();
        await _loadData();
      },
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 80),
        children: [
          banners,
          ..._alarms.map((alarm) {
            final character = _charactersMap[alarm.characterId];
            return AlarmCard(
              alarm: alarm,
              character: character,
              onToggle: (val) => _toggleAlarm(alarm, val),
              onTap: () => _navigateToEditAlarm(alarm),
              onPreview: () => _previewAlarm(alarm),
              onDelete: () => _deleteAlarm(alarm),
            );
          }),
        ],
      ),
    );
  }
}
