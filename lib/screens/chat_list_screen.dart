import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/character_profile.dart';
import '../models/chat_message.dart';
import '../services/ai_chat_service.dart';
import '../services/storage_service.dart';
import '../widgets/character_avatar.dart';
import '../widgets/empty_state_view.dart';
import 'chat_simulation_screen.dart';
import 'settings_screen.dart';
import 'character_edit_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<CharacterProfile> _characters = [];
  Map<String, List<ChatMessage>> _messagesMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final characters = await StorageService.instance.getCharacters();
      final Map<String, List<ChatMessage>> map = {};

      for (final char in characters) {
        final msgs = await StorageService.instance.getChatMessages(char.id);
        map[char.id] = msgs;
      }

      if (mounted) {
        setState(() {
          _characters = characters;
          _messagesMap = map;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _openChat(CharacterProfile character) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatSimulationScreen(
          character: character,
        ),
      ),
    );
    _loadData();
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final isToday = now.year == dt.year && now.month == dt.month && now.day == dt.day;
    final isYesterday = now.difference(DateTime(dt.year, dt.month, dt.day)).inDays == 1;

    if (isToday) {
      final period = dt.hour < 12 ? '오전' : '오후';
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$period $hour:$minute';
    } else if (isYesterday) {
      return '어제';
    } else if (now.year == dt.year) {
      return '${dt.month}월 ${dt.day}일';
    } else {
      return '${dt.year}.${dt.month}.${dt.day}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasApiKey = AiChatService.instance.currentApiKey.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('메시지 대화', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '설정',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _characters.isEmpty
          ? EmptyStateView(
              icon: Icons.chat_bubble_outline_rounded,
              title: '등록된 캐릭터가 없습니다',
              description: '캐릭터를 등록하고 나만의 맞춤 AI와\n언제든 실시간으로 대화를 나눠보세요.',
              buttonText: '캐릭터 등록하기',
              onButtonPressed: () async {
                final result = await Navigator.push<CharacterProfile>(
                  context,
                  MaterialPageRoute(builder: (_) => const CharacterEditScreen()),
                );
                if (result != null) _loadData();
              },
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.only(top: 8, bottom: 80),
                children: [
                  // API 키 미설정 배너
                  if (!hasApiKey)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lightbulb_outline, color: Colors.amber.shade800, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'AI API 키를 설정하면 캐릭터들과 실시간으로 자유롭게 대화할 수 있어요!',
                              style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const SettingsScreen()),
                              );
                              if (mounted) setState(() {});
                            },
                            child: const Text('설정하기', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),

                  // 대화방 목록
                  ..._characters.map((char) {
                    final messages = _messagesMap[char.id] ?? [];
                    final hasMessages = messages.isNotEmpty;
                    final lastMsg = hasMessages ? messages.last : null;

                    String previewText;
                    if (lastMsg != null) {
                      previewText = lastMsg.text;
                    } else {
                      previewText = '알람을 수신하거나 탭하여 대화를 시작해보세요.';
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _openChat(char),
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Row(
                            children: [
                              // 아바타
                              Stack(
                                children: [
                                  CharacterAvatar(
                                    name: char.name,
                                    avatarPath: char.avatarPath,
                                    radius: 26,
                                  ),
                                  if (char.isAiEnabled)
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 1.5),
                                        ),
                                        child: const Icon(Icons.smart_toy_rounded, size: 10, color: Colors.white),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 14),

                              // 이름, 배지, 마지막 메시지
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          char.name,
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(width: 6),
                                        if (char.title != null && char.title!.isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.primaryContainer.withAlpha(120),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              char.title!,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: theme.colorScheme.onPrimaryContainer,
                                              ),
                                            ),
                                          ),
                                        if (char.aiRelationship != null && char.aiRelationship!.isNotEmpty) ...[
                                          const SizedBox(width: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.purple.shade50,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              char.aiRelationship!,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.purple.shade700,
                                              ),
                                            ),
                                          ),
                                        ],
                                        const Spacer(),
                                        if (lastMsg != null)
                                          Text(
                                            _formatTimestamp(lastMsg.timestamp),
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      previewText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: hasMessages ? Colors.grey.shade800 : Colors.grey.shade500,
                                        fontStyle: hasMessages ? FontStyle.normal : FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}
