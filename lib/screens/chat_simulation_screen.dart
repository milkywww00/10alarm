import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/alarm_item.dart';
import '../models/character_profile.dart';
import '../models/chat_message.dart';
import '../services/ai_chat_service.dart';
import '../services/storage_service.dart';
import '../utils/message_formatter.dart';
import '../widgets/character_avatar.dart';
import 'settings_screen.dart';

class ChatSimulationScreen extends StatefulWidget {
  final CharacterProfile character;
  final AlarmItem? alarm;
  final String? initialMessage;

  const ChatSimulationScreen({
    super.key,
    required this.character,
    this.alarm,
    this.initialMessage,
  });

  @override
  State<ChatSimulationScreen> createState() => _ChatSimulationScreenState();
}

class _ChatSimulationScreenState extends State<ChatSimulationScreen> with SingleTickerProviderStateMixin {
  final List<ChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  bool _isTyping = false;

  final List<String> _quickReplies = [
    '응 일어났어!',
    '좋은 아침이야~',
    '오늘도 파이팅할게!',
    '오늘 하루는 어땠어?',
    '보고 싶었어!',
  ];

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    try {
      final saved = await StorageService.instance.getChatMessages(widget.character.id);

      if (!mounted) return;
      setState(() {
        _messages.addAll(saved);
        _isLoading = false;
      });

      _scrollToBottom(immediate: true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return;

    final userMsg = ChatMessage(
      id: const Uuid().v4(),
      characterId: widget.character.id,
      text: clean,
      isMe: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _inputController.clear();
    });

    await StorageService.instance.saveChatMessage(userMsg);
    _scrollToBottom();

    // AI 응답 처리
    final isAiEnabled = AiChatService.instance.isAiEnabledNotifier.value && widget.character.isAiEnabled;
    final isConfigured = AiChatService.instance.isConfigured;

    if (isAiEnabled && isConfigured) {
      setState(() => _isTyping = true);
      _scrollToBottom();

      try {
        final effectiveContext = widget.initialMessage != null && widget.initialMessage!.isNotEmpty
            ? '최근 수신 알람 메시지: "${widget.initialMessage}"'
            : (widget.alarm != null && widget.alarm!.message.isNotEmpty
                ? '설정된 알람 메시지: "${widget.alarm!.message}"'
                : null);

        final replyText = await AiChatService.instance.generateCharacterReply(
          character: widget.character,
          history: _messages,
          userMessage: clean,
          contextInfo: effectiveContext,
        );

        if (!mounted) return;

        final replyMsg = ChatMessage(
          id: const Uuid().v4(),
          characterId: widget.character.id,
          text: replyText,
          isMe: false,
          timestamp: DateTime.now(),
        );

        setState(() {
          _isTyping = false;
          _messages.add(replyMsg);
        });

        await StorageService.instance.saveChatMessage(replyMsg);
        _scrollToBottom();
      } catch (e) {
        if (!mounted) return;
        setState(() => _isTyping = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI 응답 생성 실패: $e'),
            action: SnackBarAction(
              label: '설정 확인',
              onPressed: () => _navigateToSettings(),
            ),
          ),
        );
      }
    } else {
      // AI 키 미등록 시 기본 반응 또는 설정 안내
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        _showApiKeySnackbar();
      });
    }
  }

  void _showApiKeySnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('💡 AI API 키를 등록하면 \'${widget.character.name}\'와 실시간으로 자유롭게 대화할 수 있어요!'),
        action: SnackBarAction(
          label: 'API 키 등록',
          onPressed: _navigateToSettings,
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _navigateToSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    if (mounted) setState(() {});
  }

  void _showPersonaInfoDialog() {
    final c = widget.character;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            CharacterAvatar(name: c.name, avatarPath: c.avatarPath, radius: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${c.name} 프로필 & 페르소나',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoRow('나를 부르는 호칭', c.title ?? '호칭 미지정'),
              _buildInfoRow('관계 설정', c.aiRelationship ?? '친근한 사이'),
              _buildInfoRow('말투 / 어조', c.aiTone ?? '다정하고 친근한 어조'),
              if (c.aiBackground != null && c.aiBackground!.isNotEmpty)
                _buildInfoRow('배경 / 세계관', c.aiBackground!),
              if (c.defaultMorningMessage != null && c.defaultMorningMessage!.isNotEmpty)
                _buildInfoRow('대표 알람 문구', c.defaultMorningMessage!),
              const Divider(height: 20),
              Row(
                children: [
                  const Icon(Icons.smart_toy_outlined, size: 16, color: Colors.blueGrey),
                  const SizedBox(width: 6),
                  Text(
                    'AI 상태: ${c.isAiEnabled ? "활성화됨" : "비활성화"} (${AiChatService.instance.providerNotifier.value.toUpperCase()})',
                    style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  Future<void> _clearChatHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('대화 내용 비우기'),
        content: Text('\'${widget.character.name}\'와의 대화 기록을 모두 지우시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('지우기'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await StorageService.instance.clearChatMessages(widget.character.id);
      setState(() => _messages.clear());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('대화 기록이 모두 초기화되었습니다.')),
        );
      }
    }
  }

  void _scrollToBottom({bool immediate = false}) {
    Future.delayed(Duration(milliseconds: immediate ? 50 : 100), () {
      if (_scrollController.hasClients) {
        if (immediate) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        } else {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  String _formatTime(DateTime dt) {
    final period = dt.hour < 12 ? '오전' : '오후';
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    return '$period $hour:$min';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isConfigured = AiChatService.instance.isConfigured;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: GestureDetector(
          onTap: _showPersonaInfoDialog,
          child: Row(
            children: [
              CharacterAvatar(
                name: widget.character.name,
                avatarPath: widget.character.avatarPath,
                radius: 18,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.character.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _isTyping
                        ? '입력 중...'
                        : (widget.character.aiRelationship != null && widget.character.aiRelationship!.isNotEmpty
                            ? widget.character.aiRelationship!
                            : (widget.character.title != null && widget.character.title!.isNotEmpty
                                ? '${widget.character.title}의 최애'
                                : '대화 가능')),
                    style: TextStyle(
                      fontSize: 12,
                      color: _isTyping ? theme.colorScheme.primary : Colors.grey.shade600,
                      fontWeight: _isTyping ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: '페르소나 & 정보 보기',
            onPressed: _showPersonaInfoDialog,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (val) {
              if (val == 'settings') {
                _navigateToSettings();
              } else if (val == 'persona') {
                _showPersonaInfoDialog();
              } else if (val == 'clear') {
                _clearChatHistory();
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'persona',
                child: Row(
                  children: [
                    Icon(Icons.badge_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('페르소나 및 설정 정보'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.smart_toy_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('AI API 키 설정'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('대화 내용 비우기', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // AI API 키 미등록 안내 배너
          if (!isConfigured)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AI API 키를 등록하면 \'${widget.character.name}\'와 실시간 대화가 가능해요!',
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: _navigateToSettings,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('등록하기', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

          // 메시지 목록 영역
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CharacterAvatar(
                                name: widget.character.name,
                                avatarPath: widget.character.avatarPath,
                                radius: 36,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '\'${widget.character.name}\'와의 대화방',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '아직 알림이나 나눈 대화가 없습니다.\n알람이 울리면 자동으로 메시지가 기록되며,\n직접 메시지를 보내 대화를 시작할 수도 있습니다.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        itemCount: _messages.length + (_isTyping ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (_isTyping && index == _messages.length) {
                            // 타이핑 인디케이터
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  CharacterAvatar(
                                    name: widget.character.name,
                                    avatarPath: widget.character.avatarPath,
                                    radius: 14,
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '\'${widget.character.name}\' 입력 중',
                                          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                                        ),
                                    const SizedBox(width: 6),
                                    SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(strokeWidth: 1.5, color: theme.colorScheme.primary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final msg = _messages[index];
                      if (msg.isMe) {
                        // 내가 보낸 메시지
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _formatTime(msg.timestamp),
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(16),
                                      topRight: Radius.circular(4),
                                      bottomLeft: Radius.circular(16),
                                      bottomRight: Radius.circular(16),
                                    ),
                                  ),
                                  child: Text(
                                    msg.text,
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      } else {
                        // 캐릭터가 보낸 메시지
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CharacterAvatar(
                                name: widget.character.name,
                                avatarPath: widget.character.avatarPath,
                                radius: 18,
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.character.name,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Flexible(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
                                              borderRadius: const BorderRadius.only(
                                                topLeft: Radius.circular(4),
                                                topRight: Radius.circular(16),
                                                bottomLeft: Radius.circular(16),
                                                bottomRight: Radius.circular(16),
                                              ),
                                            ),
                                            child: Text(
                                              msg.text,
                                              style: TextStyle(
                                                color: theme.colorScheme.onSurface,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _formatTime(msg.timestamp),
                                          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                  ),
          ),

          // 빠른 답장 칩 (Quick Replies)
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _quickReplies.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final reply = _quickReplies[index];
                return ActionChip(
                  label: Text(reply, style: const TextStyle(fontSize: 12)),
                  onPressed: () => _sendMessage(reply),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // 메시지 입력창
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      decoration: InputDecoration(
                        hintText: '\'${widget.character.name}\'에게 답장하기...',
                        hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      onSubmitted: _sendMessage,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _sendMessage(_inputController.text),
                    icon: const Icon(Icons.send_rounded),
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
