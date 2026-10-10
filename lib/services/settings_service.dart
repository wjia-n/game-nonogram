import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/press_themes.dart';

/// Persisted settings, profile, stats and progress for Nonogram.
/// Survives app restarts.
class PressSettings extends ChangeNotifier {
  static const _kMusic = 'nono_music_on';
  static const _kSfx = 'nono_sfx_on';
  static const _kVolume = 'nono_volume';
  static const _kVibrate = 'nono_vibration_on';
  static const _kName = 'nono_player_name';
  static const _kGridSize = 'nono_grid_size';
  static const _kMistakes = 'nono_mistake_limit'; // 0 off, 3, 5
  static const _kAutoCheck = 'nono_auto_check';
  static const _kTheme = 'nono_theme_id';
  static const _kInk = 'nono_ink_style';
  static const _kMark = 'nono_mark_style';
  static const _kBest = 'nono_best_'; // + size
  static const _kStreak = 'nono_daily_streak';
  static const _kLastDaily = 'nono_daily_last'; // yyyy-MM-dd of last streak credit
  static const _kDailyDone = 'nono_daily_done'; // StringList "yyyy-MM-dd:size"
  static const _kPacks = 'nono_pack_'; // + packId: IntList of stars per level
  static const _kGames = 'nono_games_played';
  static const _kWins = 'nono_wins';
  static const _kPerfect = 'nono_perfect_pulls';
  static const _kIsPro = 'nono_is_pro';
  static const _kSave = 'nono_autosave'; // JSON string of in-progress game
  static const _kCustomPrefix = 'nono_custom_';

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;
  bool vibrationOn = true;
  String playerName = 'Printer';
  int gridSize = 10;
  int mistakeLimit = 3; // 0 = off, 3, 5
  bool autoCheck = true;
  String themeId = 'classic';
  int inkStyle = 0;
  int markStyle = 0;
  int gamesPlayed = 0;
  int wins = 0;
  int perfectPulls = 0;
  bool isPro = true; // everything unlocked — no Pro version
  int dailyStreak = 0;
  String lastDailyDate = '';
  Set<String> dailyDone = {};

  /// Pack progress: packId -> stars per level (0 = not completed).
  Map<String, List<int>> packStars = {
    'apprentice': List.filled(10, 0),
    'journeyman': List.filled(12, 0),
    'master': List.filled(12, 0),
  };

  /// Custom colorway colors (ARGB ints).
  Map<String, int> customColors = Map.of(_defaultCustomColors);

  static const Map<String, int> _defaultCustomColors = {
    'ink': 0xFF1E1C1A,
    'paper': 0xFFF4EFE6,
    'brass': 0xFFB08D3F,
    'vermilion': 0xFFC84B31,
  };

  PressThemeDef get customTheme {
    Color c(String k) => Color(customColors[k] ?? 0xFF000000);
    final base = PressThemes.all[0];
    return PressThemeDef(
      id: 'custom',
      name: 'My Colorway',
      benchDark: base.benchDark,
      benchMid: base.benchMid,
      benchDeep: base.benchDeep,
      paper: c('paper'),
      paperDeep: _darken(c('paper'), 0.88),
      ink: c('ink'),
      inkGloss: _lighten(c('ink'), 0.35),
      umber: _darken(c('paper'), 0.55),
      vermilion: c('vermilion'),
      brass: c('brass'),
      brassLight: _lighten(c('brass'), 0.35),
      brassDark: _darken(c('brass'), 0.65),
      iron: base.iron,
      paperText: _darken(c('paper'), 0.32),
      paperTextDim: _darken(c('paper'), 0.55),
    );
  }

  static Color _darken(Color c, double f) => Color.fromARGB(
      0xFF,
      (c.r * f * 255).round().clamp(0, 255),
      (c.g * f * 255).round().clamp(0, 255),
      (c.b * f * 255).round().clamp(0, 255));

  static Color _lighten(Color c, double f) => Color.fromARGB(
      0xFF,
      (c.r * 255 + (255 - c.r * 255) * f).round().clamp(0, 255),
      (c.g * 255 + (255 - c.g * 255) * f).round().clamp(0, 255),
      (c.b * 255 + (255 - c.b * 255) * f).round().clamp(0, 255));

  SharedPreferences? _prefs;
  final Map<int, int> _bestTimes = {}; // size -> seconds

