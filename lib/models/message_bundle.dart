import 'dart:convert';

class MessageBundle {
  final String id;
  final String characterId;
  final String title;
  final List<String> messages; // 순차적으로 발송될 메시지 리스트
  final int intervalSeconds; // 메시지 간 딜레이 (초)
  final DateTime createdAt;

  MessageBundle({
    required this.id,
    required this.characterId,
    required this.title,
    required this.messages,
    this.intervalSeconds = 2,
    required this.createdAt,
  });

  MessageBundle copyWith({
    String? id,
    String? characterId,
    String? title,
    List<String>? messages,
    int? intervalSeconds,
    DateTime? createdAt,
  }) {
    return MessageBundle(
      id: id ?? this.id,
      characterId: characterId ?? this.characterId,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      intervalSeconds: intervalSeconds ?? this.intervalSeconds,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'characterId': characterId,
      'title': title,
      'messages': messages,
      'intervalSeconds': intervalSeconds,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory MessageBundle.fromMap(Map<String, dynamic> map) {
    return MessageBundle(
      id: map['id'] as String,
      characterId: map['characterId'] as String,
      title: map['title'] as String,
      messages: List<String>.from(map['messages'] ?? []),
      intervalSeconds: map['intervalSeconds'] as int? ?? 2,
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());
  factory MessageBundle.fromJson(String source) =>
      MessageBundle.fromMap(json.decode(source) as Map<String, dynamic>);
}
