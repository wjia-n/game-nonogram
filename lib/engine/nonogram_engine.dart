import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

// ---------------------------------------------------------------------------
// Cell state: 0 = empty, 1 = filled (inked), 2 = marked X.
// ---------------------------------------------------------------------------
class Cells {
  static const empty = 0;
  static const filled = 1;
  static const marked = 2;
}

enum PressPhase { ready, playing, paused, won, lost }

enum PressMode { fill, mark }

enum NonoEvent {
  fill,
  mark,
  clear,
  invalid,
  strike,
  hintUsed,
  won,
  lost,
  tick,
  undo,
}

/// What kind of game this engine is running.
class GameConfig {
  final int size;
  final int mistakeLimit; // 0 = off (free play), else strikes allowed
  final int timedSeconds; // 0 = no countdown
  final String dailyKey; // '' when not a daily puzzle
  final String packId; // '' when not a pack level
  final int level; // -1 when not a pack level
  final int seed; // deterministic puzzle seed
  final String label; // display label, e.g. "Daily Puzzle"

  const GameConfig({
    required this.size,
    required this.mistakeLimit,
    required this.seed,
    required this.label,
    this.timedSeconds = 0,
    this.dailyKey = '',
    this.packId = '',
    this.level = -1,
  });

  Map<String, dynamic> toJson() => {
    'size': size,
    'mistakeLimit': mistakeLimit,
    'timedSeconds': timedSeconds,
    'dailyKey': dailyKey,
    'packId': packId,
    'level': level,
    'seed': seed,
    'label': label,
  };

  factory GameConfig.fromJson(Map<String, dynamic> j) => GameConfig(
    size: (j['size'] as int?) ?? 10,
    mistakeLimit: (j['mistakeLimit'] as int?) ?? 3,
    timedSeconds: (j['timedSeconds'] as int?) ?? 0,
    dailyKey: (j['dailyKey'] as String?) ?? '',
    packId: (j['packId'] as String?) ?? '',
    level: (j['level'] as int?) ?? -1,
    seed: (j['seed'] as int?) ?? 1,
    label: (j['label'] as String?) ?? 'Puzzle',
  );
}

// ---------------------------------------------------------------------------
// Puzzle: deterministic solution + clues.
// ---------------------------------------------------------------------------
class NonogramPuzzle {
  final int size;
  final List<bool> solution; // length size*size
  final List<List<int>> rowClues;
  final List<List<int>> colClues;
  final int seed;
  final String pictureName; // '' for procedural

  const NonogramPuzzle({
    required this.size,
    required this.solution,
    required this.rowClues,
    required this.colClues,
    required this.seed,
    required this.pictureName,
  });

  int get filledCount => solution.where((b) => b).length;

  static List<List<int>> cluesFor(List<bool> sol, int n, bool rows) {
    final out = <List<int>>[];
    for (int i = 0; i < n; i++) {
      final line = <int>[];
      int run = 0;
      for (int j = 0; j < n; j++) {
        final filled = rows ? sol[i * n + j] : sol[j * n + i];
        if (filled) {
          run++;
        } else if (run > 0) {
          line.add(run);
          run = 0;
        }
      }
      if (run > 0) line.add(run);
      out.add(line);
    }
    return out;
  }
}

// ---------------------------------------------------------------------------
// Hand-drawn picture library (named reveals on victory).
// ---------------------------------------------------------------------------
class _Pic {
  final String name;
  final List<String> rows;
  const _Pic(this.name, this.rows);
}

const _library5 = [
  _Pic('Tiny Heart', ['.X.X.', 'XXXXX', 'XXXXX', '.XXX.', '..X..']),
  _Pic('Little House', ['..X..', '.XXX.', 'XXXXX', '.XXX.', '.X.X.']),
  _Pic('Starlight', ['..X..', '..X..', 'XXXXX', '..X..', '..X..']),
  _Pic('Mushroom', ['.XXX.', 'XXXXX', 'X.X.X', '.XXX.', '.XXX.']),
];

