import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

/// Procedural audio for Nonogram — all sounds synthesized in code as WAV
/// bytes. No asset files. Warm, physical, print-shop sounds: ink thumps,
/// brass taps, paper scratches, press clunks.
///
/// Reliability design (every call is safe to repeat and safe to overlap):
/// - Music clips are synthesized ONCE and cached; starting music never blocks
///   the UI thread after the first build.
/// - A [_musicGen] generation counter serializes track changes: every
///   start/stop bumps the generation, in-flight work from an older request
///   aborts, and the LATEST request always wins. Overlapping calls (menu in/out,
///   pause/resume, toggles) can never swallow a start or leave the player
///   half-started — music is app-scoped and never silently dies.
/// - Lifecycle uses pause()/resume() so an interruption (call, backgrounding)
///   resumes exactly where it left off instead of restarting or dying.
/// - Every public method catches player errors; audio can never crash the app.
class PressAudio {
  static const int _rate = 22050;
  final AudioPlayer _sfx = AudioPlayer();
  final AudioPlayer _music = AudioPlayer();
  final _rand = Random();

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;

  final Map<String, Uint8List> _cache = {};

  int _musicGen = 0;
  bool _musicBusy = false;
  String? _currentTrack; // 'menu' | 'game' | null
  bool _pausedByLifecycle = false;
  bool _disposed = false;

  PressAudio() {
    _music.setReleaseMode(ReleaseMode.loop);
  }

  void configure(
      {required bool musicOn, required bool sfxOn, required double volume}) {
    this.musicOn = musicOn;
    this.sfxOn = sfxOn;
    volume = volume.clamp(0.0, 1.0);
    this.volume = volume;
    _music.setVolume(musicOn ? volume * 0.5 : 0.0);
    _sfx.setVolume(sfxOn ? volume : 0.0);
    if (!musicOn) {
      stopMusic();
    }
  }

  /// Pre-build music clips off the critical path. Safe to call any time.
  Future<void> prewarm() async {
    if (_disposed) return;
    await Future(() {});
    _menuBytes();
    _gameBytes();
  }

  // ---------------------------------------------------------- WAV synthesis
  Uint8List _wav(List<double> samples) {
    final n = samples.length;
    final data = ByteData(44 + n * 2);
    void writeStr(int o, String s) {
      for (int i = 0; i < s.length; i++) {
        data.setUint8(o + i, s.codeUnitAt(i));
      }
    }

    writeStr(0, 'RIFF');
    data.setUint32(4, 36 + n * 2, Endian.little);
    writeStr(8, 'WAVE');
    writeStr(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, 1, Endian.little);
    data.setUint32(24, _rate, Endian.little);
    data.setUint32(28, _rate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    writeStr(36, 'data');
    data.setUint32(40, n * 2, Endian.little);
    for (int i = 0; i < n; i++) {
      final v = samples[i].clamp(-1.0, 1.0);
      data.setInt16(44 + i * 2, (v * 32767).round(), Endian.little);
    }
    return data.buffer.asUint8List();
  }

  double _env(int i, int n, {double attack = 0.02, double decayPow = 2.2}) {
    final t = i / n;
    final a = (t / attack).clamp(0.0, 1.0);
    final d = pow(1 - t, decayPow).toDouble();
    return a * d;
  }

  List<double> _tone(double freq, double secs,
      {double freqEnd = 0, double attack = 0.02, double harmonics = 0.25}) {
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      final f = freqEnd > 0 ? freq + (freqEnd - freq) * (i / n) : freq;
      final ph = 2 * pi * f * t;
      out[i] = _env(i, n, attack: attack) *
          (sin(ph) + harmonics * sin(2 * ph) + harmonics * 0.5 * sin(3 * ph));
    }
    return out;
  }

