import 'dart:convert';

class ChatMessage {
  final String id;
  final String characterId;
  final String text;
  final bool isMe;
  final DateTime timestamp;
  final bool isError;

  ChatMessage({
    required this.id,
    required this.characterId,
    required this.text,
    required this.isMe,
    required this.timestamp,
    this.isError = false,
  });

  ChatMessage copyWith({
    String? id,
    String? characterId,
    String? text,
    bool? isMe,
    DateTime? timestamp,
    bool? isError,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      characterId: characterId ?? this.characterId,
      text: text ?? this.text,
      isMe: isMe ?? this.isMe,
      timestamp: timestamp ?? this.timestamp,
      isError: isError ?? this.isError,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'characterId': characterId,
      'text': text,
      'isMe': isMe,
      'timestamp': timestamp.toIso8601String(),
      'isError': isError,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      characterId: map['characterId']?.toString() ?? '',
      text: map['text']?.toString() ?? '',
      isMe: map['isMe'] == true,
      timestamp: DateTime.tryParse(map['timestamp']?.toString() ?? '') ?? DateTime.now(),
      isError: map['isError'] == true,
    );
  }

  String toJson() => json.encode(toMap());
  factory ChatMessage.fromJson(String source) =>
      ChatMessage.fromMap(json.decode(source) as Map<String, dynamic>);
}