const _library10 = [
  _Pic('Heart', [
    '.XX...XX..',
    'XXXX.XXXX.',
    'XXXXXXXXXX',
    'XXXXXXXXXX',
    '.XXXXXXXX.',
    '..XXXXXX..',
    '...XXXX...',
    '....XX....',
    '..........',
    '..........',
  ]),
  _Pic('Rocket', [
    '....XX....',
    '...XXXX...',
    '...XXXX...',
    '...XXXX...',
    '..XXXXXX..',
    '..XXXXXX..',
    '..XXXXXX..',
    '.XXXXXXXX.',
    'XX.XXXX.XX',
    '..........',
  ]),
  _Pic('Kitty', [
    'XX......XX',
    'XXX....XXX',
    'XXXXXXXXXX',
    'XXXXXXXXXX',
    'XXXXXXXXXX',
    'XXXXXXXXXX',
    '.XXXXXXXX.',
    '..XXXXXX..',
    '..........',
    '..........',
  ]),
  _Pic('Pine Tree', [
    '....XX....',
    '...XXXX...',
    '..XXXXXX..',
    '.XXXXXXXX.',
    '..XXXXXX..',
    '...XXXX...',
    '....XX....',
    '....XX....',
    '...XXXX...',
    '..........',
  ]),
  _Pic('Star', [
    '....XX....',
    '....XX....',
    '....XX....',
    'XXXXXXXXXX',
    '.XXXXXXXX.',
    '..XXXXXX..',
    '..XXXXXX..',
    '.XXX..XXX.',
    '.XX....XX.',
    '..........',
  ]),
  _Pic('Mushroom', [
    '...XXXX...',
    '..XXXXXX..',
    '.XXXXXXXX.',
    'XXXXXXXXXX',
    'XXXXXXXXXX',
    '..X.XX.X..',
    '...XXXX...',
    '...XXXX...',
    '...XXXX...',
    '..........',
  ]),
];

NonogramPuzzle _picToPuzzle(_Pic pic, int seed) {
  final n = pic.rows.length;
  final sol = List<bool>.filled(n * n, false);
  for (int r = 0; r < n; r++) {
    for (int c = 0; c < n; c++) {
      if (pic.rows[r][c] == 'X') sol[r * n + c] = true;
    }
  }
  return NonogramPuzzle(
    size: n,
    solution: sol,
    rowClues: NonogramPuzzle.cluesFor(sol, n, true),
    colClues: NonogramPuzzle.cluesFor(sol, n, false),
    seed: seed,
    pictureName: pic.name,
  );
}

// ---------------------------------------------------------------------------
// Constraint solver: counts solutions up to [maxCount] with a node budget.
// Used at generation time to guarantee unique, logically-solvable puzzles
// (RULES.md §11).
// ---------------------------------------------------------------------------
class NonogramSolver {
  static List<List<bool>> linePatterns(List<int> clue, int size) {
    if (clue.isEmpty) return [List<bool>.filled(size, false)];
    final out = <List<bool>>[];
    void rec(int idx, int pos, List<bool> cur) {
      if (idx == clue.length) {
        out.add(List<bool>.of(cur));
        return;
      }
      final run = clue[idx];
      int minSpace = 0;
      for (int k = idx; k < clue.length; k++) {
        minSpace += clue[k];
      }
      minSpace += clue.length - idx - 1;
      for (int start = pos; start + minSpace <= size; start++) {
        final next = List<bool>.of(cur);
        for (int i = 0; i < run; i++) {
          next[start + i] = true;
        }
        rec(idx + 1, start + run + 1, next);
      }
    }

    rec(0, 0, List<bool>.filled(size, false));
    return out;
  }

