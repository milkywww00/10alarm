import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/character_profile.dart';
import '../models/message_bundle.dart';
import '../services/storage_service.dart';
import '../widgets/character_avatar.dart';
import '../widgets/message_input_field.dart';
import 'bundle_edit_screen.dart';

class CharacterEditScreen extends StatefulWidget {
  final CharacterProfile? character;

  const CharacterEditScreen({super.key, this.character});

  @override
  State<CharacterEditScreen> createState() => _CharacterEditScreenState();
}

class _CharacterEditScreenState extends State<CharacterEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _titleController;

  // 캐릭터별 맞춤 푸시알림 문구 컨트롤러
  late TextEditingController _morningMsgController;
  late TextEditingController _pomodoroFocusMsgController;
  late TextEditingController _pomodoroBreakMsgController;
  late TextEditingController _stopwatchCongratsMsgController;
  late TextEditingController _calendarMsgController;
  late TextEditingController _aiPersonaController;
  late TextEditingController _aiRelationshipController;
  late TextEditingController _aiToneController;
  late TextEditingController _aiGreetingController;
  late TextEditingController _aiBackgroundController;
  late TextEditingController _aiDialogueExamplesController;
  bool _isAiEnabled = true;

  List<MessageBundle> _bundles = [];
  bool _isLoadingBundles = false;

  String? _avatarPath;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.character?.name ?? '');
    _titleController = TextEditingController(text: widget.character?.title ?? '');
    _morningMsgController = TextEditingController(text: widget.character?.defaultMorningMessage ?? '');
    _pomodoroFocusMsgController = TextEditingController(text: widget.character?.defaultPomodoroFocusEndMessage ?? '');
    _pomodoroBreakMsgController = TextEditingController(text: widget.character?.defaultPomodoroBreakEndMessage ?? '');
    _stopwatchCongratsMsgController = TextEditingController(text: widget.character?.defaultStopwatchCongratsMessage ?? '');
    _calendarMsgController = TextEditingController(text: widget.character?.defaultCalendarMessage ?? '');
    _aiPersonaController = TextEditingController(text: widget.character?.aiPersonaPrompt ?? '');
    _aiRelationshipController = TextEditingController(text: widget.character?.aiRelationship ?? '');
    _aiToneController = TextEditingController(text: widget.character?.aiTone ?? '');
    _aiGreetingController = TextEditingController(text: widget.character?.aiGreeting ?? '');
    _aiBackgroundController = TextEditingController(text: widget.character?.aiBackground ?? '');
    _aiDialogueExamplesController = TextEditingController(text: widget.character?.aiDialogueExamples ?? '');
    _isAiEnabled = widget.character?.isAiEnabled ?? true;
    _avatarPath = widget.character?.avatarPath;

    if (widget.character != null) {
      _loadBundles();
    }
  }

  Future<void> _loadBundles() async {
    if (widget.character == null) return;
    setState(() => _isLoadingBundles = true);
    final bundles = await StorageService.instance.getMessageBundlesByCharacter(widget.character!.id);
    if (mounted) {
      setState(() {
        _bundles = bundles;
        _isLoadingBundles = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _titleController.dispose();
    _morningMsgController.dispose();
    _pomodoroFocusMsgController.dispose();
    _pomodoroBreakMsgController.dispose();
    _stopwatchCongratsMsgController.dispose();
    _calendarMsgController.dispose();
    _aiPersonaController.dispose();
    _aiRelationshipController.dispose();
    _aiToneController.dispose();
    _aiGreetingController.dispose();
    _aiBackgroundController.dispose();
    _aiDialogueExamplesController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      if (kIsWeb) {
        setState(() {
          _avatarPath = picked.path;
        });
      } else {
        final permanentPath = await StorageService.instance.saveImagePermanently(File(picked.path));
        setState(() {
          _avatarPath = permanentPath;
        });
      }
    }
  }

  Future<void> _navigateToAddBundle() async {
    if (widget.character == null) return;
    final result = await Navigator.push<MessageBundle>(
      context,
      MaterialPageRoute(
        builder: (_) => BundleEditScreen(character: widget.character!),
      ),
    );
    if (result != null) {
      _loadBundles();
    }
  }

  Future<void> _navigateToEditBundle(MessageBundle bundle) async {
    if (widget.character == null) return;
    final result = await Navigator.push<MessageBundle>(
      context,
      MaterialPageRoute(
        builder: (_) => BundleEditScreen(
          character: widget.character!,
          bundle: bundle,
        ),
      ),
    );
    if (result != null) {
      _loadBundles();
    }
  }

  Future<void> _deleteBundle(MessageBundle bundle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('시나리오 삭제'),
        content: Text('\'${bundle.title}\' 시나리오를 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await StorageService.instance.deleteMessageBundle(bundle.id);
      _loadBundles();
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final id = widget.character?.id ?? const Uuid().v4();
    final profile = CharacterProfile(
      id: id,
      name: _nameController.text.trim(),
      avatarPath: _avatarPath,
      title: _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
      defaultMorningMessage: _morningMsgController.text.trim().isEmpty ? null : _morningMsgController.text.trim(),
      defaultPomodoroFocusEndMessage: _pomodoroFocusMsgController.text.trim().isEmpty ? null : _pomodoroFocusMsgController.text.trim(),
      defaultPomodoroBreakEndMessage: _pomodoroBreakMsgController.text.trim().isEmpty ? null : _pomodoroBreakMsgController.text.trim(),
      defaultStopwatchCongratsMessage: _stopwatchCongratsMsgController.text.trim().isEmpty ? null : _stopwatchCongratsMsgController.text.trim(),
      defaultCalendarMessage: _calendarMsgController.text.trim().isEmpty ? null : _calendarMsgController.text.trim(),
      aiPersonaPrompt: _aiPersonaController.text.trim().isEmpty ? null : _aiPersonaController.text.trim(),
      isAiEnabled: _isAiEnabled,
      aiRelationship: _aiRelationshipController.text.trim().isEmpty ? null : _aiRelationshipController.text.trim(),
      aiTone: _aiToneController.text.trim().isEmpty ? null : _aiToneController.text.trim(),
      aiGreeting: _aiGreetingController.text.trim().isEmpty ? null : _aiGreetingController.text.trim(),
      aiBackground: _aiBackgroundController.text.trim().isEmpty ? null : _aiBackgroundController.text.trim(),
      aiDialogueExamples: _aiDialogueExamplesController.text.trim().isEmpty ? null : _aiDialogueExamplesController.text.trim(),
      createdAt: widget.character?.createdAt ?? DateTime.now(),
    );

    await StorageService.instance.saveCharacter(profile);

    if (mounted) {
      Navigator.pop(context, profile);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.character != null;
    final theme = Theme.of(context);

    final charName = _nameController.text;
    final callName = _titleController.text;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? '캐릭터 수정' : '새 캐릭터 등록'),
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
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 프로필 사진 선택 영역
              Center(
                child: Stack(
                  children: [
                    CharacterAvatar(
                      name: _nameController.text,
                      avatarPath: _avatarPath,
                      radius: 54,
                      onTap: _pickAvatar,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickAvatar,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _pickAvatar,
                  child: const Text('갤러리에서 사진 등록'),
                ),
              ),
              const SizedBox(height: 24),

              // 섹션 1: 기본 정보
              Text(
                '기본 정보',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 12),

              // 이름 입력
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: '이름 / 닉네임',
                  hintText: '알림 발신자로 표시될 이름을 입력하세요',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return '이름을 입력해 주세요';
                  }
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),

              // 호칭 / 애칭 입력
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: '나를 부르는 호칭 / 애칭 (선택)',
                  hintText: '상대방이 나를 부를 호칭 (예: 선배, 00아, 자기야 등)',
                  prefixIcon: const Icon(Icons.tag_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  helperText: '※ 알림 문구에 \'{호칭}\'을 넣으면 이 호칭으로 자동 치환되어 발송됩니다.',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 32),

              // 섹션 2: 캐릭터 전용 기본 푸시 알림 문구 설정
              Row(
                children: [
                  Icon(Icons.notifications_active_outlined, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    '기능별 기본 푸시 알림 문구',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '각 기능에서 알림이 울릴 때 사용할 기본 문구입니다. 버튼을 눌러 {호칭}이나 {이름}을 간편하게 삽입해 보세요.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),

              // 1. 알람 기본 문구
              MessageInputField(
                controller: _morningMsgController,
                label: '알람 기본 문구',
                hint: '좋은 아침이야, {호칭}! 오늘도 힘차게 시작해볼까?',
                characterName: charName,
                callName: callName,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 16),

              // 2. 뽀모도로 집중 완료 문구
              MessageInputField(
                controller: _pomodoroFocusMsgController,
                label: '뽀모도로 집중 완료 알림 문구',
                hint: '{호칭}, 집중 시간 끝났어! 푹 쉬자~',
                characterName: charName,
                callName: callName,
                showTimeTag: true,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 16),

              // 3. 뽀모도로 휴식 완료 문구
              MessageInputField(
                controller: _pomodoroBreakMsgController,
                label: '뽀모도로 휴식 완료 알림 문구',
                hint: '{호칭}, 휴식 시간 끝! 이제 다시 집중해볼까?',
                characterName: charName,
                callName: callName,
                showTimeTag: true,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 16),

              // 4. 스톱워치 목표 달성 문구
              MessageInputField(
                controller: _stopwatchCongratsMsgController,
                label: '스톱워치 목표 달성 축하 문구',
                hint: '{호칭}, 목표 시간 달성 완료! 오늘 하루도 정말 멋졌어!',
                characterName: charName,
                callName: callName,
                showTimeTag: true,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 16),

              // 5. 캘린더 일정 알림 문구
              MessageInputField(
                controller: _calendarMsgController,
                label: '캘린더 일정 알림 기본 문구',
                hint: '{호칭}, 오늘 {일정} 있는 날이야! 잊지 마~',
                characterName: charName,
                callName: callName,
                showScheduleTag: true,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 32),

              // 섹션 3: AI 캐릭터 성격 및 말투 (AI 페르소나)
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        secondary: Icon(Icons.smart_toy_outlined, color: theme.colorScheme.primary),
                        title: const Text('AI 캐릭터 페르소나 기능 사용', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        subtitle: Text(
                          _isAiEnabled
                              ? 'AI 실시간 대화 및 맞춤 알림 발송 시 성격과 말투가 적용됩니다.'
                              : '비활성화됨 (기본 문구와 시나리오만 사용)',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        value: _isAiEnabled,
                        onChanged: (val) => setState(() => _isAiEnabled = val),
                      ),
                      if (_isAiEnabled) ...[
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.tune_rounded, size: 18, color: theme.colorScheme.primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    '페르소나 상세 설정 (성격 및 말투 지침)',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '캐릭터가 대화 및 맞춤 알림 발송 시 유지할 성격과 말투, 관계를 설정해주세요.',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 16),

                              // 1. 사용자와의 관계
                              Row(
                                children: [
                                  Icon(Icons.people_alt_outlined, size: 16, color: theme.colorScheme.primary),
                                  const SizedBox(width: 6),
                                  const Text('사용자와의 관계', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                children: ['연인', '소꿉친구', '직속 선배', '짝사랑', '아이돌과 팬', '집사/메이드'].map((item) {
                                  return ChoiceChip(
                                    label: Text(item, style: const TextStyle(fontSize: 11)),
                                    selected: _aiRelationshipController.text == item,
                                    onSelected: (sel) {
                                      if (sel) {
                                        _aiRelationshipController.text = item;
                                        setState(() {});
                                      }
                                    },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _aiRelationshipController,
                                decoration: InputDecoration(
                                  hintText: '직접 입력 (예: 10년 지기 소꿉친구, 비밀 연인 등)',
                                  hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // 2. 말투 및 어조 스타일
                              Row(
                                children: [
                                  Icon(Icons.record_voice_over_outlined, size: 16, color: theme.colorScheme.primary),
                                  const SizedBox(width: 6),
                                  const Text('말투 및 어조 스타일', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                children: ['다정한 반말', '장난스러운 반말', '정중한 존댓말', '츤데레 말투', '애교 넘치는 어조'].map((item) {
                                  return ChoiceChip(
                                    label: Text(item, style: const TextStyle(fontSize: 11)),
                                    selected: _aiToneController.text == item,
                                    onSelected: (sel) {
                                      if (sel) {
                                        _aiToneController.text = item;
                                        setState(() {});
                                      }
                                    },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _aiToneController,
                                decoration: InputDecoration(
                                  hintText: '직접 입력 (예: 부드러운 반말, 끝에 ~했어? 붙임 등)',
                                  hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // 3. 캐릭터 배경 및 세계관
                              Row(
                                children: [
                                  Icon(Icons.history_edu_outlined, size: 16, color: theme.colorScheme.primary),
                                  const SizedBox(width: 6),
                                  const Text('3. 캐릭터 배경 및 세계관', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '캐릭터의 직업, 성격, 나이, 상황, 사용자와의 과거 서사 등을 자유롭게 적어주세요.',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _aiBackgroundController,
                                maxLines: 2,
                                decoration: InputDecoration(
                                  hintText: '예: 바쁜 아이돌이지만 사용자 메시지는 가장 먼저 봄. 피아노와 음악을 좋아함.',
                                  hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.all(12),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // 4. 대표 대화 예시 (Few-shot)
                              Row(
                                children: [
                                  Icon(Icons.chat_outlined, size: 16, color: theme.colorScheme.primary),
                                  const SizedBox(width: 6),
                                  const Text('4. 대표 대화 예시 (Few-shot)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '실제 대화 스타일을 보고 배울 수 있도록 유저와 캐릭터 간의 대사 샘플을 적어주세요.',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _aiDialogueExamplesController,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  hintText: '나: "오늘 너무 피곤했어"\n캐릭터: "고생 많았어... 얼른 따뜻한 물로 씻고 푹 자."',
                                  hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.all(12),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // 5. 추가 세부 지침 (커스텀 시스템 프롬프트)
                              Row(
                                children: [
                                  Icon(Icons.rule_folder_outlined, size: 16, color: theme.colorScheme.primary),
                                  const SizedBox(width: 6),
                                  const Text('5. 추가 세부 지침 (금기사항 등)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '대화 시 꼭 지켜야 할 규칙이나 기타 세부사항을 적어주세요.',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _aiPersonaController,
                                maxLines: 2,
                                decoration: InputDecoration(
                                  hintText: '예: AI 티 내지 말 것, 1~2문장의 자연스러운 메신저 어조 유지.',
                                  hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.all(12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // 섹션 4: 대화 시나리오 (연속 알림) 관리
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.mark_chat_unread_outlined, size: 20, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        '대화 시나리오 (연속 알림)',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                      ),
                    ],
                  ),
                  if (isEditing)
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('시나리오 추가'),
                      style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                      onPressed: _navigateToAddBundle,
                    ),
                ],
              ),
               const SizedBox(height: 6),
               Text(
                 '알림이 울릴 때 실제 메신저 대화처럼 여러 개의 메시지가 연속으로 도착하는 시나리오입니다.',
                 style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
               ),
               const SizedBox(height: 12),

               if (!isEditing)
                 Container(
                   width: double.infinity,
                   padding: const EdgeInsets.all(16),
                   decoration: BoxDecoration(
                     color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                     borderRadius: BorderRadius.circular(12),
                     border: Border.all(color: Colors.grey.shade300),
                   ),
                   child: Row(
                     children: [
                       Icon(Icons.info_outline, size: 20, color: theme.colorScheme.primary),
                       const SizedBox(width: 12),
                       const Expanded(
                         child: Text(
                           '캐릭터를 먼저 저장한 후, 상세 화면에서 대화 시나리오를 추가할 수 있습니다.',
                           style: TextStyle(fontSize: 13),
                         ),
                       ),
                     ],
                   ),
                 )
               else if (_isLoadingBundles)
                 const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
               else if (_bundles.isEmpty)
                 Card(
                   elevation: 0,
                   color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                   child: Padding(
                     padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                     child: Center(
                       child: Column(
                         children: [
                           Icon(Icons.chat_bubble_outline, size: 36, color: Colors.grey.shade400),
                           const SizedBox(height: 8),
                           const Text('등록된 대화 시나리오가 없습니다.', style: TextStyle(fontWeight: FontWeight.bold)),
                           const SizedBox(height: 4),
                           Text(
                             '대화 시나리오를 등록하면 상황에 맞추어 생생한 연속 알림을 받을 수 있습니다.',
                             style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                             textAlign: TextAlign.center,
                           ),
                           const SizedBox(height: 12),
                           FilledButton.icon(
                             icon: const Icon(Icons.add, size: 18),
                             label: const Text('첫 대화 시나리오 만들기'),
                             onPressed: _navigateToAddBundle,
                           ),
                         ],
                       ),
                     ),
                   ),
                 )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _bundles.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final b = _bundles[index];
                    return Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Text(
                            '${b.messages.length}',
                            style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onPrimaryContainer),
                          ),
                        ),
                        title: Text(b.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text(
                          '${b.intervalSeconds}초 간격 · 첫 메시지: "${b.messages.isNotEmpty ? b.messages.first : ''}"',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              tooltip: '수정',
                              onPressed: () => _navigateToEditBundle(b),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                              tooltip: '삭제',
                              onPressed: () => _deleteBundle(b),
                            ),
                          ],
                        ),
                        onTap: () => _navigateToEditBundle(b),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
