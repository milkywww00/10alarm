import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/theme_service.dart';
import '../services/sound_service.dart';
import '../services/ai_chat_service.dart';
import '../services/permission_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
  late ThemeMode _currentThemeMode;
  late Color _currentColor;
  late String _currentSound;
  late bool _vibrate;

  late bool _isAiEnabled;
  late String _aiProvider;
  late String _geminiModel;
  late String _openaiModel;
  late String _claudeModel;
  late TextEditingController _geminiKeyController;
  late TextEditingController _openaiKeyController;
  late TextEditingController _claudeKeyController;
  bool _obscureApiKey = true;
  bool _isTestingConnection = false;
  Map<String, dynamic>? _testResult;

  bool _isBatteryIgnored = true;
  bool _isOverlayGranted = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();

    _currentThemeMode = ThemeService.instance.themeModeNotifier.value;
    _currentColor = ThemeService.instance.themeColorNotifier.value;
    _currentSound = ThemeService.instance.alarmSoundNotifier.value;
    _vibrate = ThemeService.instance.vibrateNotifier.value;

    _isAiEnabled = AiChatService.instance.isAiEnabledNotifier.value;
    _aiProvider = AiChatService.instance.providerNotifier.value;
    _geminiModel = AiChatService.instance.geminiModelNotifier.value;
    _openaiModel = AiChatService.instance.openaiModelNotifier.value;
    _claudeModel = AiChatService.instance.claudeModelNotifier.value;
    _geminiKeyController = TextEditingController(text: AiChatService.instance.geminiKeyNotifier.value);
    _openaiKeyController = TextEditingController(text: AiChatService.instance.openaiKeyNotifier.value);
    _claudeKeyController = TextEditingController(text: AiChatService.instance.claudeKeyNotifier.value);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _geminiKeyController.dispose();
    _openaiKeyController.dispose();
    _claudeKeyController.dispose();
    SoundService.instance.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    if (kIsWeb || !Platform.isAndroid) return;
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
      debugPrint('권한 확인 오류: $e');
    }
  }

  void _onThemeModeChanged(Set<ThemeMode> selection) {
    if (selection.isEmpty) return;
    final mode = selection.first;
    setState(() => _currentThemeMode = mode);
    ThemeService.instance.setThemeMode(mode);
  }

  void _onColorSelected(Color color) {
    setState(() => _currentColor = color);
    ThemeService.instance.setThemeColor(color);
  }

  Future<void> _pickCustomAudioFile(StateSetter setDialogState) async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a', 'ogg', 'aac', 'flac'],
      );

      if (files.isNotEmpty) {
        final file = files.first;
        final soundName = file.name;
        final soundPath = file.path ?? '';

        await ThemeService.instance.addCustomSound(soundName, soundPath);

        setState(() {
          _currentSound = soundName;
        });
        setDialogState(() {});

        // 등록된 오디오 미리듣기 즉시 재생
        SoundService.instance.playPreview(soundName, customPath: soundPath);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('\'$soundName\' 알림음이 성공적으로 등록되었습니다.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오디오 파일 선택 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  void _showSoundPicker() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final customSounds = ThemeService.instance.customSoundsNotifier.value;
          final theme = Theme.of(context);

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.library_music_outlined),
                SizedBox(width: 8),
                Text('알림음 선택 및 미리듣기', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. 직접 추가한 알림음 섹션
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '내가 추가한 알림음 (${customSounds.length})',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.file_upload_outlined, size: 16),
                          label: const Text('파일 추가', style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                          onPressed: () => _pickCustomAudioFile(setDialogState),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (customSounds.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '기기에 저장된 MP3, WAV 등의 음원 파일을 추가해 나만의 알람음으로 설정할 수 있습니다.',
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      )
                    else
                      ...customSounds.map((item) {
                        final name = item['name']!;
                        final isSelected = _currentSound == name;
                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                          leading: Icon(
                            isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                            color: isSelected ? theme.colorScheme.primary : Colors.grey,
                            size: 20,
                          ),
                          title: Text(name, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ValueListenableBuilder<String?>(
                                valueListenable: SoundService.instance.playingSoundNotifier,
                                builder: (context, playingName, _) {
                                  final isPlaying = playingName == name;
                                  return IconButton(
                                    icon: Icon(
                                      isPlaying ? Icons.stop_circle_rounded : Icons.play_circle_outline_rounded,
                                      color: isPlaying ? theme.colorScheme.primary : Colors.grey,
                                      size: 22,
                                    ),
                                    tooltip: isPlaying ? '정지' : '미리듣기',
                                    onPressed: () {
                                      if (isPlaying) {
                                        SoundService.instance.stop();
                                      } else {
                                        SoundService.instance.playPreview(name, customPath: item['path']);
                                      }
                                    },
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18, color: Colors.red),
                                tooltip: '삭제',
                                onPressed: () async {
                                  SoundService.instance.stop();
                                  await ThemeService.instance.deleteCustomSound(name);
                                  setDialogState(() {});
                                  setState(() {
                                    _currentSound = ThemeService.instance.alarmSoundNotifier.value;
                                  });
                                },
                              ),
                            ],
                          ),
                          onTap: () {
                            setState(() => _currentSound = name);
                            ThemeService.instance.setAlarmSound(name);
                            setDialogState(() {});
                            SoundService.instance.playPreview(name, customPath: item['path']);
                          },
                        );
                      }),
                    const Divider(height: 24),

                    // 2. 기본 프리셋 알림음 섹션
                    Text(
                      '기본 알림음 프리셋',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 6),
                    ...ThemeService.alarmSounds.map((sound) {
                      final isSelected = _currentSound == sound;
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                        leading: Icon(
                          isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          color: isSelected ? theme.colorScheme.primary : Colors.grey,
                          size: 20,
                        ),
                        title: Text(
                          sound,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                        trailing: ValueListenableBuilder<String?>(
                          valueListenable: SoundService.instance.playingSoundNotifier,
                          builder: (context, playingName, _) {
                            final isPlaying = playingName == sound;
                            return IconButton(
                              icon: Icon(
                                isPlaying ? Icons.stop_circle_rounded : Icons.play_circle_outline_rounded,
                                color: isPlaying ? theme.colorScheme.primary : Colors.grey,
                                size: 24,
                              ),
                              tooltip: isPlaying ? '정지' : '미리듣기',
                              onPressed: () {
                                if (isPlaying) {
                                  SoundService.instance.stop();
                                } else {
                                  SoundService.instance.playPreview(sound);
                                }
                              },
                            );
                          },
                        ),
                        onTap: () {
                          setState(() => _currentSound = sound);
                          ThemeService.instance.setAlarmSound(sound);
                          setDialogState(() {});
                          SoundService.instance.playPreview(sound);
                        },
                      );
                    }),
                  ],
                ),
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  SoundService.instance.stop();
                  Navigator.pop(ctx);
                },
                child: const Text('완료'),
              ),
            ],
          );
        },
      ),
    ).then((_) {
      SoundService.instance.stop();
    });
  }

  Future<void> _confirmResetData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('데이터 초기화'),
        content: const Text('등록된 모든 캐릭터, 알람, 일정 데이터가 삭제됩니다.\n정말 초기화하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('초기화'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      // 테마 복원
      await ThemeService.instance.setThemeColor(_currentColor);
      await ThemeService.instance.setThemeMode(_currentThemeMode);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('모든 데이터가 성공적으로 초기화되었습니다.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('설정', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          // 섹션 1: 테마 및 UI 스타일 설정
          _buildSectionHeader('화면 테마 및 색상'),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('테마 모드', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.brightness_auto_rounded),
                          label: Text('시스템'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode_rounded),
                          label: Text('라이트'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode_rounded),
                          label: Text('다크'),
                        ),
                      ],
                      selected: {_currentThemeMode},
                      onSelectionChanged: _onThemeModeChanged,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('UI 포인트 컬러', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      Text(
                        ThemeService.presetColors.firstWhere(
                          (c) => (c['color'] as Color).toARGB32() == _currentColor.toARGB32(),
                          orElse: () => {'name': ''},
                        )['name'] as String,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _currentColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: ThemeService.presetColors.map((item) {
                      final Color color = item['color'] as Color;
                      final String name = item['name'] as String;
                      final isSelected = _currentColor.toARGB32() == color.toARGB32();

                      return GestureDetector(
                        onTap: () => _onColorSelected(color),
                        child: Tooltip(
                          message: name,
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.white : Colors.transparent,
                                width: 2.5,
                              ),
                              boxShadow: [
                                if (isSelected)
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.5),
                                    blurRadius: 6,
                                    spreadRadius: 1.5,
                                  ),
                              ],
                            ),
                            child: isSelected
                                ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 섹션 2: 사운드 및 진동 설정
          _buildSectionHeader('사운드 및 진동'),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.music_note_rounded, color: theme.colorScheme.primary),
                  title: const Text('기본 알람음'),
                  subtitle: Text(
                    _currentSound,
                    style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _showSoundPicker,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: Icon(Icons.vibration_rounded, color: theme.colorScheme.primary),
                  title: const Text('진동 알림'),
                  subtitle: const Text('알람 울릴 때 기기 진동 사용'),
                  value: _vibrate,
                  onChanged: (val) {
                    setState(() => _vibrate = val);
                    ThemeService.instance.setVibrate(val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 섹션 3: AI 대화 설정 (사용자 API 키 / BYOK)
          _buildAiSettingsSection(theme),
          const SizedBox(height: 24),

          // 섹션 4: 알람 정상 작동 권한 설정
          _buildPermissionSection(theme),

          // 섹션 5: 앱 정보 및 데이터 관리
          _buildSectionHeader('앱 관리'),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('앱 버전'),
                  trailing: Text(
                    'v1.0.0',
                    style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                  title: const Text('데이터 전체 초기화', style: TextStyle(color: Colors.red)),
                  subtitle: const Text('등록된 모든 캐릭터 및 알람 초기화'),
                  onTap: _confirmResetData,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionSection(ThemeData theme) {
    if (kIsWeb) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('알람 권한 및 백그라운드 설정'),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              ListTile(
                leading: Icon(
                  Icons.layers_rounded,
                  color: _isOverlayGranted ? Colors.green : Colors.blue.shade700,
                ),
                title: const Text('다른 앱 위에 표시'),
                subtitle: Text(
                  _isOverlayGranted
                      ? '허용됨 (화면 꺼짐 시 알람 화면 바로 뜸)'
                      : '미허용 (앱 꺼져있을 때 화면 팝업을 위해 권한 필요)',
                  style: TextStyle(
                    fontSize: 12,
                    color: _isOverlayGranted ? Colors.green.shade700 : Colors.blue.shade900,
                  ),
                ),
                trailing: _isOverlayGranted
                    ? const Icon(Icons.check_circle_rounded, color: Colors.green)
                    : FilledButton.tonal(
                        onPressed: () async {
                          await PermissionService.instance.requestSystemAlertWindow();
                          await _checkPermissions();
                        },
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        child: const Text('권한 설정', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  Icons.battery_saver_rounded,
                  color: _isBatteryIgnored ? Colors.green : Colors.amber.shade800,
                ),
                title: const Text('배터리 최적화 제외 (제한 없음)'),
                subtitle: Text(
                  _isBatteryIgnored
                      ? '설정 완료 (기기 절전 모드 시 알람 누락 방지)'
                      : '미설정 (절전 모드에서 알람이 지연될 수 있음)',
                  style: TextStyle(
                    fontSize: 12,
                    color: _isBatteryIgnored ? Colors.green.shade700 : Colors.amber.shade900,
                  ),
                ),
                trailing: _isBatteryIgnored
                    ? const Icon(Icons.check_circle_rounded, color: Colors.green)
                    : FilledButton.tonal(
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
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.settings_applications_rounded),
                title: const Text('기기 시스템 앱 설정 열기'),
                subtitle: const Text('알림 권한, 정확한 알람 등 기기 설정 직접 이동', style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.open_in_new_rounded, size: 20),
                onTap: () => PermissionService.instance.openSettings(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildAiSettingsSection(ThemeData theme) {
    final isGemini = _aiProvider == 'gemini';
    final isOpenAi = _aiProvider == 'openai';
    final currentController = isGemini
        ? _geminiKeyController
        : (isOpenAi ? _openaiKeyController : _claudeKeyController);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('AI 대화 설정 (사용자 API 키)'),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  secondary: Icon(Icons.smart_toy_outlined, color: theme.colorScheme.primary),
                  title: const Text('AI 캐릭터 실시간 대화'),
                  subtitle: const Text('알림 수신 후 캐릭터와 메신저처럼 1:1 대화'),
                  value: _isAiEnabled,
                  onChanged: (val) {
                    setState(() => _isAiEnabled = val);
                    AiChatService.instance.setAiEnabled(val);
                  },
                ),
                if (_isAiEnabled) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AI 제공사 선택',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const SizedBox(height: 10),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'gemini',
                              label: Text('Google Gemini (무료 추천)'),
                              icon: Icon(Icons.auto_awesome_rounded),
                            ),
                            ButtonSegment(
                              value: 'openai',
                              label: Text('OpenAI (GPT)'),
                              icon: Icon(Icons.psychology_outlined),
                            ),
                            ButtonSegment(
                              value: 'claude',
                              label: Text('Claude'),
                              icon: Icon(Icons.hub_outlined),
                            ),
                          ],
                          selected: {_aiProvider},
                          onSelectionChanged: (selection) {
                            if (selection.isEmpty) return;
                            final newProvider = selection.first;
                            setState(() {
                              _aiProvider = newProvider;
                              _testResult = null;
                            });
                            AiChatService.instance.setProvider(newProvider);
                          },
                        ),
                        const SizedBox(height: 14),

                        // 무료 발급 가이드 버튼
                        InkWell(
                          onTap: _showAiKeyGuideDialog,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.help_outline_rounded, size: 18, color: theme.colorScheme.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    isGemini
                                        ? 'Google AI Studio에서 무료 API 키 발급받는 방법 >'
                                        : (isOpenAi
                                            ? 'OpenAI API 키 발급 안내 >'
                                            : 'Anthropic Claude API 키 발급 안내 >'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // API 키 입력 필드
                        TextFormField(
                          controller: currentController,
                          obscureText: _obscureApiKey,
                          decoration: InputDecoration(
                            labelText: isGemini
                                ? 'Google Gemini API Key'
                                : (isOpenAi ? 'OpenAI API Key' : 'Claude API Key'),
                            hintText: isGemini
                                ? 'AIzaSy...'
                                : (isOpenAi ? 'sk-...' : 'sk-ant-...'),
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(_obscureApiKey ? Icons.visibility_off : Icons.visibility),
                                  onPressed: () => setState(() => _obscureApiKey = !_obscureApiKey),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.check_rounded, color: Colors.green),
                                  tooltip: '저장',
                                  onPressed: () {
                                    if (isGemini) {
                                      AiChatService.instance.setGeminiKey(currentController.text);
                                    } else if (isOpenAi) {
                                      AiChatService.instance.setOpenaiKey(currentController.text);
                                    } else {
                                      AiChatService.instance.setClaudeKey(currentController.text);
                                    }
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('API 키가 안전하게 로컬에 저장되었습니다.')),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          onChanged: (val) {
                            if (isGemini) {
                              AiChatService.instance.setGeminiKey(val);
                            } else if (isOpenAi) {
                              AiChatService.instance.setOpenaiKey(val);
                            } else {
                              AiChatService.instance.setClaudeKey(val);
                            }
                          },
                        ),
                        if (isGemini) ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _geminiModel,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Gemini 모델 선택 (상위 모델 지정)',
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              prefixIcon: const Icon(Icons.tune_rounded, size: 20),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'auto',
                                child: Text('자동 탐색 (구글 지원 최적 모델 권장)'),
                              ),
                              DropdownMenuItem(
                                value: 'gemini-1.5-pro',
                                child: Text('Gemini 1.5 Pro (최상위 지능 - 페르소나 극대화)'),
                              ),
                              DropdownMenuItem(
                                value: 'gemini-2.0-flash',
                                child: Text('Gemini 2.0 Flash (차세대 고성능 & 고속)'),
                              ),
                              DropdownMenuItem(
                                value: 'gemini-1.5-flash',
                                child: Text('Gemini 1.5 Flash (표준 추천 - 빠르고 쾌적)'),
                              ),
                              DropdownMenuItem(
                                value: 'gemini-1.5-flash-8b',
                                child: Text('Gemini 1.5 Flash-8B (초경량 초고속)'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _geminiModel = val;
                                  _testResult = null;
                                });
                                AiChatService.instance.setGeminiModel(val);
                              }
                            },
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '💡 1.5 Pro 모델은 캐릭터 말투와 지능이 가장 뛰어나지만 응답에 3~5초 소요될 수 있으며, 무료 사용량(분당 2회/일 50회)이 Flash(분당 15회/일 1,500회)보다 타이트합니다.',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                        if (isOpenAi) ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _openaiModel,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'OpenAI 모델 선택 (상위 모델 지정)',
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              prefixIcon: const Icon(Icons.psychology_outlined, size: 20),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'gpt-4o-mini',
                                child: Text('GPT-4o mini (표준 추천 - 빠르고 경제적)'),
                              ),
                              DropdownMenuItem(
                                value: 'gpt-4o',
                                child: Text('GPT-4o (최상위 플래그십 - 깊은 페르소나 연기)'),
                              ),
                              DropdownMenuItem(
                                value: 'gpt-4-turbo',
                                child: Text('GPT-4 Turbo (고성능 플래그십)'),
                              ),
                              DropdownMenuItem(
                                value: 'gpt-3.5-turbo',
                                child: Text('GPT-3.5 Turbo (초경량 기본형)'),
                              ),
                              DropdownMenuItem(
                                value: 'o3-mini',
                                child: Text('o3-mini (최신 추론 특화)'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _openaiModel = val;
                                  _testResult = null;
                                });
                                AiChatService.instance.setOpenaiModel(val);
                              }
                            },
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '💡 GPT-4o 플래그십은 캐릭터 연기력이 탁월하지만 mini 대비 약 15배의 크레딧이 소진됩니다.',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                        if (!isGemini && !isOpenAi) ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _claudeModel,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Claude 모델 선택 (상위 모델 지정)',
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              prefixIcon: const Icon(Icons.hub_outlined, size: 20),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'claude-3-5-haiku-20241022',
                                child: Text('Claude 3.5 Haiku (표준 추천 - 빠르고 경쾌함)'),
                              ),
                              DropdownMenuItem(
                                value: 'claude-3-5-sonnet-20241022',
                                child: Text('Claude 3.5 Sonnet (최상위 감성 문장력 - 몰입감 극대화)'),
                              ),
                              DropdownMenuItem(
                                value: 'claude-3-opus-20240229',
                                child: Text('Claude 3 Opus (심층 분석/대규모)'),
                              ),
                              DropdownMenuItem(
                                value: 'claude-3-haiku-20240307',
                                child: Text('Claude 3 Haiku (기본 경량형)'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _claudeModel = val;
                                  _testResult = null;
                                });
                                AiChatService.instance.setClaudeModel(val);
                              }
                            },
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '💡 Claude 3.5 Sonnet은 현존 최고의 감성 표현과 문장력을 자랑하지만 Haiku 대비 약 4배의 크레딧이 소진됩니다.',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                        const SizedBox(height: 12),

                        // 연결 테스트 버튼
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _isTestingConnection ? null : _testAiConnection,
                              icon: _isTestingConnection
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.wifi_tethering_rounded, size: 18),
                              label: const Text('API 연결 테스트'),
                            ),
                          ],
                        ),
                        if (_testResult != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: _testResult!['success'] == true
                                  ? Colors.green.shade50
                                  : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _testResult!['success'] == true
                                    ? Colors.green.shade300
                                    : Colors.red.shade300,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  _testResult!['success'] == true
                                      ? Icons.check_circle_rounded
                                      : Icons.error_outline_rounded,
                                  size: 18,
                                  color: _testResult!['success'] == true
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _testResult!['message'] as String,
                                    style: TextStyle(
                                      fontSize: 12,
                                      height: 1.4,
                                      color: _testResult!['success'] == true
                                          ? Colors.green.shade800
                                          : Colors.red.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (kIsWeb) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.amber.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline_rounded, size: 14, color: Colors.amber.shade900),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '웹 브라우저에서는 브라우저 보안 정책(CORS)으로 API 직접 호출이 차단될 수 있습니다. 스마트폰 앱(APK)에서는 제한 없이 원활하게 작동합니다.',
                                    style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _testAiConnection() async {
    final isGemini = _aiProvider == 'gemini';
    final isOpenAi = _aiProvider == 'openai';
    final currentKey = isGemini
        ? _geminiKeyController.text
        : (isOpenAi ? _openaiKeyController.text : _claudeKeyController.text);

    setState(() {
      _isTestingConnection = true;
      _testResult = null;
    });

    final res = await AiChatService.instance.testConnection(
      provider: _aiProvider,
      apiKey: currentKey,
    );

    if (mounted) {
      setState(() {
        _isTestingConnection = false;
        _testResult = res;
      });
    }
  }

  void _showAiKeyGuideDialog() {
    final isGemini = _aiProvider == 'gemini';
    final isOpenAi = _aiProvider == 'openai';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isGemini
                  ? Icons.auto_awesome_rounded
                  : (isOpenAi ? Icons.psychology_outlined : Icons.hub_outlined),
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              isGemini
                  ? 'Google Gemini 무료 키 발급'
                  : (isOpenAi ? 'OpenAI API 키 발급' : 'Anthropic Claude 키 발급'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isGemini) ...[
                const Text(
                  '💡 Google AI Studio는 누구나 신용카드 없이 완전 무료로 API 키를 발급받을 수 있습니다 (일일 1,500회 무료 대화 가능).',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.blueAccent),
                ),
                const SizedBox(height: 14),
                const Text('1. https://aistudio.google.com 에 접속합니다.', style: TextStyle(fontSize: 13)),
                const SizedBox(height: 6),
                const Text('2. 보유하신 Google 계정으로 로그인합니다.', style: TextStyle(fontSize: 13)),
                const SizedBox(height: 6),
                const Text('3. 좌측 상단 또는 화면 중앙의 [Get API key] 버튼을 누릅니다.', style: TextStyle(fontSize: 13)),
                const SizedBox(height: 6),
                const Text('4. [Create API key]를 누르고 발급된 키를 복사합니다.', style: TextStyle(fontSize: 13)),
                const SizedBox(height: 6),
                const Text('5. 본 앱의 API Key 입력란에 붙여넣고 저장합니다!', style: TextStyle(fontSize: 13)),
              ] else if (isOpenAi) ...[
                const Text(
                  '💡 OpenAI API 키는 platform.openai.com 에서 발급받을 수 있습니다 (유료 크레딧 계정 필요).',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.blueAccent),
                ),
                const SizedBox(height: 14),
                const Text('1. https://platform.openai.com/api-keys 에 접속합니다.', style: TextStyle(fontSize: 13)),
                const SizedBox(height: 6),
                const Text('2. [Create new secret key]를 눌러 키를 생성합니다.', style: TextStyle(fontSize: 13)),
                const SizedBox(height: 6),
                const Text('3. 복사한 sk-... 키를 본 앱에 붙여넣고 저장합니다.', style: TextStyle(fontSize: 13)),
              ] else ...[
                const Text(
                  '💡 Anthropic Claude API 키는 console.anthropic.com 에서 발급받을 수 있습니다.',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.blueAccent),
                ),
                const SizedBox(height: 14),
                const Text('1. https://console.anthropic.com 에 접속합니다.', style: TextStyle(fontSize: 13)),
                const SizedBox(height: 6),
                const Text('2. 계정 로그인 후 좌측 [API Keys] 메뉴로 이동합니다.', style: TextStyle(fontSize: 13)),
                const SizedBox(height: 6),
                const Text('3. [Create Key] 버튼을 눌러 새 API 키를 생성합니다.', style: TextStyle(fontSize: 13)),
                const SizedBox(height: 6),
                const Text('4. 복사한 sk-ant-... 키를 본 앱에 붙여넣고 저장합니다.', style: TextStyle(fontSize: 13)),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '🔒 입력하신 API 키는 오직 사용자의 기기 내부(로컬)에만 안전하게 저장되며, 어떠한 외부 서버로도 전송되지 않습니다.',
                  style: TextStyle(fontSize: 11, color: Colors.black87),
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