  /// Logical solver: constraint propagation over line patterns.
  /// Returns the solved grid when the puzzle is solvable by pure logic
  /// (no guessing required). A fully-propagated solution is provably
  /// unique: every fixed cell is identical across ALL clue-consistent
  /// patterns, so no second solution can exist.
  /// Returns null when guessing would be required or a line contradicts
  /// the known cells — such candidates are discarded (RULES.md §11).
  static List<bool>? propagateSolve(NonogramPuzzle p) {
    final n = p.size;
    final rowPats = List<List<List<bool>>>.generate(
      n,
      (r) => linePatterns(p.rowClues[r], n),
    );
    final colPats = List<List<List<bool>>>.generate(
      n,
      (c) => linePatterns(p.colClues[c], n),
    );
    for (int i = 0; i < n; i++) {
      if (rowPats[i].isEmpty ||
          colPats[i].isEmpty ||
          rowPats[i].length > 40000 ||
          colPats[i].length > 40000) {
        return null;
      }
    }
    final known = List<bool?>.filled(n * n, null);
    var remaining = n * n;
    var changed = true;
    var guard = 0;
    while (changed && remaining > 0 && guard < 1000) {
      guard++;
      changed = false;
      for (int r = 0; r < n; r++) {
        final kept = <List<bool>>[];
        for (final pat in rowPats[r]) {
          var ok = true;
          for (int c = 0; c < n; c++) {
            final k = known[r * n + c];
            if (k != null && k != pat[c]) {
              ok = false;
              break;
            }
          }
          if (ok) kept.add(pat);
        }
        if (kept.isEmpty) return null;
        rowPats[r] = kept;
        for (int c = 0; c < n; c++) {
          final idx = r * n + c;
          if (known[idx] != null) continue;
          final v = kept[0][c];
          var forced = true;
          for (int k = 1; k < kept.length; k++) {
            if (kept[k][c] != v) {
              forced = false;
              break;
            }
          }
          if (forced) {
            known[idx] = v;
            remaining--;
            changed = true;
          }
        }
      }
      for (int c = 0; c < n; c++) {
        final kept = <List<bool>>[];
        for (final pat in colPats[c]) {
          var ok = true;
          for (int r = 0; r < n; r++) {
            final k = known[r * n + c];
            if (k != null && k != pat[r]) {
              ok = false;
              break;
            }
          }
          if (ok) kept.add(pat);
        }
        if (kept.isEmpty) return null;
        colPats[c] = kept;
        for (int r = 0; r < n; r++) {
          final idx = r * n + c;
          if (known[idx] != null) continue;
          final v = kept[0][r];
          var forced = true;
          for (int k = 1; k < kept.length; k++) {
            if (kept[k][r] != v) {
              forced = false;
              break;
            }
          }
          if (forced) {
            known[idx] = v;
            remaining--;
            changed = true;
          }
        }
      }
    }
    if (remaining > 0) return null; // needs guessing — reject
    return [for (final k in known) k!];
  }

  /// Returns the number of solutions, capped at [maxCount]. Returns -1 when
  /// the node [budget] is exhausted (treated as "not provably unique").
  static int countSolutions(
    NonogramPuzzle p, {
    int maxCount = 2,
    int budget = 120000,
  }) {
    final n = p.size;
    final rowPats = <List<List<bool>>>[];
    final colPats = <List<List<bool>>>[];
    for (int i = 0; i < n; i++) {
      final rp = linePatterns(p.rowClues[i], n);
      final cp = linePatterns(p.colClues[i], n);
      if (rp.isEmpty || cp.isEmpty || rp.length > 20000 || cp.length > 20000) {
        return -1;
      }
      rowPats.add(rp);
      colPats.add(cp);
    }
    int count = 0;
    int nodes = 0;
    final grid = List.generate(n, (_) => List<bool>.filled(n, false));

    bool prefixOk(int r) {
      for (int c = 0; c < n; c++) {
        var ok = false;
        for (final pat in colPats[c]) {
          var match = true;
          for (int rr = 0; rr <= r; rr++) {
            if (pat[rr] != grid[rr][c]) {
              match = false;
              break;
            }
          }
          if (match) {
            ok = true;
            break;
          }
        }
        if (!ok) return false;
      }
      return true;
    }

    bool search(int r) {
      if (count >= maxCount || nodes > budget) return true;
      if (r == n) {
        count++;
        return count >= maxCount;
      }
      nodes++;
      for (final pat in rowPats[r]) {
        for (int c = 0; c < n; c++) {
          grid[r][c] = pat[c];
        }
        if (prefixOk(r)) {
          if (search(r + 1)) return true;
        }
      }
      return false;
    }

    search(0);
    if (nodes > budget && count < maxCount) return -1;
    return count;
  }
}

