import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/alarm_item.dart';
import '../models/character_profile.dart';
import '../services/sound_service.dart';
import '../services/theme_service.dart';
import '../utils/message_formatter.dart';
import 'chat_simulation_screen.dart';

class AlarmRingScreen extends StatefulWidget {
  final CharacterProfile character;
  final AlarmItem? alarm;
  final String message;

  const AlarmRingScreen({
    super.key,
    required this.character,
    this.alarm,
    required this.message,
  });

  @override
  State<AlarmRingScreen> createState() => _AlarmRingScreenState();
}

class _AlarmRingScreenState extends State<AlarmRingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late Timer _clockTimer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();

    // 1. 알람 사운드 무한 루프 재생 시작
    SoundService.instance.startAlarmRinging();

    // 2. 가벼운 진동 피드백
    HapticFeedback.vibrate();

    // 3. 아바타 펄스 애니메이션 (알람 울림 시각화)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 4. 시계 타이머 (매 초 갱신)
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _currentTime = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _pulseController.dispose();
    SoundService.instance.stopAlarm();
    super.dispose();
  }

  void _dismissAlarm() {
    SoundService.instance.stopAlarm();
    HapticFeedback.mediumImpact();
    Navigator.pop(context);
  }

  void _goToChat() {
    SoundService.instance.stopAlarm();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChatSimulationScreen(
          character: widget.character,
          alarm: widget.alarm,
          initialMessage: widget.message,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeStr = DateFormat('HH:mm').format(_currentTime);
    final dateStr = DateFormat('M월 d일 EEEE', 'ko').format(_currentTime);
    final currentSoundName = ThemeService.instance.alarmSoundNotifier.value;

    // 안내 메시지 치환 (호칭, 이름 등 치환)
    final resolvedMessage = MessageFormatter.format(
      widget.message,
      character: widget.character,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _dismissAlarm();
        }
      },
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                theme.colorScheme.primaryContainer.withValues(alpha: 0.8),
                theme.colorScheme.surface,
                theme.colorScheme.surface,
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 상단: 현재 시간 및 날짜
                  Column(
                    children: [
                      const SizedBox(height: 16),
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.alarm_on_rounded, size: 16, color: theme.colorScheme.primary),
                            const SizedBox(width: 6),
                            Text(
                              '🎵 $currentSoundName 알람 울림 중',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // 중앙: 캐릭터 프로필 아바타 (펄스 애니메이션) & 말풍선
                  Column(
                    children: [
                      ScaleTransition(
                        scale: _pulseAnimation,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.colorScheme.primary.withValues(alpha: 0.4),
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.primary.withValues(alpha: 0.25),
                                blurRadius: 24,
                                spreadRadius: 8,
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 65,
                            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                            backgroundImage: (!kIsWeb &&
                                    widget.character.avatarPath != null &&
                                    File(widget.character.avatarPath!).existsSync())
                                ? FileImage(File(widget.character.avatarPath!)) as ImageProvider
                                : null,
                            child: (kIsWeb ||
                                    widget.character.avatarPath == null ||
                                    !File(widget.character.avatarPath!).existsSync())
                                ? Text(
                                    widget.character.name.isNotEmpty
                                        ? widget.character.name[0]
                                        : '?',
                                    style: TextStyle(
                                      fontSize: 48,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        widget.character.name,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      if (widget.character.title != null && widget.character.title!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.character.title!,
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                        ),
                      ],
                      const SizedBox(height: 18),
                      // 캐릭터의 대사 말풍선
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          resolvedMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // 하단: 알람 해제 및 대화하기 버튼
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton.icon(
                          icon: const Icon(Icons.alarm_off_rounded, size: 22),
                          label: const Text('알람 끄기', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 2,
                          ),
                          onPressed: _dismissAlarm,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                          label: Text('\'${widget.character.name}\'와(과) 대화하기', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.colorScheme.primary,
                            side: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: _goToChat,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
