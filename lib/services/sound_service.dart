import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'theme_service.dart';

class SoundService {
  static final SoundService instance = SoundService._();
  SoundService._();

  final AudioPlayer _player = AudioPlayer();
  final AudioPlayer _alarmPlayer = AudioPlayer();
  final ValueNotifier<String?> playingSoundNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<bool> isAlarmRingingNotifier = ValueNotifier<bool>(false);

  Future<void> init() async {
    _player.onPlayerComplete.listen((_) {
      playingSoundNotifier.value = null;
    });
  }

  /// 실제 알람 울림 (알람 오디오 스트림 및 반복 재생)
  Future<void> startAlarmRinging({String? soundName, String? customPath}) async {
    try {
      final selectedSound = soundName ?? ThemeService.instance.alarmSoundNotifier.value;
      await _alarmPlayer.stop();
      await _alarmPlayer.setReleaseMode(ReleaseMode.loop);

      // 알람 전용 오디오 컨텍스트 (무음 모드 무시, 최대 스피커 알람 스트림)
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.alarm,
            audioFocus: AndroidAudioFocus.gainTransientExclusive,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {
              AVAudioSessionOptions.duckOthers,
              AVAudioSessionOptions.defaultToSpeaker,
            },
          ),
        ),
      );

      isAlarmRingingNotifier.value = true;

      String? effectivePath = customPath;
      if (effectivePath == null) {
        final customSounds = ThemeService.instance.customSoundsNotifier.value;
        final matched = customSounds.where((s) => s['name'] == selectedSound).firstOrNull;
        if (matched != null && matched['path'] != null) {
          effectivePath = matched['path'];
        }
      }

      if (effectivePath != null && effectivePath.isNotEmpty) {
        if (kIsWeb) {
          await _alarmPlayer.play(UrlSource(effectivePath));
        } else {
          await _alarmPlayer.play(DeviceFileSource(effectivePath));
        }
        return;
      }

      final wavBytes = _generatePresetWav(selectedSound);
      await _alarmPlayer.play(BytesSource(wavBytes));
    } catch (e) {
      debugPrint('알람 사운드 재생 실패: $e');
    }
  }

  /// 알람 울림 정지
  Future<void> stopAlarm() async {
    try {
      await _alarmPlayer.stop();
    } catch (_) {}
    isAlarmRingingNotifier.value = false;
  }

  /// 알림음 미리듣기 재생 (단발성)
  Future<void> playPreview(String soundName, {String? customPath}) async {
    try {
      // 현재 재생 중인 동일한 소리를 다시 누르면 정지
      if (playingSoundNotifier.value == soundName) {
        await stop();
        return;
      }

      await _player.stop();
      playingSoundNotifier.value = soundName;

      // 1. 커스텀 업로드 파일 재생
      if (customPath != null && customPath.isNotEmpty) {
        if (kIsWeb) {
          await _player.play(UrlSource(customPath));
        } else {
          await _player.play(DeviceFileSource(customPath));
        }
        return;
      }

      // 2. 프리셋 알림음 합성 사운드 생성 및 재생
      final wavBytes = _generatePresetWav(soundName);
      await _player.play(BytesSource(wavBytes));
    } catch (e) {
      debugPrint('사운드 재생 오류: $e');
      playingSoundNotifier.value = null;
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
    playingSoundNotifier.value = null;
  }

  /// 11종 프리셋 사운드별 맞춤 PCM 파형 생성
  Uint8List _generatePresetWav(String name) {
    const sampleRate = 22050; // 가볍고 빠른 22kHz
    List<double> samples;

    switch (name) {
      case '피아노':
        // C4(261Hz) - E4(329Hz) - G4(392Hz) - C5(523Hz) 아르페지오 (풍부한 배음)
        samples = _generateMelody(sampleRate, [
          _Note(261.63, 0.45, tone: _ToneType.piano),
          _Note(329.63, 0.45, tone: _ToneType.piano),
          _Note(392.00, 0.45, tone: _ToneType.piano),
          _Note(523.25, 0.90, tone: _ToneType.piano),
        ]);
        break;

      case '실로폰':
        // 맑고 경쾌한 목금 타격음 (E5 - G5 - A5 - B5)
        samples = _generateMelody(sampleRate, [
          _Note(659.25, 0.25, tone: _ToneType.xylophone),
          _Note(783.99, 0.25, tone: _ToneType.xylophone),
          _Note(880.00, 0.25, tone: _ToneType.xylophone),
          _Note(987.77, 0.70, tone: _ToneType.xylophone),
        ]);
        break;

      case '오르골':
        // 영롱한 고음역대 오르골 멜로디 (C6 - G6 - E6 - C7)
        samples = _generateMelody(sampleRate, [
          _Note(1046.50, 0.35, tone: _ToneType.musicBox),
          _Note(1567.98, 0.35, tone: _ToneType.musicBox),
          _Note(1318.51, 0.35, tone: _ToneType.musicBox),
          _Note(2093.00, 0.85, tone: _ToneType.musicBox),
        ]);
        break;

      case '차임벨':
        // 클래식 2톤 차임 (E5 -> C5)
        samples = _generateMelody(sampleRate, [
          _Note(659.25, 0.7, tone: _ToneType.chime),
          _Note(523.25, 1.2, tone: _ToneType.chime),
        ]);
        break;

      case '벨소리':
        // 맑은 데스크 벨 2회 타격 (A5)
        samples = _generateMelody(sampleRate, [
          _Note(880.0, 0.5, tone: _ToneType.bell),
          _Note(880.0, 1.0, tone: _ToneType.bell),
        ]);
        break;

      case '하모니카':
        // 따뜻한 리드 화음 (C4 + G4 동시 화음)
        samples = _generateChord(sampleRate, [261.63, 329.63, 392.0], 1.8, tone: _ToneType.harmonica);
        break;

      case '팡파르':
        // 당당한 트라이어드 팡파르 (C5 -> E5 -> G5)
        samples = _generateMelody(sampleRate, [
          _Note(523.25, 0.25, tone: _ToneType.fanfare),
          _Note(659.25, 0.25, tone: _ToneType.fanfare),
          _Note(783.99, 0.80, tone: _ToneType.fanfare),
        ]);
        break;

      case '핑퐁':
        // 퐁당퐁당 튕기는 효과음 (고음 -> 저음 -> 고음)
        samples = _generateMelody(sampleRate, [
          _Note(987.77, 0.18, tone: _ToneType.pingpong),
          _Note(493.88, 0.18, tone: _ToneType.pingpong),
          _Note(1174.66, 0.40, tone: _ToneType.pingpong),
        ]);
        break;

      case '자명종':
        // 따르릉 기계식 자명종 따블 벨 트릴
        samples = _generateAlarmTrill(sampleRate, 1.8);
        break;

      case '비프음':
        // 디지털 전자시계 알람 (삐-삐-삐-삐)
        samples = _generateBeeps(sampleRate, 4, 1046.5);
        break;

      case '기본 알람':
      default:
        // 상쾌한 기상 시그니처 멜로디 (G4 - C5 - E5 - G5)
        samples = _generateMelody(sampleRate, [
          _Note(392.00, 0.28, tone: _ToneType.chime),
          _Note(523.25, 0.28, tone: _ToneType.chime),
          _Note(659.25, 0.28, tone: _ToneType.chime),
          _Note(783.99, 0.85, tone: _ToneType.chime),
        ]);
        break;
    }

    return _encodeWav(samples, sampleRate);
  }

  List<double> _generateMelody(int sampleRate, List<_Note> notes) {
    final List<double> result = [];
    for (final note in notes) {
      final noteSamples = (sampleRate * note.duration).toInt();
      for (int i = 0; i < noteSamples; i++) {
        final t = i / sampleRate;
        final progress = i / noteSamples;
        double envelope;

        // 악기별 감쇠 곡선
        switch (note.tone) {
          case _ToneType.piano:
            envelope = math.exp(-2.5 * progress);
            break;
          case _ToneType.xylophone:
            envelope = math.exp(-5.0 * progress);
            break;
          case _ToneType.musicBox:
            envelope = math.exp(-3.0 * progress);
            break;
          case _ToneType.bell:
            envelope = math.exp(-2.0 * progress);
            break;
          case _ToneType.fanfare:
            envelope = progress < 0.1 ? (progress / 0.1) : (1.0 - (progress - 0.1) * 0.4);
            break;
          case _ToneType.pingpong:
            envelope = math.exp(-8.0 * progress);
            break;
          default:
            envelope = math.exp(-2.2 * progress);
        }

        // 배음 합성으로 자연스러운 음색 형성
        double sample = math.sin(2 * math.pi * note.frequency * t);
        if (note.tone == _ToneType.piano) {
          sample += 0.4 * math.sin(4 * math.pi * note.frequency * t);
          sample += 0.2 * math.sin(6 * math.pi * note.frequency * t);
          sample /= 1.6;
        } else if (note.tone == _ToneType.musicBox) {
          sample += 0.5 * math.sin(4 * math.pi * note.frequency * t);
          sample /= 1.5;
        } else if (note.tone == _ToneType.fanfare) {
          sample += 0.6 * math.sin(4 * math.pi * note.frequency * t);
          sample += 0.3 * math.sin(6 * math.pi * note.frequency * t);
          sample /= 1.9;
        }

        result.add(sample * envelope * 0.8);
      }
    }
    return result;
  }

  List<double> _generateChord(int sampleRate, List<double> freqs, double duration, {required _ToneType tone}) {
    final int totalSamples = (sampleRate * duration).toInt();
    final List<double> result = List.filled(totalSamples, 0.0);

    for (int i = 0; i < totalSamples; i++) {
      final t = i / sampleRate;
      final progress = i / totalSamples;
      final envelope = math.sin(math.pi * progress) * 0.8;

      double sample = 0;
      for (final f in freqs) {
        sample += math.sin(2 * math.pi * f * t);
        sample += 0.3 * math.sin(4 * math.pi * f * t);
      }
      sample /= freqs.length * 1.3;
      result[i] = sample * envelope;
    }
    return result;
  }

  List<double> _generateAlarmTrill(int sampleRate, double duration) {
    final int totalSamples = (sampleRate * duration).toInt();
    final List<double> result = [];
    const f1 = 1200.0;
    const f2 = 1400.0;

    for (int i = 0; i < totalSamples; i++) {
      final t = i / sampleRate;
      // 15Hz로 두 벨 사이를 빠르게 교대
      final freq = (math.sin(2 * math.pi * 15 * t) > 0) ? f1 : f2;
      final sample = math.sin(2 * math.pi * freq * t) * 0.7;
      result.add(sample);
    }
    return result;
  }

  List<double> _generateBeeps(int sampleRate, int count, double freq) {
    final List<double> result = [];
    const beepDuration = 0.18;
    const pauseDuration = 0.12;

    for (int b = 0; b < count; b++) {
      final beepSamples = (sampleRate * beepDuration).toInt();
      for (int i = 0; i < beepSamples; i++) {
        final t = i / sampleRate;
        final sample = math.sin(2 * math.pi * freq * t) * 0.75;
        result.add(sample);
      }
      final pauseSamples = (sampleRate * pauseDuration).toInt();
      for (int i = 0; i < pauseSamples; i++) {
        result.add(0.0);
      }
    }
    return result;
  }

  Uint8List _encodeWav(List<double> samples, int sampleRate) {
    final int byteLength = samples.length * 2;
    final ByteData byteData = ByteData(44 + byteLength);

    // RIFF header
    byteData.setUint8(0, 0x52); // 'R'
    byteData.setUint8(1, 0x49); // 'I'
    byteData.setUint8(2, 0x46); // 'F'
    byteData.setUint8(3, 0x46); // 'F'
    byteData.setUint32(4, 36 + byteLength, Endian.little);
    byteData.setUint8(8, 0x57);  // 'W'
    byteData.setUint8(9, 0x41);  // 'A'
    byteData.setUint8(10, 0x56); // 'V'
    byteData.setUint8(11, 0x45); // 'E'

    // fmt chunk
    byteData.setUint8(12, 0x66); // 'f'
    byteData.setUint8(13, 0x6D); // 'm'
    byteData.setUint8(14, 0x74); // 't'
    byteData.setUint8(15, 0x20); // ' '
    byteData.setUint32(16, 16, Endian.little);
    byteData.setUint16(20, 1, Endian.little); // PCM
    byteData.setUint16(22, 1, Endian.little); // Mono
    byteData.setUint32(24, sampleRate, Endian.little);
    byteData.setUint32(28, sampleRate * 2, Endian.little);
    byteData.setUint16(32, 2, Endian.little);
    byteData.setUint16(34, 16, Endian.little);

    // data chunk
    byteData.setUint8(36, 0x64); // 'd'
    byteData.setUint8(37, 0x61); // 'a'
    byteData.setUint8(38, 0x74); // 't'
    byteData.setUint8(39, 0x61); // 'a'
    byteData.setUint32(40, byteLength, Endian.little);

    int offset = 44;
    for (final s in samples) {
      final clamped = s.clamp(-1.0, 1.0);
      final int sampleInt = (clamped * 32767).toInt();
      byteData.setInt16(offset, sampleInt, Endian.little);
      offset += 2;
    }

    return byteData.buffer.asUint8List();
  }
}

enum _ToneType {
  piano,
  xylophone,
  musicBox,
  chime,
  bell,
  harmonica,
  fanfare,
  pingpong,
}

class _Note {
  final double frequency;
  final double duration;
  final _ToneType tone;

  _Note(this.frequency, this.duration, {required this.tone});
}
