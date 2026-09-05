import 'dart:convert';

class PomodoroConfig {
  final int focusMinutes;
  final int breakMinutes;
  final String? characterId;
  final String focusEndMessage;
  final String breakEndMessage;
  final String? focusBundleId;
  final String? breakBundleId;

  PomodoroConfig({
    this.focusMinutes = 25,
    this.breakMinutes = 5,
    this.characterId,
    this.focusEndMessage = '집중 시간 종료! 잠시 휴식해.',
    this.breakEndMessage = '휴식 시간 종료! 다시 집중해볼까?',
    this.focusBundleId,
    this.breakBundleId,
  });

  PomodoroConfig copyWith({
    int? focusMinutes,
    int? breakMinutes,
    String? characterId,
    String? focusEndMessage,
    String? breakEndMessage,
    String? focusBundleId,
    String? breakBundleId,
  }) {
    return PomodoroConfig(
      focusMinutes: focusMinutes ?? this.focusMinutes,
      breakMinutes: breakMinutes ?? this.breakMinutes,
      characterId: characterId ?? this.characterId,
      focusEndMessage: focusEndMessage ?? this.focusEndMessage,
      breakEndMessage: breakEndMessage ?? this.breakEndMessage,
      focusBundleId: focusBundleId ?? this.focusBundleId,
      breakBundleId: breakBundleId ?? this.breakBundleId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'focusMinutes': focusMinutes,
      'breakMinutes': breakMinutes,
      'characterId': characterId,
      'focusEndMessage': focusEndMessage,
      'breakEndMessage': breakEndMessage,
      'focusBundleId': focusBundleId,
      'breakBundleId': breakBundleId,
    };
  }

  factory PomodoroConfig.fromMap(Map<String, dynamic> map) {
    return PomodoroConfig(
      focusMinutes: map['focusMinutes'] as int? ?? 25,
      breakMinutes: map['breakMinutes'] as int? ?? 5,
      characterId: map['characterId'] as String?,
      focusEndMessage: map['focusEndMessage'] as String? ?? '집중 시간 종료! 잠시 휴식해.',
      breakEndMessage: map['breakEndMessage'] as String? ?? '휴식 시간 종료! 다시 집중해볼까?',
      focusBundleId: map['focusBundleId'] as String?,
      breakBundleId: map['breakBundleId'] as String?,
    );
  }

  String toJson() => json.encode(toMap());
  factory PomodoroConfig.fromJson(String source) =>
      PomodoroConfig.fromMap(json.decode(source) as Map<String, dynamic>);
}
