import 'dart:convert';

class AlarmItem {
  final String id;
  final String characterId;
  final int hour;
  final int minute;
  final List<int> repeatDays; // 1 = 월, 7 = 일
  final String message;
  final String? bundleId; // null: 기본 문구, 'RANDOM': 랜덤 시나리오, 또는 특정 시나리오 ID
  final bool isEnabled;
  final DateTime createdAt;

  AlarmItem({
    required this.id,
    required this.characterId,
    required this.hour,
    required this.minute,
    this.repeatDays = const [],
    required this.message,
    this.bundleId,
    this.isEnabled = true,
    required this.createdAt,
  });

  String get timeFormatted {
    final period = hour < 12 ? '오전' : '오후';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final minuteStr = minute.toString().padLeft(2, '0');
    return '$period $displayHour:$minuteStr';
  }

  String get repeatDaysFormatted {
    if (repeatDays.isEmpty) return '한 번만';
    if (repeatDays.length == 7) return '매일';
    if (repeatDays.length == 5 &&
        !repeatDays.contains(6) &&
        !repeatDays.contains(7)) {
      return '주중 (월~금)';
    }
    if (repeatDays.length == 2 &&
        repeatDays.contains(6) &&
        repeatDays.contains(7)) {
      return '주말 (토, 일)';
    }

    const dayNames = {
      1: '월',
      2: '화',
      3: '수',
      4: '목',
      5: '금',
      6: '토',
      7: '일',
    };
    final sorted = List<int>.from(repeatDays)..sort();
    return sorted.map((d) => dayNames[d] ?? '').join(', ');
  }

  AlarmItem copyWith({
    String? id,
    String? characterId,
    int? hour,
    int? minute,
    List<int>? repeatDays,
    String? message,
    String? bundleId,
    bool? isEnabled,
    DateTime? createdAt,
  }) {
    return AlarmItem(
      id: id ?? this.id,
      characterId: characterId ?? this.characterId,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      repeatDays: repeatDays ?? this.repeatDays,
      message: message ?? this.message,
      bundleId: bundleId ?? this.bundleId,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'characterId': characterId,
      'hour': hour,
      'minute': minute,
      'repeatDays': repeatDays,
      'message': message,
      'bundleId': bundleId,
      'isEnabled': isEnabled,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AlarmItem.fromMap(Map<String, dynamic> map) {
    return AlarmItem(
      id: map['id'] as String,
      characterId: map['characterId'] as String,
      hour: map['hour'] as int,
      minute: map['minute'] as int,
      repeatDays: List<int>.from(map['repeatDays'] ?? []),
      message: map['message'] as String? ?? '',
      bundleId: map['bundleId'] as String?,
      isEnabled: map['isEnabled'] as bool? ?? true,
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());
  factory AlarmItem.fromJson(String source) =>
      AlarmItem.fromMap(json.decode(source) as Map<String, dynamic>);
}
