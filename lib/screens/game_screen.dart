import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../engine/nonogram_engine.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/letterpress.dart';
import '../theme/press_themes.dart';

/// Game board screen — letterpress chase grid with brass clue strips,
/// timer/mistake plaques, Fill/Mark-X mode rail and cast-iron furniture
/// buttons. Victory renders as a freshly pulled print.
class GameScreen extends StatefulWidget {
  final NonogramEngine engine;
  final PressAudio audio;
  final PressSettings settings;

  const GameScreen(
      {super.key,
      required this.engine,
      required this.audio,
      required this.settings});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with WidgetsBindingObserver {
  final Map<int, int> _fillEpoch = {};
  final Map<int, int> _markEpoch = {};
  int _nonce = 0;
  bool _wonHandled = false;
  bool _lostHandled = false;
  bool _newBest = false;

  NonogramEngine get _e => widget.engine;
  PressSettings get _s => widget.settings;
  PressThemeDef get _t =>
      PressThemes.byId(_s.themeId, custom: _s.customTheme);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _e.onSave = (json) => _s.writeAutosave(json);
    _e.onEvent = _onEvent;
    _e.addListener(_onEngine);
    widget.audio.startGameMusic();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _e.removeListener(_onEngine);
    _e.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // RULES.md §12: the timer never runs while the app is backgrounded.
    if (state == AppLifecycleState.paused) {
      _e.pause();
    }
  }

  void _onEngine() {
    if (mounted) setState(() {});
  }

  void _buzz([bool heavy = false]) {
    if (!_s.vibrationOn) return;
    try {
      if (heavy) {
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.lightImpact();
      }
    } catch (_) {}
  }

  void _onEvent(NonoEvent ev) {
    final i = _e.lastIndex;
    switch (ev) {
      case NonoEvent.fill:
        widget.audio.press();
        _buzz();
        if (i >= 0) _fillEpoch[i] = ++_nonce;
      case NonoEvent.mark:
        widget.audio.scratch();
        _buzz();
        if (i >= 0) _markEpoch[i] = ++_nonce;
      case NonoEvent.clear:
        widget.audio.click();
      case NonoEvent.invalid:
        widget.audio.invalid();
        _buzz(true);
      case NonoEvent.strike:
        widget.audio.strike();
        _buzz(true);
      case NonoEvent.hintUsed:
        widget.audio.hint();
        _buzz();
        if (i >= 0) _fillEpoch[i] = ++_nonce;
      case NonoEvent.undo:
        widget.audio.click();
      case NonoEvent.tick:
        widget.audio.tick();
      case NonoEvent.won:
        widget.audio.win();
        _buzz(true);
        _handleWin();
      case NonoEvent.lost:
        widget.audio.lose();
        _buzz(true);
        _handleLose();
    }
    if (mounted) setState(() {});
  }

  Future<void> _handleWin() async {
    if (_wonHandled) return;
    _wonHandled = true;
    final e = _e;
    final perfect = e.mistakes == 0 && e.hintsUsed == 0;
    _newBest = await _s.recordWin(
        size: e.size, seconds: e.elapsed, perfect: perfect);
    if (e.config.dailyKey.isNotEmpty) {
      await _s.creditDaily(DateTime.now(), e.size,
          entryKey: '${e.config.dailyKey}:${e.size}');
    }
    if (e.config.packId.isNotEmpty && e.config.level >= 0) {
      await _s.recordPackStars(e.config.packId, e.config.level, e.stars);
    }
    if (mounted) setState(() {});
  }

  Future<void> _handleLose() async {
    if (_lostHandled) return;
    _lostHandled = true;
    await _s.recordGame();
    if (mounted) setState(() {});
  }