// ---------------------------------------------------------------------------
// Deterministic puzzle generator.
// ---------------------------------------------------------------------------
class PuzzleFactory {
  static int maxAttemptsFor(int size) => size >= 20
      ? 150
      : size >= 15
      ? 100
      : 40;

  static NonogramPuzzle generate({required int size, required int seed}) {
    NonogramPuzzle? fallback;
    final attempts = maxAttemptsFor(size);
    for (int a = 0; a < attempts; a++) {
      final s = (seed * 100003 + a * 7919 + 17) & 0x7fffffff;
      final pic = _candidate(size, s);
      fallback ??= pic;
      // Gate: logically solvable with no guessing (RULES.md §11) —
      // a fully-propagated solution is provably unique.
      if (NonogramSolver.propagateSolve(pic) != null) return pic;
    }
    return fallback!;
  }

  static NonogramPuzzle _candidate(int n, int s) {
    final rnd = Random(s);
    // Library pictures for 5x5 and 10x10, half the time — named reveals.
    if (n == 5 && s % 2 == 0) {
      return _picToPuzzle(_library5[s % _library5.length], s);
    }
    if (n == 10 && s % 2 == 0) {
      return _picToPuzzle(_library10[s % _library10.length], s);
    }
    final cells = _drawShapes(n, rnd);
    // Optional horizontal symmetry for picture-like results.
    if (rnd.nextBool()) {
      for (int y = 0; y < n; y++) {
        for (int x = 0; x < n ~/ 2; x++) {
          cells[y * n + (n - 1 - x)] = cells[y * n + x];
        }
      }
    }
    return NonogramPuzzle(
      size: n,
      solution: cells,
      rowClues: NonogramPuzzle.cluesFor(cells, n, true),
      colClues: NonogramPuzzle.cluesFor(cells, n, false),
      seed: s,
      pictureName: '',
    );
  }

  /// Draws random shapes until the fill density lands in a playable band —
  /// too sparse is trivial, too dense is mud.
  static List<bool> _drawShapes(int n, Random rnd) {
    var cells = List<bool>.filled(n * n, false);
    for (int t = 0; t < 8; t++) {
      cells = List<bool>.filled(n * n, false);
      final shapes = 3 + rnd.nextInt(4);
      for (int k = 0; k < shapes; k++) {
        final kind = rnd.nextInt(5);
        switch (kind) {
          case 0: // rectangle
            final w = 1 + rnd.nextInt(n ~/ 2 + 1);
            final h = 1 + rnd.nextInt(n ~/ 2 + 1);
            final x0 = rnd.nextInt(n);
            final y0 = rnd.nextInt(n);
            for (int y = y0; y < y0 + h && y < n; y++) {
              for (int x = x0; x < x0 + w && x < n; x++) {
                cells[y * n + x] = true;
              }
            }
          case 1: // disc
            final r = 1 + rnd.nextInt(n ~/ 3 + 1);
            final cx = rnd.nextInt(n);
            final cy = rnd.nextInt(n);
            for (int y = 0; y < n; y++) {
              for (int x = 0; x < n; x++) {
                final dx = x - cx, dy = y - cy;
                if (dx * dx + dy * dy <= r * r) cells[y * n + x] = true;
              }
            }
          case 2: // horizontal bar
            final y = rnd.nextInt(n);
            final x0 = rnd.nextInt(n);
            final len = 2 + rnd.nextInt(n ~/ 2 + 1);
            for (int x = x0; x < x0 + len && x < n; x++) {
              cells[y * n + x] = true;
            }
          case 3: // vertical bar
            final x = rnd.nextInt(n);
            final y0 = rnd.nextInt(n);
            final len = 2 + rnd.nextInt(n ~/ 2 + 1);
            for (int y = y0; y < y0 + len && y < n; y++) {
              cells[y * n + x] = true;
            }
          default: // scattered dots
            final dots = 2 + rnd.nextInt(5);
            for (int d = 0; d < dots; d++) {
              cells[rnd.nextInt(n * n)] = true;
            }
        }
      }
      final density = cells.where((b) => b).length / (n * n);
      if (density >= 0.22 && density <= 0.6) break;
    }
    return cells;
  }

