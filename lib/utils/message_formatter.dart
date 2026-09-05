import '../models/character_profile.dart';

class MessageFormatter {
  /// 메시지 템플릿 내의 치환 태그들을 실제 값으로 변환합니다.
  /// - {호칭}: 캐릭터가 나를 부르는 호칭 (character.title)
  /// - {이름} / {캐릭터}: 캐릭터 본인의 이름 (character.name)
  /// - {일정}: 캘린더 일정 제목
  /// - {시간}: 스톱워치/뽀모도로 시간
  static String format(
    String template, {
    CharacterProfile? character,
    String? scheduleTitle,
    String? timeText,
  }) {
    if (template.isEmpty) return template;

    String result = template;

    final callName = character?.title?.trim() ?? '';
    final charName = character?.name.trim() ?? '';

    // 치환 수행
    result = result.replaceAll('{호칭}', callName);
    result = result.replaceAll('{이름}', charName);
    result = result.replaceAll('{캐릭터}', charName);

    if (scheduleTitle != null) {
      result = result.replaceAll('{일정}', scheduleTitle);
    }
    if (timeText != null) {
      result = result.replaceAll('{시간}', timeText);
    }

    // 호칭이 비어있을 때 발생하는 연속 공백 및 문장부호 앞 잉여 공백 정리
    result = result.replaceAllMapped(RegExp(r'\s+([,!?~])'), (m) => m[1]!);
    result = result.replaceAll(RegExp(r'[ \t]{2,}'), ' ').trim();

    return result;
  }
}
