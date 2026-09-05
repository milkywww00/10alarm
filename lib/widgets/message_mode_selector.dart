import 'package:flutter/material.dart';
import '../models/character_profile.dart';
import '../models/message_bundle.dart';
import '../services/ai_chat_service.dart';
import '../utils/message_formatter.dart';

class MessageModeSelector extends StatelessWidget {
  final String currentMode; // 'SINGLE', 'AI', 'RANDOM', 'BUNDLE'
  final ValueChanged<String> onModeChanged;
  final TextEditingController messageController;
  final String label;
  final String hint;
  final CharacterProfile? character;
  final List<MessageBundle> bundles;
  final String? selectedBundleId;
  final ValueChanged<String?> onBundleSelected;
  final bool showScheduleTag;
  final bool showTimeTag;
  final int maxLines;
  final VoidCallback? onAddBundle;

  const MessageModeSelector({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
    required this.messageController,
    required this.label,
    required this.hint,
    required this.character,
    required this.bundles,
    required this.selectedBundleId,
    required this.onBundleSelected,
    this.showScheduleTag = false,
    this.showTimeTag = false,
    this.maxLines = 2,
    this.onAddBundle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final charName = character?.name ?? '';

    final rawText = messageController.text.trim().isNotEmpty
        ? messageController.text.trim()
        : hint;
    final resolvedPreview = character != null
        ? MessageFormatter.format(rawText, character: character)
        : rawText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'SINGLE',
                icon: Icon(Icons.chat_bubble_outline),
                label: Text('기본 문구'),
              ),
              ButtonSegment(
                value: 'AI',
                icon: Icon(Icons.auto_awesome_rounded),
                label: Text('AI 맞춤'),
              ),
              ButtonSegment(
                value: 'RANDOM',
                icon: Icon(Icons.casino_outlined),
                label: Text('선택 랜덤'),
              ),
              ButtonSegment(
                value: 'BUNDLE',
                icon: Icon(Icons.folder_outlined),
                label: Text('시나리오'),
              ),
            ],
            selected: {currentMode},
            onSelectionChanged: (newSelection) {
              onModeChanged(newSelection.first);
            },
          ),
        ),
        const SizedBox(height: 14),

        // 0. AI 맞춤 생성 알림 모드
        if (currentMode == 'AI') ...[
          Builder(
            builder: (context) {
              final isConfigured = AiChatService.instance.isConfigured;
              final isCharAiEnabled = character?.isAiEnabled ?? true;

              return Card(
                elevation: 0,
                color: theme.colorScheme.primary.withValues(alpha: 0.07),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.auto_awesome_rounded, size: 20, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'AI 맞춤 생성 알림',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isConfigured && isCharAiEnabled ? '실시간 생성 활성' : '설정 필요',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isConfigured && isCharAiEnabled ? theme.colorScheme.primary : Colors.orange.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '알림이 울릴 때마다 \'$charName\'의 페르소나(성격 및 말투)에 맞춰 AI가 실시간으로 새로운 알림 문구를 직접 생성하여 보내줍니다.',
                        style: const TextStyle(fontSize: 13, height: 1.4),
                      ),
                      if (character?.aiPersonaPrompt != null && character!.aiPersonaPrompt!.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '적용될 페르소나 지침:',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                character!.aiPersonaPrompt!,
                                style: const TextStyle(fontSize: 12, color: Colors.black87),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (!isConfigured) ...[
                        const SizedBox(height: 8),
                        Text(
                          '⚠️ 앱 설정에서 AI API 키를 먼저 등록해 주세요. (미등록 시 기본 문구로 안전하게 대체 발송됩니다)',
                          style: TextStyle(fontSize: 11, color: Colors.orange.shade800, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ] else if (currentMode == 'SINGLE') ...[
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.format_quote_rounded, size: 20, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        '캐릭터 기본 알림 문구',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    resolvedPreview.isNotEmpty ? resolvedPreview : '설정된 기본 문구가 없습니다.',
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '※ 문구 수정은 [캐릭터 설정]에서 언제든 변경할 수 있습니다.',
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
                  ),
                ],
              ),
            ),
          ),
        ] else if (currentMode == 'RANDOM') ...[
          // 2. 선택한 대화 시나리오 중 랜덤 발송 모드
          Builder(
            builder: (context) {
              final Set<String> selectedRandomIds = () {
                if (selectedBundleId == null || selectedBundleId == 'RANDOM') {
                  return bundles.map((b) => b.id).toSet();
                }
                if (selectedBundleId!.startsWith('RANDOM:')) {
                  final raw = selectedBundleId!.substring(7);
                  if (raw.isEmpty) return <String>{};
                  return raw.split(',').where((id) => id.isNotEmpty).toSet();
                }
                return bundles.map((b) => b.id).toSet();
              }();

              return Card(
                elevation: 0,
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.casino_rounded, size: 20, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            '선택한 시나리오 중 랜덤 발송',
                            style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        character != null
                            ? '\'$charName\'의 선택된 시나리오(${selectedRandomIds.length}/${bundles.length}개) 중 하나가 알림마다 무작위로 발송됩니다.'
                            : '선택된 시나리오 중 하나가 무작위로 발송됩니다.',
                        style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                      ),
                      if (bundles.isEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, size: 18, color: Colors.amber.shade900),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '등록된 대화 시나리오가 없습니다. 캐릭터 설정에서 시나리오를 먼저 추가해 주세요.',
                                  style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '랜덤 추첨 대상 시나리오',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                            ),
                            Row(
                              children: [
                                TextButton(
                                  onPressed: () {
                                    onBundleSelected('RANDOM');
                                  },
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                  ),
                                  child: const Text('전체 선택', style: TextStyle(fontSize: 12)),
                                ),
                                TextButton(
                                  onPressed: () {
                                    onBundleSelected('RANDOM:');
                                  },
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                  ),
                                  child: const Text('선택 해제', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: bundles.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final b = bundles[index];
                            final isChecked = selectedRandomIds.contains(b.id);
                            return InkWell(
                              onTap: () {
                                final newSet = Set<String>.from(selectedRandomIds);
                                if (isChecked) {
                                  newSet.remove(b.id);
                                } else {
                                  newSet.add(b.id);
                                }
                                if (newSet.length == bundles.length) {
                                  onBundleSelected('RANDOM');
                                } else {
                                  onBundleSelected('RANDOM:${newSet.join(',')}');
                                }
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isChecked
                                      ? theme.colorScheme.surface
                                      : theme.colorScheme.surface.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isChecked
                                        ? theme.colorScheme.primary
                                        : Colors.grey.shade300,
                                    width: isChecked ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isChecked ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                      size: 20,
                                      color: isChecked ? theme.colorScheme.primary : Colors.grey,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            b.title,
                                            style: TextStyle(
                                              fontWeight: isChecked ? FontWeight.bold : FontWeight.normal,
                                              fontSize: 13,
                                            ),
                                          ),
                                          Text(
                                            '${b.messages.length}개 대화 메시지 · ${b.intervalSeconds}초 간격',
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        if (selectedRandomIds.isEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            '※ 아무것도 선택하지 않으면 전체 시나리오 중 무작위로 발송됩니다.',
                            style: TextStyle(fontSize: 11, color: theme.colorScheme.error),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ] else if (currentMode == 'BUNDLE') ...[
          // 3. 특정 시나리오 선택 모드
          if (bundles.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '\'$charName\'에게 등록된 대화 시나리오가 없습니다. 캐릭터 설정에서 시나리오를 먼저 추가해 주세요.',
                      style: TextStyle(fontSize: 13, color: Colors.amber.shade900),
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selectedBundleId != null && bundles.any((b) => b.id == selectedBundleId)
                          ? selectedBundleId
                          : bundles.first.id,
                      items: bundles.map((b) {
                        return DropdownMenuItem<String>(
                          value: b.id,
                          child: Text(
                            '${b.title} (${b.messages.length}개 메시지, ${b.intervalSeconds}초 간격)',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: onBundleSelected,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Builder(
                  builder: (context) {
                    final currentId = selectedBundleId != null && bundles.any((b) => b.id == selectedBundleId)
                        ? selectedBundleId
                        : bundles.first.id;
                    final b = bundles.firstWhere((item) => item.id == currentId, orElse: () => bundles.first);
                    return Card(
                      elevation: 0,
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '선택된 시나리오 미리보기 (${b.intervalSeconds}초 간격)',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ...b.messages.asMap().entries.map(
                              (entry) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Text(
                                  '${entry.key + 1}. ${character != null ? MessageFormatter.format(entry.value, character: character) : entry.value}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
        ],
      ],
    );
  }
}
