import 'dart:convert';

class CharacterProfile {
  final String id;
  final String name;
  final String? avatarPath;
  final String? title;
  final String? defaultMorningMessage;
  final String? defaultPomodoroFocusEndMessage;
  final String? defaultPomodoroBreakEndMessage;
  final String? defaultStopwatchCongratsMessage;
  final String? defaultCalendarMessage;
  final String? aiPersonaPrompt;
  final bool isAiEnabled;
  final String? aiRelationship;
  final String? aiTone;
  final String? aiGreeting;
  final String? aiBackground;
  final String? aiDialogueExamples;
  final DateTime createdAt;

  CharacterProfile({
    required this.id,
    required this.name,
    this.avatarPath,
    this.title,
    this.defaultMorningMessage,
    this.defaultPomodoroFocusEndMessage,
    this.defaultPomodoroBreakEndMessage,
    this.defaultStopwatchCongratsMessage,
    this.defaultCalendarMessage,
    this.aiPersonaPrompt,
    this.isAiEnabled = true,
    this.aiRelationship,
    this.aiTone,
    this.aiGreeting,
    this.aiBackground,
    this.aiDialogueExamples,
    required this.createdAt,
  });

  CharacterProfile copyWith({
    String? id,
    String? name,
    String? avatarPath,
    String? title,
    String? defaultMorningMessage,
    String? defaultPomodoroFocusEndMessage,
    String? defaultPomodoroBreakEndMessage,
    String? defaultStopwatchCongratsMessage,
    String? defaultCalendarMessage,
    String? aiPersonaPrompt,
    bool? isAiEnabled,
    String? aiRelationship,
    String? aiTone,
    String? aiGreeting,
    String? aiBackground,
    String? aiDialogueExamples,
    DateTime? createdAt,
  }) {
    return CharacterProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarPath: avatarPath ?? this.avatarPath,
      title: title ?? this.title,
      defaultMorningMessage: defaultMorningMessage ?? this.defaultMorningMessage,
      defaultPomodoroFocusEndMessage: defaultPomodoroFocusEndMessage ?? this.defaultPomodoroFocusEndMessage,
      defaultPomodoroBreakEndMessage: defaultPomodoroBreakEndMessage ?? this.defaultPomodoroBreakEndMessage,
      defaultStopwatchCongratsMessage: defaultStopwatchCongratsMessage ?? this.defaultStopwatchCongratsMessage,
      defaultCalendarMessage: defaultCalendarMessage ?? this.defaultCalendarMessage,
      aiPersonaPrompt: aiPersonaPrompt ?? this.aiPersonaPrompt,
      isAiEnabled: isAiEnabled ?? this.isAiEnabled,
      aiRelationship: aiRelationship ?? this.aiRelationship,
      aiTone: aiTone ?? this.aiTone,
      aiGreeting: aiGreeting ?? this.aiGreeting,
      aiBackground: aiBackground ?? this.aiBackground,
      aiDialogueExamples: aiDialogueExamples ?? this.aiDialogueExamples,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'avatarPath': avatarPath,
      'title': title,
      'defaultMorningMessage': defaultMorningMessage,
      'defaultPomodoroFocusEndMessage': defaultPomodoroFocusEndMessage,
      'defaultPomodoroBreakEndMessage': defaultPomodoroBreakEndMessage,
      'defaultStopwatchCongratsMessage': defaultStopwatchCongratsMessage,
      'defaultCalendarMessage': defaultCalendarMessage,
      'aiPersonaPrompt': aiPersonaPrompt,
      'isAiEnabled': isAiEnabled,
      'aiRelationship': aiRelationship,
      'aiTone': aiTone,
      'aiGreeting': aiGreeting,
      'aiBackground': aiBackground,
      'aiDialogueExamples': aiDialogueExamples,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CharacterProfile.fromMap(Map<String, dynamic> map) {
    return CharacterProfile(
      id: map['id'] as String,
      name: map['name'] as String,
      avatarPath: map['avatarPath'] as String?,
      title: map['title'] as String?,
      defaultMorningMessage: map['defaultMorningMessage'] as String?,
      defaultPomodoroFocusEndMessage: map['defaultPomodoroFocusEndMessage'] as String?,
      defaultPomodoroBreakEndMessage: map['defaultPomodoroBreakEndMessage'] as String?,
      defaultStopwatchCongratsMessage: map['defaultStopwatchCongratsMessage'] as String?,
      defaultCalendarMessage: map['defaultCalendarMessage'] as String?,
      aiPersonaPrompt: map['aiPersonaPrompt'] as String?,
      isAiEnabled: map['isAiEnabled'] as bool? ?? true,
      aiRelationship: map['aiRelationship'] as String?,
      aiTone: map['aiTone'] as String?,
      aiGreeting: map['aiGreeting'] as String?,
      aiBackground: map['aiBackground'] as String?,
      aiDialogueExamples: map['aiDialogueExamples'] as String?,
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());
  factory CharacterProfile.fromJson(String source) =>
      CharacterProfile.fromMap(json.decode(source) as Map<String, dynamic>);
}
