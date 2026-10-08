import 'dart:math';
import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';

/// Nonogram: 10x10 pixel-logic. Tap = paint, long-press = cross.
/// 6 built-in pictures + a seeded daily puzzle. Win reveals the art.
class _Pic {
  final String name;
  final String emoji;
  final List<String> rows;
  const _Pic(this.name, this.emoji, this.rows);
}

const _pics = [
  _Pic('Heart', '❤️', [
    '.XXX..XXX.',
    'XXXXXXXXXX',
    'XXXXXXXXXX',
    'XXXXXXXXXX',
    'XXXXXXXXXX',
    '.XXXXXXXX.',
    '..XXXXXX..',
    '...XXXX...',
    '....XX....',
    '..........',
  ]),
  _Pic('Rocket', '🚀', [
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
  _Pic('Kitty', '🐱', [
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
  _Pic('Tree', '🌳', [
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
  _Pic('Star', '⭐', [
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
  _Pic('Shroom', '🍄', [
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

const int _n = 10;

class NonogramScreen extends StatefulWidget {
  final List<Player> players;
  final GameCallbacks callbacks;
  const NonogramScreen({super.key, required this.players, required this.callbacks});

  @override
  State<NonogramScreen> createState() => _NonogramScreenState();
}

class _NonogramScreenState extends State<NonogramScreen> with SingleTickerProviderStateMixin {
  int _picIdx = 0; // 0..5 built-ins, 6 = daily
  late Set<int> _solution;
  late List<int> _grid; // 0 unknown, 1 painted, 2 crossed
  bool _crossMode = false;
  int _mistakes = 0;
  bool _hintUsed = false;
  bool _over = false;
  int _flash = -1;
  late AnimationController _pop;

  @override
  void initState() {
    super.initState();
    _pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _loadPuzzle(0);
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  Set<int> _dailySolution() {
    final day = DateTime.now().difference(DateTime(2026, 1, 1)).inDays;
    final rnd = Random(day * 7919 + 13);
    Set<int> s = {};
    int guard = 0;
    while ((s.length < 22 || s.length > 46) && guard < 60) {
      guard++;
      s = {};
      for (int r = 0; r < _n; r++) {
        for (int c = 0; c < 5; c++) {
          if (rnd.nextDouble() < 0.44) {
            s.add(r * _n + c);
            s.add(r * _n + (9 - c));
          }
        }
      }
    }
    return s;
  }

  void _loadPuzzle(int idx) {
    _picIdx = idx;
    if (idx < _pics.length) {
      _solution = {};
      for (int r = 0; r < _n; r++) {
        for (int c = 0; c < _n; c++) {
          if (_pics[idx].rows[r][c] == 'X') _solution.add(r * _n + c);
        }
      }
    } else {
      _solution = _dailySolution();
    }
    _grid = List.filled(_n * _n, 0);
    _mistakes = 0;
    _hintUsed = false;
    _over = false;
    _flash = -1;
    _crossMode = false;
    setState(() {});
  }

  List<List<int>> _clues(bool forRows) {
    final out = <List<int>>[];
    for (int i = 0; i < _n; i++) {
      final line = <int>[];
      int run = 0;
      for (int j = 0; j < _n; j++) {
        final filled = forRows ? _solution.contains(i * _n + j) : _solution.contains(j * _n + i);
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

  int get _painted => _grid.where((v) => v == 1).length;

  void _tapCell(int i) {
    if (_over) return;
    final v = _grid[i];
    if (_crossMode) {
      _grid[i] = v == 2 ? 0 : 2;
      Sfx.tap();
      setState(() {});
      return;
    }
    if (v == 1) {
      _grid[i] = 0; // unpaint
      Sfx.tap();
      setState(() {});
      return;
    }
    if (v == 2) {
      _grid[i] = 0;
      Sfx.tap();
      setState(() {});
      return;
    }
    // v == 0: attempt paint
    if (_solution.contains(i)) {
      _grid[i] = 1;
      Sfx.click();
      _pop.forward(from: 0);
      setState(() {});
      _checkWin();
    } else {
      _grid[i] = 2;
      _mistakes++;
      _flash = i;
      Sfx.lose();
      setState(() {});
      Future.delayed(const Duration(milliseconds: 450), () {
        if (mounted) setState(() => _flash = -1);
      });
    }
  }

  void _longPressCell(int i) {
    if (_over) return;
    _grid[i] = _grid[i] == 2 ? 0 : 2;
    Sfx.tap();
    setState(() {});
  }

  void _useHint() {
    if (_hintUsed || _mistakes < 3 || _over) return;
    final missing = _solution.where((c) => _grid[c] != 1).toList();
    if (missing.isEmpty) return;
    missing.shuffle();
    _grid[missing.first] = 1;
    _hintUsed = true;
    Sfx.win();
    setState(() {});
    _checkWin();
  }

  void _checkWin() {
    if (_over) return;
    for (final c in _solution) {
      if (_grid[c] != 1) return;
    }
    _over = true;
    Sfx.win();
    _fanfare();
  }

  void _fanfare() {
    final t = ThemeController.of(context).theme;
    final pic = _picIdx < _pics.length ? _pics[_picIdx] : null;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => WajihaDialog(
        title: 'Masterpiece complete!',
        emoji: '🎨',
        children: [
          Text(
            pic != null ? 'You painted the ${pic.name} ${pic.emoji}!' : 'You cracked the daily puzzle! 📅',
            textAlign: TextAlign.center,
            style: TextStyle(color: t.muted, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ScaleTransition(
            scale: Tween(begin: 0.6, end: 1.0).animate(CurvedAnimation(parent: _pop, curve: Curves.elasticOut)),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: t.background, borderRadius: t.radius),
              child: AspectRatio(
                aspectRatio: 1,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: _n),
                  itemCount: _n * _n,
                  itemBuilder: (_, i) {
                    final on = _solution.contains(i);
                    final hue = ((i ~/ _n) * 36 + (i % _n) * 12) % 360;
                    return Container(
                      margin: const EdgeInsets.all(0.6),
                      decoration: BoxDecoration(
                        color: on ? HSVColor.fromAHSV(1, hue.toDouble(), 0.75, 0.95).toColor() : t.surface,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('✨ Mistakes: $_mistakes ✨',
              textAlign: TextAlign.center, style: TextStyle(color: t.muted, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          WajihaButton(
            label: 'Keep painting',
            emoji: '🖌️',
            onTap: () {
              Navigator.pop(context);
              widget.callbacks.finish(
                headline: 'Gallery growing! 🎨',
                subline: _mistakes == 0 ? 'Flawless — not a single wrong brushstroke!' : 'Finished with $_mistakes mistake${_mistakes == 1 ? '' : 's'}.',
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeController.of(context).theme;
    final rowClues = _clues(true);
    final colClues = _clues(false);
    final maxColDepth = colClues.map((c) => c.length).fold(0, max);
    final maxRowWidth = rowClues.map((c) => c.length).fold(0, max);
    final pct = _solution.isEmpty ? 0 : (_painted * 100 ~/ _solution.length);
    final picName = _picIdx < _pics.length ? '${_pics[_picIdx].emoji} ${_pics[_picIdx].name}' : '📅 Daily';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(picName, style: TextStyle(color: t.text, fontWeight: FontWeight.w900, fontSize: 18)),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: _solution.isEmpty ? 0 : _painted / _solution.length,
                        minHeight: 8,
                        backgroundColor: t.surface,
                        valueColor: AlwaysStoppedAnimation(t.primary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _statChip(t, '🎯', '$pct%'),
              const SizedBox(width: 8),
              _statChip(t, '💥', '$_mistakes'),
              if (_mistakes >= 3 && !_hintUsed && !_over) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _useHint,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [t.primary, t.secondary]), borderRadius: BorderRadius.circular(99)),
                    child: const Text('💡 Hint', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _pics.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final sel = i == _picIdx;
              final label = i < _pics.length ? _pics[i].emoji : '📅';
              return GestureDetector(
                onTap: () {
                  Sfx.click();
                  _loadPuzzle(i);
                },
                child: Container(
                  width: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: sel ? t.primary : t.surface,
                    borderRadius: t.radius,
                    border: Border.all(color: sel ? t.primary : t.muted.withValues(alpha: 0.25)),
                  ),
                  child: Text(label, style: const TextStyle(fontSize: 20)),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: LayoutBuilder(
            builder: (_, cons) {
              final clueW = maxRowWidth * 20.0 + 8;
              final cell = ((cons.maxWidth - clueW - 32) / _n).clamp(18.0, 44.0);
              final boardW = cell * _n;
              return SingleChildScrollView(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: t.surface, borderRadius: t.radius),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // column clues
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(width: clueW),
                              for (int c = 0; c < _n; c++)
                                SizedBox(
                                  width: cell,
                                  height: maxColDepth * 20.0,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      for (final n in colClues[c])
                                        SizedBox(
                                          height: 20,
                                          child: Center(
                                              child: Text('$n',
                                                  style: TextStyle(
                                                      color: t.muted, fontWeight: FontWeight.w800, fontSize: 13))),
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          for (int r = 0; r < _n; r++)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: clueW,
                                  height: cell,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      for (final n in rowClues[r])
                                        SizedBox(
                                          width: 20,
                                          child: Center(
                                              child: Text('$n',
                                                  style: TextStyle(
                                                      color: t.muted, fontWeight: FontWeight.w800, fontSize: 13))),
                                        ),
                                    ],
                                  ),
                                ),
                                for (int c = 0; c < _n; c++) _cell(t, r * _n + c, cell, r, c),
                              ],
                            ),
                          SizedBox(width: boardW + clueW),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
          child: Row(
            children: [
              Expanded(
                child: WajihaButton(
                  label: _crossMode ? 'Cross mode ✖️' : 'Paint mode 🖌️',
                  emoji: '',
                  primary: _crossMode,
                  onTap: () {
                    Sfx.click();
                    setState(() => _crossMode = !_crossMode);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: WajihaButton(
                  label: 'Restart',
                  emoji: '🔄',
                  primary: false,
                  onTap: () {
                    Sfx.click();
                    _loadPuzzle(_picIdx);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statChip(GameTheme t, String emoji, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(99)),
      child: Text('$emoji $value', style: TextStyle(color: t.text, fontWeight: FontWeight.w900)),
    );
  }

  Widget _cell(GameTheme t, int i, double size, int r, int c) {
    final v = _grid[i];
    final flash = i == _flash;
    final thickR = r % 5 == 0, thickC = c % 5 == 0;
    return GestureDetector(
      onTap: () => _tapCell(i),
      onLongPress: () => _longPressCell(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: size,
        height: size,
        margin: EdgeInsets.only(
          left: thickC ? 1.2 : 0.4,
          top: thickR ? 1.2 : 0.4,
          right: c == _n - 1 ? 1.2 : 0.4,
          bottom: r == _n - 1 ? 1.2 : 0.4,
        ),
        decoration: BoxDecoration(
          color: flash
              ? const Color(0xFFE5484D)
              : v == 1
                  ? t.primary
                  : t.background,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
              color: flash ? const Color(0xFFE5484D) : t.muted.withValues(alpha: 0.25), width: (thickR || thickC) ? 1.4 : 0.6),
        ),
        alignment: Alignment.center,
        child: v == 2
            ? Text('✕', style: TextStyle(color: flash ? Colors.white : t.muted, fontWeight: FontWeight.w900, fontSize: size * 0.5))
            : null,
      ),
    );
  }
}
