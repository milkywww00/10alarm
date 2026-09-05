import 'dart:convert';

class StopwatchConfig {
  final int targetMinutes;
  final bool isTargetEnabled;
  final String? characterId;
  final String targetReachedMessage;
  final String? bundleId;

  StopwatchConfig({
    this.targetMinutes = 30,
    this.isTargetEnabled = true,
    this.characterId,
    this.targetReachedMessage = '목표 시간 달성! 정말 대단해.',
    this.bundleId,
  });

  StopwatchConfig copyWith({
    int? targetMinutes,
    bool? isTargetEnabled,
    String? characterId,
    String? targetReachedMessage,
    String? bundleId,
  }) {
    return StopwatchConfig(
      targetMinutes: targetMinutes ?? this.targetMinutes,
      isTargetEnabled: isTargetEnabled ?? this.isTargetEnabled,
      characterId: characterId ?? this.characterId,
      targetReachedMessage: targetReachedMessage ?? this.targetReachedMessage,
      bundleId: bundleId ?? this.bundleId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'targetMinutes': targetMinutes,
      'isTargetEnabled': isTargetEnabled,
      'characterId': characterId,
      'targetReachedMessage': targetReachedMessage,
      'bundleId': bundleId,
    };
  }

  factory StopwatchConfig.fromMap(Map<String, dynamic> map) {
    return StopwatchConfig(
      targetMinutes: map['targetMinutes'] as int? ?? 30,
      isTargetEnabled: map['isTargetEnabled'] as bool? ?? true,
      characterId: map['characterId'] as String?,
      targetReachedMessage: map['targetReachedMessage'] as String? ?? '목표 시간 달성! 정말 대단해.',
      bundleId: map['bundleId'] as String?,
    );
  }

  String toJson() => json.encode(toMap());
  factory StopwatchConfig.fromJson(String source) =>
      StopwatchConfig.fromMap(json.decode(source) as Map<String, dynamic>);
}
