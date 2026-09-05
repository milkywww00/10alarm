import 'package:flutter/material.dart';
import '../utils/message_formatter.dart';
import '../models/character_profile.dart';

class MessageInputField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final String characterName;
  final String? callName;
  final bool showScheduleTag;
  final bool showTimeTag;
  final int maxLines;
  final VoidCallback? onChanged;

  const MessageInputField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.characterName,
    this.callName,
    this.showScheduleTag = false,
    this.showTimeTag = false,
    this.maxLines = 2,
    this.onChanged,
  });

  @override
  State<MessageInputField> createState() => _MessageInputFieldState();
}

class _MessageInputFieldState extends State<MessageInputField> {
  void _insertTag(String tag) {
    final text = widget.controller.text;
    final selection = widget.controller.selection;

    if (selection.start >= 0 && selection.end >= 0) {
      final newText = text.replaceRange(selection.start, selection.end, tag);
      widget.controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + tag.length),
      );
    } else {
      final newText = text + tag;
      widget.controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    }
    setState(() {});
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = widget.controller.text;

    // 실시간 치환 미리보기 계산
    final mockChar = CharacterProfile(
      id: 'mock',
      name: widget.characterName.isNotEmpty ? widget.characterName : '캐릭터',
      title: widget.callName?.isNotEmpty == true ? widget.callName : '호칭',
      createdAt: DateTime.now(),
    );

    final previewText = MessageFormatter.format(
      text.isNotEmpty ? text : widget.hint,
      character: mockChar,
      scheduleTitle: '중요한 회의',
      timeText: '25분',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ActionChip(
              visualDensity: VisualDensity.compact,
              labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              avatar: const Icon(Icons.bookmark_outline, size: 14),
              label: const Text('{호칭}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              onPressed: () => _insertTag('{호칭}'),
            ),
            ActionChip(
              visualDensity: VisualDensity.compact,
              labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              avatar: const Icon(Icons.person_outline, size: 14),
              label: const Text('{이름}', style: TextStyle(fontSize: 12)),
              onPressed: () => _insertTag('{이름}'),
            ),
            if (widget.showScheduleTag)
              ActionChip(
                visualDensity: VisualDensity.compact,
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                avatar: const Icon(Icons.event_outlined, size: 14),
                label: const Text('{일정}', style: TextStyle(fontSize: 12)),
                onPressed: () => _insertTag('{일정}'),
              ),
            if (widget.showTimeTag)
              ActionChip(
                visualDensity: VisualDensity.compact,
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                avatar: const Icon(Icons.timer_outlined, size: 14),
                label: const Text('{시간}', style: TextStyle(fontSize: 12)),
                onPressed: () => _insertTag('{시간}'),
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: widget.controller,
          maxLines: widget.maxLines,
          decoration: InputDecoration(
            hintText: widget.hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          onChanged: (_) {
            setState(() {});
            widget.onChanged?.call();
          },
        ),
        const SizedBox(height: 6),
        // 실시간 치환 알림 미리보기 배너
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.notifications_active_outlined, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '[알림 미리보기] ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      TextSpan(
                        text: previewText,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                          fontStyle: text.isEmpty ? FontStyle.italic : FontStyle.normal,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