  int bestTime(int size) => _bestTimes[size] ?? 0;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    musicOn = p.getBool(_kMusic) ?? true;
    sfxOn = p.getBool(_kSfx) ?? true;
    volume = p.getDouble(_kVolume) ?? 0.8;
    vibrationOn = p.getBool(_kVibrate) ?? true;
    final nm = (p.getString(_kName) ?? '').trim();
    playerName = nm.isEmpty ? 'Printer' : nm;
    gridSize = (p.getInt(_kGridSize) ?? 10);
    if (![5, 10, 15, 20].contains(gridSize)) gridSize = 10;
    mistakeLimit = p.getInt(_kMistakes) ?? 3;
    if (![0, 3, 5].contains(mistakeLimit)) mistakeLimit = 3;
    autoCheck = p.getBool(_kAutoCheck) ?? true;
    themeId = p.getString(_kTheme) ?? 'classic';
    inkStyle = (p.getInt(_kInk) ?? 0).clamp(0, InkStyle.values.length - 1);
    markStyle = (p.getInt(_kMark) ?? 0).clamp(0, MarkStyle.values.length - 1);
    gamesPlayed = p.getInt(_kGames) ?? 0;
    wins = p.getInt(_kWins) ?? 0;
    perfectPulls = p.getInt(_kPerfect) ?? 0;
    isPro = true; // everything unlocked
    dailyStreak = p.getInt(_kStreak) ?? 0;
    lastDailyDate = p.getString(_kLastDaily) ?? '';
    dailyDone = (p.getStringList(_kDailyDone) ?? []).toSet();
    for (final size in [5, 10, 15, 20]) {
      final b = p.getInt('$_kBest$size') ?? 0;
      if (b > 0) _bestTimes[size] = b;
    }
    for (final id in packStars.keys) {
      final stars = p.getStringList('$_kPacks$id');
      if (stars != null && stars.length == packStars[id]!.length) {
        packStars[id] = [for (final s in stars) int.tryParse(s) ?? 0];
      }
    }
    for (final k in _defaultCustomColors.keys) {
      customColors[k] =
          p.getInt('$_kCustomPrefix$k') ?? _defaultCustomColors[k]!;
    }
    _enforceFreeLimits(silent: true);
    notifyListeners();
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    await p.setBool(_kMusic, musicOn);
    await p.setBool(_kSfx, sfxOn);
    await p.setDouble(_kVolume, volume);
    await p.setBool(_kVibrate, vibrationOn);
    await p.setString(_kName, playerName);
    await p.setInt(_kGridSize, gridSize);
    await p.setInt(_kMistakes, mistakeLimit);
    await p.setBool(_kAutoCheck, autoCheck);
    await p.setString(_kTheme, themeId);
    await p.setInt(_kInk, inkStyle);
    await p.setInt(_kMark, markStyle);
    await p.setInt(_kGames, gamesPlayed);
    await p.setInt(_kWins, wins);
    await p.setInt(_kPerfect, perfectPulls);
    await p.setBool(_kIsPro, isPro);
    await p.setInt(_kStreak, dailyStreak);
    await p.setString(_kLastDaily, lastDailyDate);
    await p.setStringList(_kDailyDone, dailyDone.toList());
    for (final size in [5, 10, 15, 20]) {
      final b = _bestTimes[size] ?? 0;
      if (b > 0) {
        await p.setInt('$_kBest$size', b);
      } else {
        await p.remove('$_kBest$size');
      }
    }
    for (final e in packStars.entries) {
      await p.setStringList(
          '$_kPacks${e.key}', [for (final s in e.value) '$s']);
    }
    for (final e in customColors.entries) {
      await p.setInt('$_kCustomPrefix${e.key}', e.value);
    }
  }

  void _enforceFreeLimits({bool silent = false}) {
    if (isPro) return;
    var changed = false;
    if (PressThemes.isProTheme(themeId)) {
      themeId = 'classic';
      changed = true;
    }
    if (InkStyle.isPro(inkStyle)) {
      inkStyle = 0;
      changed = true;
    }
    if (gridSize == 20) {
      gridSize = 10;
      changed = true;
    }
    if (changed && !silent) {
      notifyListeners();
      _save();
    }
  }

  Future<void> setPro(bool v) async {
    isPro = v;
    if (!v) _enforceFreeLimits();
    notifyListeners();
    await _save();
  }

  Future<void> setMusic(bool v) async {
    musicOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setSfx(bool v) async {
    sfxOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setVolume(double v) async {
    volume = v.clamp(0.0, 1.0);
    notifyListeners();
    await _save();
  }

  Future<void> setVibration(bool v) async {
    vibrationOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setPlayerName(String name) async {
    final clean = name.trim();
    playerName = clean.isEmpty ? 'Printer' : clean;
    notifyListeners();
    await _save();
  }

  Future<void> setGridSize(int v) async {
    if (![5, 10, 15, 20].contains(v)) return;
    if (v == 20 && !isPro) return;
    gridSize = v;
    notifyListeners();
    await _save();
  }

  Future<void> setMistakeLimit(int v) async {
    if (![0, 3, 5].contains(v)) return;
    mistakeLimit = v;
    notifyListeners();
    await _save();
  }

  Future<void> setAutoCheck(bool v) async {
    autoCheck = v;
    notifyListeners();
    await _save();
  }

  Future<void> setTheme(String id) async {
    if (!isPro && PressThemes.isProTheme(id)) return;
    themeId = id;
    notifyListeners();
    await _save();
  }

  Future<void> setInkStyle(int v) async {
    v = v.clamp(0, InkStyle.values.length - 1);
    if (!isPro && InkStyle.isPro(v)) return;
    inkStyle = v;
    notifyListeners();
    await _save();
  }

  Future<void> setMarkStyle(int v) async {
    markStyle = v.clamp(0, MarkStyle.values.length - 1);
    notifyListeners();
    await _save();
  }

  Future<void> setCustomColor(String key, int argb) async {
    if (!_defaultCustomColors.containsKey(key)) return;
    customColors[key] = argb;
    notifyListeners();
    await _save();
  }

  Future<void> resetCustomColors() async {
    customColors = Map.of(_defaultCustomColors);
    notifyListeners();
    await _save();
  }

  /// Record a win. Returns true if this is a new best time for [size].
  Future<bool> recordWin(
      {required int size, required int seconds, required bool perfect}) async {
    gamesPlayed++;
    wins++;
    if (perfect) perfectPulls++;
    var newBest = false;
    final prev = _bestTimes[size] ?? 0;
    if (prev == 0 || seconds < prev) {
      _bestTimes[size] = seconds;
      newBest = true;
    }
    notifyListeners();
    await _save();
    return newBest;
  }

  Future<void> recordGame() async {
    gamesPlayed++;
    notifyListeners();
    await _save();
  }

  /// Daily streak bookkeeping. Call on daily completion; returns true if the
  /// streak was credited (first completion for this calendar day).
  /// [entryKey] overrides the dedupe key (used when a puzzle started before
  /// midnight is finished after — the streak still credits to [day]).
  Future<bool> creditDaily(DateTime day, int size, {String? entryKey}) async {
    final key = _dayKey(day);
    final entry = entryKey ?? '$key:$size';
    if (dailyDone.contains(entry)) return false;
    dailyDone.add(entry);
    // Prune entries older than 60 days.
    final cutoff = _dayKey(day.subtract(const Duration(days: 60)));
    dailyDone.removeWhere((e) => e.split(':').first.compareTo(cutoff) < 0);
    if (lastDailyDate != key) {
      final yesterday = _dayKey(day.subtract(const Duration(days: 1)));
      dailyStreak = (lastDailyDate == yesterday) ? dailyStreak + 1 : 1;
      lastDailyDate = key;
    }
    notifyListeners();
    await _save();
    return true;
  }

  bool dailyCompletedFor(DateTime day, int size) =>
      dailyDone.contains('${_dayKey(day)}:$size');

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> resetBestTimes() async {
    _bestTimes.clear();
    notifyListeners();
    await _save();
  }

  Future<void> recordPackStars(String packId, int level, int stars) async {
    final list = packStars[packId];
    if (list == null || level < 0 || level >= list.length) return;
    if (stars > list[level]) {
      list[level] = stars;
      notifyListeners();
      await _save();
    }
  }

  /// Auto-save slot (JSON written by the engine via the game screen).
  Future<void> writeAutosave(String? json) async {
    final p = _prefs;
    if (p == null) return;
    if (json == null) {
      await p.remove(_kSave);
    } else {
      await p.setString(_kSave, json);
    }
  }

  String? readAutosave() => _prefs?.getString(_kSave);
}