  String _fmt(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  GameConfig? _nextConfig() {
    final c = _e.config;
    if (c.packId.isNotEmpty) {
      final pack = packs.firstWhere((p) => p.id == c.packId);
      if (c.level + 1 < pack.levels) {
        return GameConfig(
          size: c.size,
          mistakeLimit: c.mistakeLimit,
          seed: 0,
          label: '${pack.name} · ${c.level + 2}',
          packId: c.packId,
          level: c.level + 1,
        );
      }
      return null;
    }
    if (c.dailyKey.isNotEmpty) return c; // replay the same daily
    if (c.timedSeconds > 0) {
      return GameConfig(
        size: c.size,
        mistakeLimit: c.mistakeLimit,
        seed: DateTime.now().millisecondsSinceEpoch & 0x7fffffff,
        label: 'Timed Challenge',
        timedSeconds: c.timedSeconds,
      );
    }
    if (c.mistakeLimit == 1) {
      return GameConfig(
        size: c.size,
        mistakeLimit: 1,
        seed: DateTime.now().millisecondsSinceEpoch & 0x7fffffff,
        label: 'Mistake-Free Challenge',
      );
    }
    return GameConfig(
      size: c.size,
      mistakeLimit: c.mistakeLimit,
      seed: DateTime.now().millisecondsSinceEpoch & 0x7fffffff,
      label: '${c.size}×${c.size} Puzzle',
    );
  }

  void _nextPuzzle() {
    final next = _nextConfig();
    if (next == null) {
      Navigator.of(context).pop(true);
      return;
    }
    widget.audio.gameStart();
    final eng = NonogramEngine(config: next);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          engine: eng,
          audio: widget.audio,
          settings: _s,
        ),
      ),
    );
  }

  void _quitToMenu() {
    widget.audio.click();
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final e = _e;
    return WorkshopBackdrop(
      theme: t,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _header(t, e),
                  _modeRail(t, e),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (_, cons) => _boardArea(cons, t, e),
                    ),
                  ),
                  _furnitureRow(t, e),
                ],
              ),
              if (e.phase == PressPhase.paused) _pauseSheet(t),
              if (e.phase == PressPhase.won) _victoryOverlay(t, e),
              if (e.phase == PressPhase.lost) _loseOverlay(t, e),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------- header
  Widget _header(PressThemeDef t, NonogramEngine e) {
    final timed = e.config.timedSeconds > 0;
    final timeText = timed ? _fmt(e.timedLeft) : _fmt(e.elapsed);
    final timeUrgent = timed && e.timedLeft <= 60;
    final pct = (e.progress * 100).round();
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: Column(
        children: [
          Row(
            children: [
              _plaque(t, '⏱', timeText,
                  urgent: timeUrgent,
                  sub: timed ? 'left' : e.config.label),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$pct% pulled',
                      style: Press.label(12, theme: t),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: Colors.black.withValues(alpha: 0.45),
                        border: Border.all(
                            color: t.brass.withValues(alpha: 0.5)),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: e.progress.clamp(0.02, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            gradient: LinearGradient(
                              colors: [t.brassLight, t.brass],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _plaque(
                t,
                '✕',
                e.mistakeLimit == 0
                    ? 'FREE'
                    : '${e.mistakes}/${e.mistakeLimit}',
                urgent: e.mistakeLimit > 0 &&
                    e.mistakes >= e.mistakeLimit - 1,
                sub: e.mistakeLimit == 0 ? 'no strikes' : 'strikes',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _plaque(PressThemeDef t, String icon, String value,
      {bool urgent = false, String? sub}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [t.brassLight, t.brass, t.brassDark],
        ),
        border: Border.all(color: t.benchDeep, width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              offset: const Offset(0, 3),
              blurRadius: 6),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon,
                  style: Press.label(14,
                      theme: t, color: t.benchDeep)),
              const SizedBox(width: 6),
              Text(value,
                  style: Press.display(17, theme: t).copyWith(
                      color: urgent ? t.vermilion : t.benchDeep,
                      shadows: [])),
            ],
          ),
          if (sub != null)
            Text(sub,
                style: Press.label(9, theme: t, color: t.benchDeep),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  // ---------------------------------------------------------- mode rail
  Widget _modeRail(PressThemeDef t, NonogramEngine e) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
      child: Row(
        children: [
          Expanded(
            child: TypeSlug(
              theme: t,
              label: '⬛ INK',
              selected: e.mode == PressMode.fill,
              onTap: () {
                if (e.mode != PressMode.fill) {
                  widget.audio.click();
                  e.toggleMode();
                }
              },
            ),
          ),
          Expanded(
            child: TypeSlug(
              theme: t,
              label: '✕ MARK',
              selected: e.mode == PressMode.mark,
              onTap: () {
                if (e.mode != PressMode.mark) {
                  widget.audio.click();
                  e.toggleMode();
                }
              },
            ),
          ),
          TypeSlug(
            theme: t,
            label: '💡 Hint',
            selected: false,
            onTap: () => e.hint(),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- board
  Widget _boardArea(
      BoxConstraints cons, PressThemeDef t, NonogramEngine e) {
    final n = e.size;
    final rowClues = e.puzzle.rowClues;
    final colClues = e.puzzle.colClues;
    final maxColDepth =
        colClues.map((c) => c.length).fold(0, max);
    final maxRowWidth =
        rowClues.map((c) => c.length).fold(0, max);
    const clueUnit = 17.0;
    final clueW = max(maxRowWidth * clueUnit + 10, 34.0);
    final clueH = max(maxColDepth * clueUnit + 6, 22.0);

    final availW = cons.maxWidth - 28;
    double cell = (availW - clueW - 12) / n;
    var scroll = false;
    if (cell < 26) {
      cell = 26;
      scroll = true;
    }
    cell = cell.clamp(26.0, 52.0);

    final board = _chaseGrid(t, e, cell, clueW, clueH, clueUnit);
    final framed = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [t.iron, t.benchDeep],
        ),
        border: Border.all(color: t.brass, width: 3),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              offset: const Offset(0, 8),
              blurRadius: 16),
        ],
      ),
      child: board,
    );
    final centered = Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: scroll
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal, child: framed)
            : framed,
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: centered,
    );
  }

  Widget _chaseGrid(PressThemeDef t, NonogramEngine e, double cell,
      double clueW, double clueH, double clueUnit) {
    final n = e.size;
    final rowClues = e.puzzle.rowClues;
    final colClues = e.puzzle.colClues;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Column clue strip.
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: clueW),
            for (int c = 0; c < n; c++)
              _clueCell(
                t,
                width: cell,
                height: clueH,
                vertical: true,
                clues: colClues[c],
                done: e.colDone(c),
                clueUnit: clueUnit,
              ),
          ],
        ),
        for (int r = 0; r < n; r++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _clueCell(
                t,
                width: clueW,
                height: cell,
                vertical: false,
                clues: rowClues[r],
                done: e.rowDone(r),
                clueUnit: clueUnit,
              ),
              for (int c = 0; c < n; c++)
                _boardCell(t, e, r * n + c, cell, r, c),
            ],
          ),
      ],
    );
  }

  Widget _clueCell(PressThemeDef t,
      {required double width,
      required double height,
      required bool vertical,
      required List<int> clues,
      required bool done,
      required double clueUnit}) {
    final numerals = clues.isEmpty
        ? [
            Text('0',
                style: _clueNumeral(t, done, clueUnit),
                textAlign: TextAlign.center)
          ]
        : [
            for (final v in clues)
              SizedBox(
                width: vertical ? width : clueUnit,
                height: vertical ? clueUnit : height,
                child: Center(
                  child: Text('$v',
                      style: _clueNumeral(t, done, clueUnit),
                      textAlign: TextAlign.center),
                ),
              ),
          ];
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: done ? 0.55 : 1.0,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [t.brassLight, t.brass, t.brassDark],
          ),
          border: Border.all(color: t.benchDeep.withValues(alpha: 0.6)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            vertical
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: numerals)
                : Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: numerals),
            if (done)
              // Vermilion strike-through, struck like a proofreader's mark.
              Transform.rotate(
                angle: vertical ? 0.5 : -0.12,
                child: Container(
                  width: vertical ? 3 : width * 0.8,
                  height: vertical ? height * 0.8 : 3,
                  decoration: BoxDecoration(
                    color: t.vermilion,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  TextStyle _clueNumeral(
      PressThemeDef t, bool done, double clueUnit) {
    return TextStyle(
      fontFamily: 'serif',
      fontSize: (clueUnit * 0.72).clamp(10.0, 15.0),
      fontWeight: FontWeight.w800,
      color: done
          ? t.benchDeep.withValues(alpha: 0.7)
          : t.benchDeep,
      shadows: [
        Shadow(
            color: t.brassLight.withValues(alpha: 0.9),
            offset: const Offset(0, 1),
            blurRadius: 0),
      ],
    );
  }

  Widget _boardCell(
      PressThemeDef t, NonogramEngine e, int i, double cell, int r, int c) {
    final n = e.size;
    // Wider furniture gaps every 5 cells, like a locked-up chase.
    final padL = c % 5 == 0 ? 1.6 : 0.4;
    final padT = r % 5 == 0 ? 1.6 : 0.4;
    final padR = c == n - 1 ? 1.6 : 0.4;
    final padB = r == n - 1 ? 1.6 : 0.4;
    return Padding(
      padding: EdgeInsets.fromLTRB(padL, padT, padR, padB),
      child: _PressCell(
        key: ValueKey('cell_$i'),
        index: i,
        value: e.cells[i],
        size: cell - 1.2,
        theme: t,
        inkStyle: InkStyle.values[_s.inkStyle],
        markStyle: MarkStyle.values[_s.markStyle],
        flash: e.flashIndex == i,
        dimmed: _s.autoCheck &&
            (e.rowDone(r) || e.colDone(c)),
        fillEpoch: _fillEpoch[i] ?? 0,
        markEpoch: _markEpoch[i] ?? 0,
        onTap: () => e.tapCell(i),
      ),
    );
  }

  // ------------------------------------------------------- furniture row
  Widget _furnitureRow(PressThemeDef t, NonogramEngine e) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _furnitureButton(t, Icons.pause, 'Pause', () {
            widget.audio.click();
            e.pause();
          }),
          const SizedBox(width: 22),
          _furnitureButton(t, Icons.undo, 'Undo', () => e.undo()),
          const SizedBox(width: 22),
          _furnitureButton(t, Icons.refresh, 'Restart', () {
            widget.audio.click();
            _confirmRestart(t, e);
          }),
        ],
      ),
    );
  }

  Widget _furnitureButton(
      PressThemeDef t, IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [t.iron, t.benchDeep],
              ),
              border: Border.all(color: t.brass, width: 2.5),
              boxShadow: [
                BoxShadow(
                    color: t.brassLight.withValues(alpha: 0.25),
                    offset: const Offset(0, -2),
                    blurRadius: 2),
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    offset: const Offset(0, 5),
                    blurRadius: 8),
              ],
            ),
            child: Icon(icon, color: t.brassLight, size: 26),
          ),
          const SizedBox(height: 4),
          Text(label, style: Press.label(11, theme: t)),
        ],
      ),
    );
  }

  void _confirmRestart(PressThemeDef t, NonogramEngine e) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: PaperSheet(
          theme: t,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Start over?',
                  style: Press.engraved(22, theme: t)),
              const SizedBox(height: 8),
              Text('The chase will be unlocked and re-locked fresh.',
                  style: Press.body(14,
                      theme: t, color: t.paperText),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  BrassButton(
                    label: 'Keep going',
                    width: 130,
                    fontSize: 15,
                    theme: t,
                    onTap: () {
                      widget.audio.click();
                      Navigator.of(context).pop();
                    },
                  ),
                  const SizedBox(width: 12),
                  BrassButton(
                    label: 'Restart',
                    width: 130,
                    fontSize: 15,
                    theme: t,
                    primary: true,
                    onTap: () {
                      Navigator.of(context).pop();
                      e.restart();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ overlays
  /// Pause sheet: resume / restart / menu (timer stays stopped).
  Widget _pauseSheet(PressThemeDef t) {
    return Container(
      color: Colors.black.withValues(alpha: 0.65),
      child: Center(
        child: PaperSheet(
          theme: t,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Press Paused',
                  style: Press.engraved(26, theme: t)),
              const SizedBox(height: 6),
              Text('The timer is stopped.',
                  style: Press.body(14,
                      theme: t, color: t.paperTextDim)),
              const SizedBox(height: 18),
              BrassButton(
                label: '▶  Resume',
                width: 220,
                theme: t,
                onTap: () {
                  widget.audio.click();
                  _e.resume();
                },
              ),
              const SizedBox(height: 10),
              BrassButton(
                label: '↻  Restart',
                width: 220,
                theme: t,
                onTap: () {
                  widget.audio.click();
                  _e.restart();
                },
              ),
              const SizedBox(height: 10),
              BrassButton(
                label: '⬅  Menu',
                width: 220,
                theme: t,
                onTap: _quitToMenu,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _victoryOverlay(PressThemeDef t, NonogramEngine e) {
    final perfect = e.mistakes == 0 && e.hintsUsed == 0;
    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Freshly pulled print: grid lines dissolve into the picture.
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [t.paper, t.paperDeep],
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        offset: const Offset(0, 10),
                        blurRadius: 20),
                  ],
                ),
                child: Column(
                  children: [
                    _printImage(t, e),
                    const SizedBox(height: 10),
                    if (e.puzzle.pictureName.isNotEmpty)
                      Text('“${e.puzzle.pictureName}”',
                          style: Press.engraved(18, theme: t)),
                    const SizedBox(height: 4),
                    Text('— a fresh pull from the press —',
                        style: Press.body(12,
                            theme: t, color: t.paperTextDim)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              BrassPlaque(
                title: 'PUZZLE COMPLETE',
                subtitle: e.rating,
                theme: t,
                fontSize: 26,
              ),
              if (perfect) ...[
                const SizedBox(height: 12),
                // Vermilion PERFECT PULL seal, stamped at a jaunty angle.
                Transform.rotate(
                  angle: -0.12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: t.vermilion, width: 4),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '★ PERFECT PULL ★',
                      style: Press.display(20, theme: t)
                          .copyWith(color: t.vermilion, shadows: []),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              // Printer's job ticket tally.
              PaperSheet(
                theme: t,
                padding: const EdgeInsets.symmetric(
                    horizontal: 22, vertical: 14),
                child: Column(
                  children: [
                    Text('JOB TICKET',
                        style: Press.label(13,
                            theme: t, color: t.umber)),
                    const SizedBox(height: 8),
                    _tallyRow(t, 'Time', _fmt(e.elapsed)),
                    _tallyRow(t, 'Mistakes', '${e.mistakes}'),
                    _tallyRow(t, 'Hints', '${e.hintsUsed}'),
                    _tallyRow(
                        t,
                        'Best ${e.size}×${e.size}',
                        _s.bestTime(e.size) > 0
                            ? _fmt(_s.bestTime(e.size))
                            : '—'),
                    if (_newBest)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Transform.rotate(
                          angle: 0.06,
                          child: Text('✦ NEW BEST TIME ✦',
                              style: Press.label(14,
                                  theme: t,
                                  color: t.vermilion)),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              BrassButton(
                label: _nextConfig() == null
                    ? '⬅  Main Menu'
                    : '▶  Next Puzzle',
                width: 250,
                theme: t,
                primary: true,
                onTap: _nextPuzzle,
              ),
              const SizedBox(height: 10),
              BrassButton(
                label: '⬅  Main Menu',
                width: 250,
                theme: t,
                onTap: _quitToMenu,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tallyRow(PressThemeDef t, String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 110,
            child: Text(k,
                style: Press.body(14,
                    theme: t, color: t.paperTextDim)),
          ),
          Text(v,
              style: Press.engraved(16, theme: t)),
        ],
      ),
    );
  }

  Widget _printImage(PressThemeDef t, NonogramEngine e) {
    final n = e.size;
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: t.paperDeep,
          border: Border.all(color: t.umber.withValues(alpha: 0.6)),
        ),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: n),
          itemCount: n * n,
          itemBuilder: (_, i) {
            final on = e.puzzle.solution[i];
            return Container(
              margin: const EdgeInsets.all(0.5),
              decoration: BoxDecoration(
                color: on ? t.ink : Colors.transparent,
                borderRadius: BorderRadius.circular(1),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _loseOverlay(PressThemeDef t, NonogramEngine e) {
    final timedOut =
        e.config.timedSeconds > 0 && e.timedLeft <= 0;
    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BrassPlaque(
                title: timedOut ? 'OUT OF TIME' : 'OUT OF INK',
                subtitle: timedOut
                    ? 'The clock beat the press.'
                    : '${e.mistakes} strikes — the proof is ruined.',
                theme: t,
                fontSize: 26,
              ),
              const SizedBox(height: 14),
              PaperSheet(
                theme: t,
                child: Column(
                  children: [
                    Text(
                        'Pulled: ${(e.progress * 100).round()}%   •   Time: ${_fmt(e.elapsed)}',
                        style: Press.body(14,
                            theme: t, color: t.paperText),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 6),
                    Text('Every master ruins a few proofs.',
                        style: Press.body(13,
                            theme: t,
                            color: t.paperTextDim),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              BrassButton(
                label: '↻  Try Again',
                width: 250,
                theme: t,
                primary: true,
                onTap: () {
                  widget.audio.gameStart();
                  e.restart();
                },
              ),
              const SizedBox(height: 10),
              BrassButton(
                label: '⬅  Main Menu',
                width: 250,
                theme: t,
                onTap: _quitToMenu,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// One press cell: debossed paper well, inked type block, or carved ×.
/// Fill plays an 80ms press-down animation; marks carve in.
class _PressCell extends StatefulWidget {
  final int index;
  final int value;
  final double size;
  final PressThemeDef theme;
  final InkStyle inkStyle;
  final MarkStyle markStyle;
  final bool flash;
  final bool dimmed;
  final int fillEpoch;
  final int markEpoch;
  final VoidCallback onTap;

  const _PressCell({
    super.key,
    required this.index,
    required this.value,
    required this.size,
    required this.theme,
    required this.inkStyle,
    required this.markStyle,
    required this.flash,
    required this.dimmed,
    required this.fillEpoch,
    required this.markEpoch,
    required this.onTap,
  });

  @override
  State<_PressCell> createState() => _PressCellState();
}

class _PressCellState extends State<_PressCell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;
  late final AnimationController _carve;
  int _lastFill = 0;
  int _lastMark = 0;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 130));
    _carve = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 180));
    _lastFill = widget.fillEpoch;
    _lastMark = widget.markEpoch;
  }

  @override
  void didUpdateWidget(covariant _PressCell old) {
    super.didUpdateWidget(old);
    if (widget.fillEpoch != _lastFill) {
      _lastFill = widget.fillEpoch;
      if (_lastFill > 0) _press.forward(from: 0);
    }
    if (widget.markEpoch != _lastMark) {
      _lastMark = widget.markEpoch;
      if (_lastMark > 0) _carve.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _press.dispose();
    _carve.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_press, _carve]),
        builder: (_, _) {
          // 80ms-style press: block slams from 1.22x down to 1.0.
          final p = _press.value;
          final scale = widget.value == Cells.filled
              ? 1.22 - 0.22 * Curves.easeOut.transform(p.clamp(0.0, 1.0))
              : 1.0;
          final carveP = Curves.easeOut.transform(_carve.value.clamp(0.0, 1.0));
          return Transform.scale(
            scale: scale,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: CustomPaint(
                painter: _CellPainter(
                  value: widget.value,
                  t: widget.theme,
                  inkStyle: widget.inkStyle,
                  markStyle: widget.markStyle,
                  flash: widget.flash,
                  dimmed: widget.dimmed,
                  carveProgress: widget.value == Cells.marked
                      ? (_lastMark > 0 ? carveP : 1.0)
                      : 1.0,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CellPainter extends CustomPainter {
  final int value;
  final PressThemeDef t;
  final InkStyle inkStyle;
  final MarkStyle markStyle;
  final bool flash;
  final bool dimmed;
  final double carveProgress;

  _CellPainter({
    required this.value,
    required this.t,
    required this.inkStyle,
    required this.markStyle,
    required this.flash,
    required this.dimmed,
    required this.carveProgress,
  });

  Color get _ink => switch (inkStyle) {
        InkStyle.glossy => t.ink,
        InkStyle.matte => t.ink,
        InkStyle.woodcut => t.ink,
        InkStyle.sepia => const Color(0xFF5A3B22),
        InkStyle.ironGall => const Color(0xFF1E2A44),
        InkStyle.vermilion => t.vermilion,
      };

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = Radius.circular(size.width * 0.14);

    if (flash) {
      // Red-ink mistake warning flash.
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, r),
          Paint()..color = t.vermilion.withValues(alpha: 0.75));
      return;
    }

    if (value == Cells.filled) {
      _paintInkBlock(canvas, size, rect, r);
    } else {
      _paintWell(canvas, size, rect, r);
      if (value == Cells.marked) _paintMark(canvas, size);
      if (dimmed && value == Cells.empty) {
        // Implicitly-empty highlight: faint brass pinprick.
        canvas.drawCircle(
            size.center(Offset.zero),
            size.width * 0.07,
            Paint()..color = t.brass.withValues(alpha: 0.5));
      }
    }
  }

  void _paintWell(Canvas canvas, Size size, Rect rect, Radius r) {
    // Debossed paper well: dark inset on top/left, light on bottom/right.
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect, r),
        Paint()..color = t.paperDeep);
    final w = size.width;
    final inset = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, r));
    canvas.save();
    canvas.clipPath(inset);
    canvas.drawRect(
        Rect.fromLTWH(0, 0, w, w * 0.28),
        Paint()..color = Colors.black.withValues(alpha: 0.16));
    canvas.drawRect(
        Rect.fromLTWH(0, 0, w * 0.22, w),
        Paint()..color = Colors.black.withValues(alpha: 0.10));
    canvas.drawRect(
        Rect.fromLTWH(0, w * 0.78, w, w * 0.22),
        Paint()..color = Colors.white.withValues(alpha: 0.28));
    canvas.drawRect(
        Rect.fromLTWH(w * 0.82, 0, w * 0.18, w),
        Paint()..color = Colors.white.withValues(alpha: 0.18));
    canvas.restore();
  }

  void _paintInkBlock(Canvas canvas, Size size, Rect rect, Radius r) {
    final ink = _ink;
    // Contact shadow beneath the block.
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            rect.shift(const Offset(0, 1.5)), r),
        Paint()..color = Colors.black.withValues(alpha: 0.35));
    // The inked block itself, flush with a hairline paper border.
    final block = rect.deflate(size.width * 0.06);
    canvas.drawRRect(
        RRect.fromRectAndRadius(block, r), Paint()..color = ink);
    if (inkStyle != InkStyle.matte) {
      // Bevel highlight: lamplight from upper-left.
      final hl = Path()
        ..moveTo(block.left, block.bottom)
        ..lineTo(block.left, block.top)
        ..lineTo(block.right, block.top)
        ..lineTo(block.left + size.width * 0.3, block.top)
        ..lineTo(block.left + size.width * 0.3, block.top + size.width * 0.22)
        ..lineTo(block.left + size.width * 0.22, block.top + size.width * 0.3)
        ..lineTo(block.left, block.top + size.width * 0.3)
        ..close();
      canvas.drawPath(
          hl,
          Paint()
            ..color = (inkStyle == InkStyle.glossy
                    ? Colors.white
                    : t.inkGloss)
                .withValues(alpha: inkStyle == InkStyle.glossy ? 0.35 : 0.5));
    }
    if (inkStyle == InkStyle.woodcut) {
      // Carved linocut grain: diagonal hatch lines.
      final grain = Paint()
        ..color = Colors.white.withValues(alpha: 0.10)
        ..strokeWidth = 1.0;
      canvas.save();
      canvas.clipRRect(RRect.fromRectAndRadius(block, r));
      for (double d = -size.width;
          d < size.width * 2;
          d += size.width * 0.16) {
        canvas.drawLine(Offset(d, 0),
            Offset(d + size.width * 0.5, size.height), grain);
      }
      canvas.restore();
    }
    if (inkStyle == InkStyle.glossy) {
      // Wet-ink specular dot.
      canvas.drawCircle(
          Offset(block.left + block.width * 0.3,
              block.top + block.height * 0.28),
          size.width * 0.07,
          Paint()..color = Colors.white.withValues(alpha: 0.5));
    }
  }

  void _paintMark(Canvas canvas, Size size) {
    final p = carveProgress.clamp(0.0, 1.0);
    if (p <= 0) return;
    final c = size.center(Offset.zero);
    final ext = size.width * 0.28 * p;
    final paint = Paint()
      ..color = t.umber.withValues(alpha: 0.75)
      ..strokeWidth = markStyle == MarkStyle.brushed
          ? size.width * 0.13
          : size.width * 0.09
      ..strokeCap = markStyle == MarkStyle.stamped
          ? StrokeCap.round
          : StrokeCap.butt;
    canvas.drawLine(
        c + Offset(-ext, -ext), c + Offset(ext, ext), paint);
    canvas.drawLine(
        c + Offset(ext, -ext), c + Offset(-ext, ext), paint);
  }

  @override
  bool shouldRepaint(covariant _CellPainter old) =>
      old.value != value ||
      old.flash != flash ||
      old.dimmed != dimmed ||
      old.carveProgress != carveProgress ||
      old.t != t ||
      old.inkStyle != inkStyle ||
      old.markStyle != markStyle;
}
