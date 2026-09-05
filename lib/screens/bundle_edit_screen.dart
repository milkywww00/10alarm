import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/character_profile.dart';
import '../models/message_bundle.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../widgets/message_input_field.dart';

class BundleEditScreen extends StatefulWidget {
  final CharacterProfile character;
  final MessageBundle? bundle;

  const BundleEditScreen({
    super.key,
    required this.character,
    this.bundle,
  });

  @override
  State<BundleEditScreen> createState() => _BundleEditScreenState();
}

class _BundleEditScreenState extends State<BundleEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late int _intervalSeconds;
  final List<TextEditingController> _msgControllers = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.bundle?.title ?? '');
    _intervalSeconds = widget.bundle?.intervalSeconds ?? 2;

    if (widget.bundle != null && widget.bundle!.messages.isNotEmpty) {
      for (final msg in widget.bundle!.messages) {
        _msgControllers.add(TextEditingController(text: msg));
      }
    } else {
      // 신규 등록 시 기본 2개 빈 입력창 제공
      _msgControllers.add(TextEditingController());
      _msgControllers.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (final c in _msgControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addMessageField() {
    setState(() {
      _msgControllers.add(TextEditingController());
    });
  }

  void _removeMessageField(int index) {
    if (_msgControllers.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('메시지는 최소 1개 이상 필요합니다.')),
      );
      return;
    }
    setState(() {
      final removed = _msgControllers.removeAt(index);
      removed.dispose();
    });
  }

  Future<void> _previewBurst() async {
    final messages = _msgControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
    if (messages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('테스트할 메시지를 1개 이상 입력해 주세요.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${widget.character.name}님의 순차 알림(${messages.length}건)을 전송합니다.')),
    );

    await NotificationService.instance.showSequentialCharacterNotifications(
      baseId: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      character: widget.character,
      messages: messages,
      intervalSeconds: _intervalSeconds,
      payload: '${widget.character.id}#preview_bundle',
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final messages = _msgControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
    if (messages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('최소 1개 이상의 유효한 메시지를 입력해 주세요.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final id = widget.bundle?.id ?? const Uuid().v4();
    final bundle = MessageBundle(
      id: id,
      characterId: widget.character.id,
      title: _titleController.text.trim(),
      messages: messages,
      intervalSeconds: _intervalSeconds,
      createdAt: widget.bundle?.createdAt ?? DateTime.now(),
    );

    await StorageService.instance.saveMessageBundle(bundle);

    if (mounted) {
      Navigator.pop(context, bundle);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.bundle != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? '대화 시나리오 수정' : '새 대화 시나리오 등록'),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_circle_outline),
            tooltip: '시나리오 알림 테스트',
            onPressed: _previewBurst,
          ),
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
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 시나리오 정보
              Text(
                '시나리오 정보',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: '시나리오 제목',
                  hintText: '예: 다정한 아침, 깨우기 대작전, 시험 응원 등',
                  prefixIcon: const Icon(Icons.folder_special_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return '시나리오 제목을 입력해 주세요';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // 전송 간격 설정
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.speed, size: 20),
                              SizedBox(width: 8),
                              Text('메시지 전송 간격', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                          Text(
                            '$_intervalSeconds초 간격',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Slider(
                        value: _intervalSeconds.toDouble(),
                        min: 1,
                        max: 5,
                        divisions: 4,
                        label: '$_intervalSeconds초',
                        onChanged: (val) {
                          setState(() {
                            _intervalSeconds = val.round();
                          });
                        },
                      ),
                      Text(
                        '실제 메신저처럼 $_intervalSeconds초마다 순차적으로 다음 알림 버블이 화면에 울립니다.',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 순차 메시지 리스트 헤더
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '대화 메시지 목록 (${_msgControllers.length}개)',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                  ),
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('문장 추가'),
                    style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                    onPressed: _addMessageField,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '상단에서부터 아래로 순서대로 전송됩니다. {호칭}을 넣으면 상대방이 나를 부르는 호칭으로 치환됩니다.',
                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),

              // 각 메시지 입력 카드 목록
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _msgControllers.length,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final delaySeconds = index * _intervalSeconds;
                  final timeLabel = index == 0 ? '시작 (0초)' : '+$delaySeconds초';

                  return Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '#${index + 1}번째 알림 ($timeLabel)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                              if (_msgControllers.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                  tooltip: '삭제',
                                  onPressed: () => _removeMessageField(index),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          MessageInputField(
                            controller: _msgControllers[index],
                            label: '발송 텍스트',
                            hint: '순차적으로 도착할 문구를 입력하세요',
                            characterName: widget.character.name,
                            callName: widget.character.title,
                            onChanged: () => setState(() {}),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // 하단 발송 테스트 안내 버튼
              Center(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('작성한 시나리오 알림 미리 테스트하기'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _previewBurst,
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
