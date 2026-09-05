import 'package:flutter/material.dart';
import '../models/alarm_item.dart';
import '../models/character_profile.dart';
import 'character_avatar.dart';

class AlarmCard extends StatelessWidget {
  final AlarmItem alarm;
  final CharacterProfile? character;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTap;
  final VoidCallback onPreview;
  final VoidCallback onDelete;

  const AlarmCard({
    super.key,
    required this.alarm,
    required this.character,
    required this.onToggle,
    required this.onTap,
    required this.onPreview,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final characterName = character?.name ?? '미지정 캐릭터';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: alarm.isEnabled
              ? theme.colorScheme.primary.withValues(alpha: 0.2)
              : Colors.grey.shade200,
          width: 1.5,
        ),
      ),
      color: alarm.isEnabled
          ? theme.colorScheme.surface
          : Colors.grey.shade50,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상단: 시간 및 On/Off 스위치
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        alarm.timeFormatted,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: alarm.isEnabled
                              ? theme.colorScheme.onSurface
                              : Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: alarm.isEnabled
                              ? theme.colorScheme.primaryContainer
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          alarm.repeatDaysFormatted,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: alarm.isEnabled
                                ? theme.colorScheme.onPrimaryContainer
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Transform.scale(
                    scale: 0.9,
                    child: Switch(
                      value: alarm.isEnabled,
                      onChanged: onToggle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // 중단: 발신 캐릭터 정보 및 말풍선 미리보기
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CharacterAvatar(
                    name: characterName,
                    avatarPath: character?.avatarPath,
                    radius: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          characterName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: alarm.isEnabled
                                ? theme.colorScheme.onSurface
                                : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: alarm.isEnabled
                                ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
                                : Colors.grey.shade100,
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(12),
                              bottomLeft: Radius.circular(12),
                              bottomRight: Radius.circular(12),
                            ),
                          ),
                          child: Text(
                            alarm.message.isNotEmpty
                                ? alarm.message
                                : '(설정된 모닝 메시지 없음)',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: alarm.isEnabled
                                  ? theme.colorScheme.onSurfaceVariant
                                  : Colors.grey.shade500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 하단 액션 버튼 (미리보기 & 삭제)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: onPreview,
                    icon: const Icon(Icons.send_rounded, size: 16),
                    label: const Text('알림 테스트', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    color: Colors.red.shade400,
                    visualDensity: VisualDensity.compact,
                    tooltip: '알람 삭제',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
