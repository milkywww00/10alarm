import 'dart:convert';

class ScheduleItem {
  final String id;
  final String title;
  final int year;
  final int month;
  final int day;
  final int hour;
  final int minute;
  final String characterId;
  final String message;
  final String? bundleId;
  final bool isCompleted;
  final DateTime createdAt;

  ScheduleItem({
    required this.id,
    required this.title,
    required this.year,
    required this.month,
    required this.day,
    required this.hour,
    required this.minute,
    required this.characterId,
    required this.message,
    this.bundleId,
    this.isCompleted = false,
    required this.createdAt,
  });

  DateTime get scheduledDateTime => DateTime(year, month, day, hour, minute);

  String get timeFormatted {
    final period = hour < 12 ? '오전' : '오후';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final minuteStr = minute.toString().padLeft(2, '0');
    return '$period $displayHour:$minuteStr';
  }

  String get dateFormatted {
    final m = month.toString().padLeft(2, '0');
    final d = day.toString().padLeft(2, '0');
    return '$year.$m.$d';
  }

  ScheduleItem copyWith({
    String? id,
    String? title,
    int? year,
    int? month,
    int? day,
    int? hour,
    int? minute,
    String? characterId,
    String? message,
    String? bundleId,
    bool? isCompleted,
    DateTime? createdAt,
  }) {
    return ScheduleItem(
      id: id ?? this.id,
      title: title ?? this.title,
      year: year ?? this.year,
      month: month ?? this.month,
      day: day ?? this.day,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      characterId: characterId ?? this.characterId,
      message: message ?? this.message,
      bundleId: bundleId ?? this.bundleId,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'year': year,
      'month': month,
      'day': day,
      'hour': hour,
      'minute': minute,
      'characterId': characterId,
      'message': message,
      'bundleId': bundleId,
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ScheduleItem.fromMap(Map<String, dynamic> map) {
    return ScheduleItem(
      id: map['id'] as String,
      title: map['title'] as String,
      year: map['year'] as int,
      month: map['month'] as int,
      day: map['day'] as int,
      hour: map['hour'] as int,
      minute: map['minute'] as int,
      characterId: map['characterId'] as String,
      message: map['message'] as String? ?? '',
      bundleId: map['bundleId'] as String?,
      isCompleted: map['isCompleted'] as bool? ?? false,
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());
  factory ScheduleItem.fromJson(String source) =>
      ScheduleItem.fromMap(json.decode(source) as Map<String, dynamic>);
}