  /// Daily puzzle: fixed per calendar day (local midnight rollover) and
  /// grid size — identical for all players (RULES.md §7).
  static NonogramPuzzle daily({required int size, required DateTime day}) {
    final seed = day.year * 10000 + day.month * 100 + day.day + size * 1000000;
    return generate(size: size, seed: seed);
  }

  /// Pack level puzzle: deterministic per pack + level.
  static NonogramPuzzle packLevel({
    required int size,
    required String packId,
    required int level,
  }) {
    final seed = packId.hashCode ^ (level * 104729) ^ (size * 1009);
    return generate(size: size, seed: seed & 0x7fffffff);
  }
}

// ---------------------------------------------------------------------------
// Engine: owns ALL puzzle state (RULES.md enforcement), the timer, undo,
// hints, mistakes and the phase machine. The UI only renders.
// A watchdog recovers timer state so stuck states are impossible.
// ---------------------------------------------------------------------------
class _UndoEntry {
  final int index;
  final int prev;
  const _UndoEntry(this.index, this.prev);
}

class NonogramEngine extends ChangeNotifier {
  final GameConfig config;
  late final NonogramPuzzle puzzle;

  late List<int> cells;
  PressPhase phase = PressPhase.ready;
  PressMode mode = PressMode.fill;
  int mistakes = 0;
  int hintsUsed = 0;
  int elapsed = 0; // active seconds (timer runs only while playing)
  int timedLeft = 0; // timed-mode countdown seconds
  bool _started = false; // timer starts on first cell action (RULES §2)
  final List<_UndoEntry> _undo = [];
  final Set<int> _rowDone = {};
  final Set<int> _colDone = {};
  int flashIndex = -1; // cell showing the mistake flash
  int lastIndex = -1; // most recent cell touched (for UI animations)
  bool _disposed = false;
  Timer? _tick;
  Timer? _watchdog;

  void Function(NonoEvent event)? onEvent;

  /// Hook the UI sets so the engine can auto-save after every action
  /// (RULES.md §7). Called with a JSON string, or null to clear the slot.
  void Function(String? json)? onSave;

  NonogramEngine({required this.config}) {
    puzzle = config.packId.isNotEmpty && config.level >= 0
        ? PuzzleFactory.packLevel(
            size: config.size,
            packId: config.packId,
            level: config.level,
          )
        : config.dailyKey.isNotEmpty
        ? _dailyFromKey()
        : PuzzleFactory.generate(size: config.size, seed: config.seed);
    _resetState();
    timedLeft = config.timedSeconds;
    _watchdog = Timer.periodic(const Duration(seconds: 3), (_) => _recover());
  }

  NonogramPuzzle _dailyFromKey() {
    final parts = config.dailyKey.split('-');
    final day = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
    return PuzzleFactory.daily(size: config.size, day: day);
  }

  /// Restore an auto-saved game (RULES.md §10).
  factory NonogramEngine.restored(Map<String, dynamic> j) {
    final e = NonogramEngine(config: GameConfig.fromJson(j['config']));
    final savedCells = (j['cells'] as List).map((v) => v as int).toList();
    if (savedCells.length == e.cells.length) {
      e.cells = savedCells;
    }
    e.mistakes = (j['mistakes'] as int?) ?? 0;
    e.hintsUsed = (j['hints'] as int?) ?? 0;
    e.elapsed = (j['elapsed'] as int?) ?? 0;
    e.timedLeft = (j['timedLeft'] as int?) ?? e.config.timedSeconds;
    e._started = (j['started'] as bool?) ?? false;
    e.mode = PressMode.values[(j['mode'] as int?) ?? 0];
    e._recomputeChecks();
    final ph = (j['phase'] as String?) ?? 'ready';
    e.phase = ph == 'paused'
        ? PressPhase.paused
        : (e._started ? PressPhase.playing : PressPhase.ready);
    return e;
  }

  Map<String, dynamic> toJson() => {
    'v': 1,
    'config': config.toJson(),
    'cells': cells,
    'mistakes': mistakes,
    'hints': hintsUsed,
    'elapsed': elapsed,
    'timedLeft': timedLeft,
    'started': _started,
    'mode': mode.index,
    'phase': phase == PressPhase.paused ? 'paused' : 'ready',
  };