  /// Ink-block press: low wooden thump + paper kiss.
  List<double> _pressThump() {
    final n = (_rate * 0.16).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      out[i] = _env(i, n, attack: 0.004) *
          (0.85 * sin(2 * pi * 150 * t) * exp(-t * 28) +
              0.45 * sin(2 * pi * 320 * t) * exp(-t * 50) +
              0.2 * (_rand.nextDouble() * 2 - 1) * exp(-t * 110));
    }
    return out;
  }

  /// Brass tap: bright metallic ping with fast decay.
  List<double> _brassTap() {
    final n = (_rate * 0.12).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      out[i] = _env(i, n, attack: 0.002, decayPow: 3.0) *
          (0.5 * sin(2 * pi * 1560 * t) +
              0.3 * sin(2 * pi * 2340 * t) +
              0.15 * sin(2 * pi * 980 * t));
    }
    return out;
  }

  /// Carved X: dry scratch — filtered noise burst.
  List<double> _scratch() {
    final n = (_rate * 0.13).round();
    final out = List<double>.filled(n, 0);
    double lp = 0;
    for (int i = 0; i < n; i++) {
      final raw = _rand.nextDouble() * 2 - 1;
      lp = lp * 0.82 + raw * 0.18;
      out[i] = _env(i, n, attack: 0.03, decayPow: 1.6) * lp * 1.6;
    }
    return out;
  }

  /// Error: dull iron clunk + low buzz.
  List<double> _errorClunk() {
    final n = (_rate * 0.28).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      out[i] = _env(i, n, attack: 0.004) *
          (0.7 * sin(2 * pi * 110 * t) * exp(-t * 16) +
              0.4 * sin(2 * pi * 220 * t + 0.5) * exp(-t * 22) +
              0.25 * sin(2 * pi * 82 * t) * exp(-t * 10));
    }
    return out;
  }

  /// Press lever clunk for game start.
  List<double> _leverClunk() {
    final n = (_rate * 0.3).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      out[i] = _env(i, n, attack: 0.003) *
          (0.8 * sin(2 * pi * 190 * t) * exp(-t * 24) +
              0.4 * sin(2 * pi * 95 * t) * exp(-t * 14) +
              0.2 * (_rand.nextDouble() * 2 - 1) * exp(-t * 60));
    }
    return out;
  }

  List<double> _arp(List<double> freqs, double noteSecs, double gapSecs,
      {double harmonics = 0.2}) {
    final out = <double>[];
    for (final f in freqs) {
      out.addAll(_tone(f, noteSecs, harmonics: harmonics));
      out.addAll(List<double>.filled((_rate * gapSecs).round(), 0));
    }
    return out;
  }

  List<double> _padChord(List<double> freqs, double secs) {
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      double v = 0;
      for (final f in freqs) {
        final t = i / _rate;
        v += sin(2 * pi * f * t) + 0.3 * sin(2 * pi * f * 2 * t);
      }
      v /= freqs.length * 1.3;
      final t = i / n;
      final swell = sin(pi * t.clamp(0.0, 1.0));
      out[i] = v * (0.35 + 0.65 * swell);
    }
    return out;
  }

  Uint8List _clip(String key, List<double> Function() build) =>
      _cache.putIfAbsent(key, () => _wav(build()));

  Uint8List _menuBytes() => _clip('music_menu', () {
        // Warm workshop drone: slow Am – F – C – G pad, 16s loop.
        final seq = [
          [220.0, 261.63, 329.63],
          [174.61, 220.0, 261.63],
          [261.63, 329.63, 392.0],
          [196.0, 246.94, 293.66],
        ];
        final out = <double>[];
        for (final chord in seq) {
          out.addAll(_padChord(chord, 4.0));
        }
        return out;
      });

  Uint8List _gameBytes() => _clip('music_game', () {
        // Print-shop rhythm: soft press thumps at 60bpm under gentle plucks.
        const secs = 12.0;
        final n = (_rate * secs).round();
        final drone = _padChord([130.81, 196.0], secs);
        final out = List<double>.from(drone);
        final thump = _pressThump();
        for (int beat = 0; beat < 12; beat++) {
          final start = (_rate * beat).round();
          for (int i = 0; i < thump.length && start + i < n; i++) {
            out[start + i] += thump[i] * 0.16;
          }
        }
        final plucks = [392.0, 440.0, 523.25, 587.33, 523.25, 440.0];
        for (int k = 0; k < plucks.length; k++) {
          final start = (n * (2 * k + 1) / (2 * plucks.length)).round();
          final tone = _tone(plucks[k], 0.5, harmonics: 0.3);
          for (int i = 0; i < tone.length && start + i < n; i++) {
            out[start + i] += tone[i] * 0.3;
          }
        }
        return out;
      });

  // ------------------------------------------------------------------ SFX
  Future<void> _play(Uint8List bytes) async {
    if (!sfxOn || _disposed) return;
    try {
      await _sfx.play(BytesSource(bytes));
    } catch (_) {}
  }

  Future<void> click() => _play(_clip('click', _brassTap));

  /// Cell filled: ink press thump.
  Future<void> press() => _play(_clip('press', _pressThump));

  /// Cell marked with X: dry scratch.
  Future<void> scratch() => _play(_clip('scratch', _scratch));

  /// Invalid action: iron clunk.
  Future<void> invalid() => _play(_clip('invalid', _errorClunk));

  Future<void> gameStart() => _play(_clip(
      'start',
      () => [
            ..._leverClunk(),
            ..._tone(392, 0.25, freqEnd: 587.33, harmonics: 0.2),
          ]));

  Future<void> hint() => _play(_clip(
      'hint', () => _arp([659.25, 783.99, 987.77], 0.12, 0.03)));

  Future<void> strike() => _play(_clip('strike', () {
        final out = _errorClunk();
        final tone = _tone(196, 0.2, freqEnd: 147, harmonics: 0.4);
        for (int i = 0; i < tone.length && i < out.length; i++) {
          out[i] += tone[i] * 0.5;
        }
        return out;
      }));

  Future<void> win() => _play(_clip(
      'win',
      () => _arp(
          [523.25, 659.25, 783.99, 1046.5, 1318.5, 1567.98], 0.15, 0.03)));

  Future<void> lose() => _play(_clip(
      'lose', () => _arp([329.63, 293.66, 246.94, 196.0], 0.22, 0.05)));

  /// Timed-mode tick warning.
  Future<void> tick() => _play(_clip('tick', () => _tone(880, 0.05)));

  // ----------------------------------------------------------------- music
  /// Start (or keep) a music track. Generation-serialized: the latest request
  /// always wins; a start issued while an older one is in flight is never
  /// dropped. Re-requesting the current track just ensures it is audible.
  Future<void> _startTrack(String track, Uint8List Function() bytes) async {
    if (_disposed) return;
    final gen = ++_musicGen;
    if (_currentTrack == track && !_pausedByLifecycle) {
      try {
        await _music.resume();
      } catch (_) {}
      return;
    }
    while (_musicBusy) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    if (gen != _musicGen || _disposed || !musicOn) return;
    _musicBusy = true;
    try {
      await _music.stop();
      if (gen != _musicGen || _disposed || !musicOn) return;
      _currentTrack = track;
      _pausedByLifecycle = false;
      await _music.play(BytesSource(bytes()));
    } catch (_) {
      if (gen == _musicGen) _currentTrack = null;
    } finally {
      _musicBusy = false;
    }
  }

  Future<void> startMenuMusic() => _startTrack('menu', _menuBytes);
  Future<void> startGameMusic() => _startTrack('game', _gameBytes);

  /// App-scoped stop: cancels any pending start, then stops. Used only when
  /// the user turns music OFF — never on screen navigation.
  Future<void> stopMusic() async {
    ++_musicGen;
    while (_musicBusy) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    if (_disposed) return;
    try {
      await _music.stop();
    } catch (_) {}
    _currentTrack = null;
    _pausedByLifecycle = false;
  }

  Future<void> onAppPaused() async {
    if (_disposed || _currentTrack == null) return;
    try {
      await _music.pause();
      _pausedByLifecycle = true;
    } catch (_) {}
  }

  Future<void> onAppResumed() async {
    if (_disposed || !musicOn || !_pausedByLifecycle) return;
    _pausedByLifecycle = false;
    try {
      await _music.resume();
    } catch (_) {
      final track = _currentTrack;
      _currentTrack = null;
      if (track == 'menu') {
        await startMenuMusic();
      } else if (track == 'game') {
        await startGameMusic();
      }
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    try {
      await _sfx.dispose();
      await _music.dispose();
    } catch (_) {}
  }
}