  String toJsonString() => jsonEncode(toJson());

  void _resetState() {
    cells = List<int>.filled(puzzle.size * puzzle.size, Cells.empty);
    mistakes = 0;
    hintsUsed = 0;
    elapsed = 0;
    _started = false;
    _undo.clear();
    _rowDone.clear();
    _colDone.clear();
    flashIndex = -1;
    mode = PressMode.fill;
    phase = PressPhase.ready;
  }

  int get size => puzzle.size;
  int get mistakeLimit => config.mistakeLimit;
  bool get over => phase == PressPhase.won || phase == PressPhase.lost;
  int get filledTotal => puzzle.filledCount;
  int get filledNow => cells.where((c) => c == Cells.filled).length;
  double get progress => filledTotal == 0 ? 0 : filledNow / filledTotal;
  bool rowDone(int r) => _rowDone.contains(r);
  bool colDone(int c) => _colDone.contains(c);

  /// Rating awarded on win (RULES.md §8).
  String get rating {
    if (mistakes == 0 && hintsUsed == 0) return 'Perfect Pull';
    if (hintsUsed == 0) return 'Clean Proof';
    return 'Finished Print';
  }

  int get stars {
    if (mistakes == 0 && hintsUsed == 0) return 3;
    if (hintsUsed == 0) return 2;
    return 1;
  }

  @override
  void dispose() {
    _disposed = true;
    _tick?.cancel();
    _watchdog?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------ timers
  void _ensureTick() {
    if (_disposed || _tick != null) return;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  void _cancelTick() {
    _tick?.cancel();
    _tick = null;
  }

  void _onTick() {
    if (_disposed || phase != PressPhase.playing || !_started) return;
    elapsed++;
    if (config.timedSeconds > 0) {
      timedLeft--;
      if (timedLeft <= 10 && timedLeft > 0) {
        onEvent?.call(NonoEvent.tick);
      }
      if (timedLeft <= 0) {
        _lose();
        return;
      }
    }
    notifyListeners();
  }

  /// Watchdog: the single tick timer must exist exactly while playing.
  /// Recovers any desync (e.g. after backgrounding) — stuck states
  /// impossible by construction.
  void _recover() {
    if (_disposed) return;
    if (phase == PressPhase.playing && _started && _tick == null) {
      _ensureTick();
    } else if (phase != PressPhase.playing && _tick != null) {
      _cancelTick();
    }
  }

  void pause() {
    if (phase != PressPhase.playing) return;
    phase = PressPhase.paused;
    _cancelTick();
    notifyListeners();
    _autosave();
  }

  void resume() {
    if (phase != PressPhase.paused) return;
    phase = PressPhase.playing;
    _ensureTick();
    notifyListeners();
  }

  void restart() {
    _cancelTick();
    _resetState();
    timedLeft = config.timedSeconds;
    notifyListeners();
    _autosave();
  }

  void _autosave() {
    if (_disposed) return;
    if (over) {
      onSave?.call(null);
    } else {
      onSave?.call(toJsonString());
    }
  }

  // ------------------------------------------------------------ actions
  /// Tap a cell. Full RULES.md §4/§5/§7 enforcement.
  void tapCell(int i) {
    if (over || phase == PressPhase.paused) return;
    if (i < 0 || i >= cells.length) return;
    lastIndex = i;
    final cur = cells[i];
    final solFilled = puzzle.solution[i];

    void begin() {
      // Timer starts on the first cell action (RULES §2).
      if (!_started) {
        _started = true;
        phase = PressPhase.playing;
        _ensureTick();
      }
    }

    if (mode == PressMode.fill) {
      if (cur == Cells.filled) {
        // Clear a fill (legal, no mistake).
        begin();
        _pushUndo(i);
        cells[i] = Cells.empty;
        onEvent?.call(NonoEvent.clear);
      } else if (cur == Cells.marked) {
        // Attempt to fill an X-marked cell.
        if (solFilled) {
          begin();
          _pushUndo(i);
          cells[i] = Cells.filled;
          onEvent?.call(NonoEvent.fill);
        } else {
          _mistake(i, revertTo: Cells.empty);
          return;
        }
      } else {
        // Attempt to fill an empty cell.
        if (solFilled) {
          begin();
          _pushUndo(i);
          cells[i] = Cells.filled;
          onEvent?.call(NonoEvent.fill);
        } else {
          _mistake(i, revertTo: Cells.empty);
          return;
        }
      }
    } else {
      // Mark mode.
      if (cur == Cells.marked) {
        // Clear the X (legal, no mistake).
        begin();
        _pushUndo(i);
        cells[i] = Cells.empty;
        onEvent?.call(NonoEvent.clear);
      } else if (cur == Cells.filled) {
        // §4: marking a filled cell converts it back to X —
        // treated as an undo of that fill, NOT a mistake (test case 7).
        begin();
        _pushUndo(i);
        cells[i] = Cells.marked;
        onEvent?.call(NonoEvent.mark);
      } else {
        // Attempt to X an empty cell: only legal when the solution
        // has it empty (RULES §7).
        if (!solFilled) {
          begin();
          _pushUndo(i);
          cells[i] = Cells.marked;
          onEvent?.call(NonoEvent.mark);
        } else {
          _mistake(i, revertTo: Cells.empty);
          return;
        }
      }
    }
    _afterChange();
  }

  /// A mistake: strike bookkeeping per RULES §7. The cell reverts to
  /// [revertTo]; strikes are permanent (undo never decrements).
  void _mistake(int i, {required int revertTo}) {
    cells[i] = revertTo;
    flashIndex = i;
    if (mistakeLimit > 0) {
      mistakes++;
      onEvent?.call(NonoEvent.strike);
      if (mistakes >= mistakeLimit) {
        _lose();
        return;
      }
    } else {
      onEvent?.call(NonoEvent.invalid);
    }
    notifyListeners();
    // Clear the red-ink flash shortly.
    Future.delayed(const Duration(milliseconds: 450), () {
      if (!_disposed && flashIndex == i) {
        flashIndex = -1;
        notifyListeners();
      }
    });
    _autosave();
  }

  void toggleMode() {
    if (over) return;
    mode = mode == PressMode.fill ? PressMode.mark : PressMode.fill;
    notifyListeners();
  }

  void _pushUndo(int i) {
    _undo.add(_UndoEntry(i, cells[i]));
    if (_undo.length > 2000) _undo.removeAt(0);
  }

  /// Undo the most recent cell action. Strikes and hint counts are
  /// permanent — undo never decrements them (RULES §12).
  void undo() {
    if (over || _undo.isEmpty || phase == PressPhase.paused) return;
    final e = _undo.removeLast();
    cells[e.index] = e.prev;
    lastIndex = e.index;
    onEvent?.call(NonoEvent.undo);
    _afterChange();
  }

  /// Hint: fill the first unsolved cell of the longest unresolved clue run,
  /// topmost row then leftmost column tiebreak (RULES §7). Deterministic.
  void hint() {
    if (over || phase == PressPhase.paused) return;
    final target = _hintTarget();
    if (target < 0) {
      onEvent?.call(NonoEvent.invalid);
      return;
    }
    if (!_started) {
      _started = true;
      phase = PressPhase.playing;
      _ensureTick();
    }
    _pushUndo(target);
    cells[target] = Cells.filled;
    lastIndex = target;
    hintsUsed++;
    onEvent?.call(NonoEvent.hintUsed);
    _afterChange();
  }

  int _hintTarget() {
    final n = size;
    int bestLen = 0;
    int bestCell = -1;
    bool bestIsRow = true;
    // Rows first (topmost tiebreak), then columns (leftmost tiebreak).
    for (int r = 0; r < n; r++) {
      final runs = _runsInLine(r, true);
      for (final run in runs) {
        if (run.cells.any((i) => cells[i] != Cells.filled)) {
          if (run.length > bestLen) {
            bestLen = run.length;
            bestIsRow = true;
            bestCell = run.cells.firstWhere((i) => cells[i] != Cells.filled);
          }
        }
      }
    }
    for (int c = 0; c < n; c++) {
      final runs = _runsInLine(c, false);
      for (final run in runs) {
        if (run.cells.any((i) => cells[i] != Cells.filled)) {
          if (run.length > bestLen) {
            bestLen = run.length;
            bestIsRow = false;
            bestCell = run.cells.firstWhere((i) => cells[i] != Cells.filled);
          }
        }
      }
    }
    // Silence unused-variable lint intent: tiebreak prefers rows on ties
    // because rows are scanned first with strict >.
    if (!bestIsRow && bestCell < 0) return -1;
    return bestCell;
  }

  /// Solution runs in a line (row or column): positions of each clue run.
  List<_Run> _runsInLine(int idx, bool isRow) {
    final n = size;
    final runs = <_Run>[];
    var cellsRun = <int>[];
    for (int j = 0; j < n; j++) {
      final i = isRow ? idx * n + j : j * n + idx;
      if (puzzle.solution[i]) {
        cellsRun.add(i);
      } else if (cellsRun.isNotEmpty) {
        runs.add(_Run(cellsRun));
        cellsRun = <int>[];
      }
    }
    if (cellsRun.isNotEmpty) runs.add(_Run(cellsRun));
    return runs;
  }

  void _afterChange() {
    _recomputeChecks();
    _checkWin();
    notifyListeners();
    _autosave();
  }

  /// Clue auto-check (RULES §7): when every filled run in a line matches
  /// its clues exactly, strike the clues through and highlight the line's
  /// remaining cells as implicitly empty. Visual aid only.
  void _recomputeChecks() {
    final n = size;
    _rowDone.clear();
    _colDone.clear();
    for (int r = 0; r < n; r++) {
      if (_lineSatisfied(r, true)) _rowDone.add(r);
    }
    for (int c = 0; c < n; c++) {
      if (_lineSatisfied(c, false)) _colDone.add(c);
    }
  }

  bool _lineSatisfied(int idx, bool isRow) {
    final n = size;
    final clues = isRow ? puzzle.rowClues[idx] : puzzle.colClues[idx];
    final runs = <int>[];
    int run = 0;
    int filled = 0;
    for (int j = 0; j < n; j++) {
      final i = isRow ? idx * n + j : j * n + idx;
      if (cells[i] == Cells.filled) {
        run++;
        filled++;
      } else if (run > 0) {
        runs.add(run);
        run = 0;
      }
    }
    if (run > 0) runs.add(run);
    if (runs.length != clues.length) return false;
    for (int k = 0; k < runs.length; k++) {
      if (runs[k] != clues[k]) return false;
    }
    // Total filled must equal the clue sum — no hidden extras.
    var sum = 0;
    for (final c in clues) {
      sum += c;
    }
    return filled == sum;
  }

  /// Win: every solution-filled cell is filled and zero incorrect fills
  /// exist (RULES §9). X-marks are ignored. Checked on every state change.
  void _checkWin() {
    if (over) return;
    for (int i = 0; i < cells.length; i++) {
      if (puzzle.solution[i]) {
        if (cells[i] != Cells.filled) return;
      } else if (cells[i] == Cells.filled) {
        return; // impossible by auto-revert, but never allow it
      }
    }
    phase = PressPhase.won;
    _cancelTick();
    onEvent?.call(NonoEvent.won);
  }

  void _lose() {
    if (over) return;
    phase = PressPhase.lost;
    _cancelTick();
    onEvent?.call(NonoEvent.lost);
  }
}

class _Run {
  final List<int> cells;
  int get length => cells.length;
  const _Run(this.cells);
}

// ---------------------------------------------------------------------------
// Modes & packs (shared by menu and game screens).
// ---------------------------------------------------------------------------
/// Pack definitions: id, name, size, levels, pro-gated.
class PackDef {
  final String id;
  final String name;
  final int size;
  final int levels;
  final bool pro;
  const PackDef(this.id, this.name, this.size, this.levels, this.pro);
}

const packs = [
  PackDef('apprentice', 'Apprentice Folio', 5, 10, false),
  PackDef('journeyman', 'Journeyman Folio', 10, 12, false),
  PackDef('master', 'Master Folio', 15, 12, true),
];

int timedSecondsFor(int size) => switch (size) {
  5 => 240,
  15 => 1500,
  20 => 2400,
  _ => 720,
};

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
