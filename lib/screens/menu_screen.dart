import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../engine/nonogram_engine.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/letterpress.dart';
import '../theme/press_themes.dart';
import 'custom_theme_screen.dart';
import 'game_screen.dart';
import 'pro_screen.dart';
import 'settings_screen.dart';

/// Main menu — Craft Letterpress Picross edition.
class MenuScreen extends StatefulWidget {
  final PressAudio audio;
  final PressSettings settings;

  const MenuScreen({super.key, required this.audio, required this.settings});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final StoreService _store = StoreService();
  String? _resumeJson;

  PressSettings get _s => widget.settings;
  PressThemeDef get _t =>
      PressThemes.byId(_s.themeId, custom: _s.customTheme);

  @override
  void initState() {
    super.initState();
    widget.audio.startMenuMusic();
    _store.init().then((_) {
      if (mounted) setState(() {});
    });
    _store.lastThanks.addListener(_onThanks);
    _store.proPurchased.addListener(_onPro);
    _resumeJson = _s.readAutosave();
  }

  void _onThanks() {
    final msg = _store.lastThanks.value;
    if (msg == null || !mounted) return;
    widget.audio.win();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: Press.body(15, theme: _t)),
        backgroundColor: _t.benchDeep,
        behavior: SnackBarBehavior.floating,
      ),
    );
    _store.lastThanks.value = null;
  }

  void _onPro() {
    if (_store.proPurchased.value && mounted) {
      widget.settings.setPro(true);
      _store.proPurchased.value = false;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _store.lastThanks.removeListener(_onThanks);
    _store.proPurchased.removeListener(_onPro);
    _store.dispose();
    super.dispose();
  }

  Future<void> _startGame(GameConfig config) async {
    widget.audio.gameStart();
    final engine = NonogramEngine(config: config);
    engine.onSave = (json) => _s.writeAutosave(json);
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          engine: engine,
          audio: widget.audio,
          settings: _s,
        ),
      ),
    );
    if (!mounted) return;
    widget.audio.startMenuMusic();
    setState(() => _resumeJson = _s.readAutosave());
    if (result == true) setState(() {});
  }

  Future<void> _resumeGame() async {
    final json = _resumeJson;
    if (json == null) return;
    widget.audio.gameStart();
    NonogramEngine engine;
    try {
      engine = NonogramEngine.restored(
          Map<String, dynamic>.from(jsonDecode(json) as Map));
    } catch (_) {
      setState(() => _resumeJson = null);
      return;
    }
    engine.onSave = (j) => _s.writeAutosave(j);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          engine: engine,
          audio: widget.audio,
          settings: _s,
        ),
      ),
    );
    if (!mounted) return;
    widget.audio.startMenuMusic();
    setState(() => _resumeJson = _s.readAutosave());
  }

  GameConfig _quickConfig({int? timed, int? mistakes}) => GameConfig(
        size: _s.gridSize,
        mistakeLimit: mistakes ?? _s.mistakeLimit,
        seed: DateTime.now().millisecondsSinceEpoch & 0x7fffffff,
        label: timed != null
            ? 'Timed Challenge'
            : mistakes == 1
                ? 'Mistake-Free Challenge'
                : '${_s.gridSize}×${_s.gridSize} Puzzle',
        timedSeconds: timed ?? 0,
      );

  void _goPro() {
    widget.audio.click();
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => ProScreen(
            audio: widget.audio,
            settings: _s,
            store: _store,
          ),
        ))
        .then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final today = DateTime.now();
    final dailyDone = _s.dailyCompletedFor(today, _s.gridSize);
    return WorkshopBackdrop(
      theme: t,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListenableBuilder(
            listenable: _s,
            builder: (_, _) => SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              child: Column(
                children: [
                  const SizedBox(height: 6),
                  Container(
                    width: 148,
                    height: 148,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: t.brass, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          offset: const Offset(0, 8),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset('assets/nonogram_logo.png',
                        fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 12),
                  Text('Nonogram', style: Press.display(46, theme: t)),
                  Text(
                    'THE LETTERPRESS EDITION',
                    style: Press.label(12, theme: t),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Welcome back, ${_s.playerName}.',
                    style: Press.body(14,
                        theme: t, color: t.paper.withValues(alpha: 0.7)),
                  ),
                  const SizedBox(height: 20),
                  if (_resumeJson != null) ...[
                    BrassButton(
                      label: '▶  Resume Puzzle',
                      onTap: _resumeGame,
                      theme: t,
                      width: 280,
                      primary: true,
                    ),
                    const SizedBox(height: 12),
                  ],
                  BrassButton(
                    label: '▶  New Puzzle',
                    onTap: () => _startGame(_quickConfig()),
                    theme: t,
                    width: 280,
                  ),
                  const SizedBox(height: 12),
                  BrassButton(
                    label:
                        '${dailyDone ? '✓ ' : '📅 '} Daily Puzzle${_s.dailyStreak > 0 ? '  ·  🔥${_s.dailyStreak}' : ''}',
                    onTap: () => _startGame(GameConfig(
                      size: _s.gridSize,
                      mistakeLimit: _s.mistakeLimit,
                      seed: 0,
                      label: 'Daily Puzzle',
                      dailyKey: dayKey(today),
                    )),
                    theme: t,
                    width: 280,
                  ),
                  const SizedBox(height: 20),
                  _ModeCard(theme: t),
                  const SizedBox(height: 14),
                  _PackCard(theme: t),
                  const SizedBox(height: 14),
                  _StyleCard(theme: t),
                  const SizedBox(height: 14),
                  _ProfileCard(theme: t),
                  const SizedBox(height: 14),
                  _SupportCard(theme: t, store: _store),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _MenuIcon(
                        theme: t,
                        icon: Icons.settings,
                        label: 'Settings',
                        onTap: () async {
                          widget.audio.click();
                          await Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => SettingsScreen(
                              audio: widget.audio,
                              settings: _s,
                            ),
                          ));
                          if (mounted) setState(() {});
                        },
                      ),
                      const SizedBox(width: 26),
                      _MenuIcon(
                        theme: t,
                        icon: Icons.help_outline,
                        label: 'How to Play',
                        onTap: () {
                          widget.audio.click();
                          _showHowTo(context, t);
                        },
                      ),
                      const SizedBox(width: 26),
                      _MenuIcon(
                        theme: t,
                        icon: Icons.workspace_premium,
                        label: _s.isPro ? 'PRO ✓' : 'PRO',
                        onTap: _goPro,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (_s.gamesPlayed > 0)
                    Text(
                      'Solved: ${_s.wins}   •   Perfect: ${_s.perfectPulls}   •   Played: ${_s.gamesPlayed}',
                      style: Press.label(12, theme: t),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/wajiha_logo.png',
                          width: 22, height: 22, fit: BoxFit.contain),
                      const SizedBox(width: 8),
                      Text('Credits: WAJIHA',
                          style: Press.label(12, theme: t)),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showHowTo(BuildContext context, PressThemeDef t) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: PaperSheet(
          theme: t,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('How to Play', style: Press.engraved(24, theme: t)),
                const SizedBox(height: 12),
                for (final line in [
                  '• Numbers beside each row and column tell you the lengths of consecutive filled blocks.',
                  '• FILL mode: tap a square to ink it. MARK mode: tap to carve an × on squares you know are empty.',
                  '• Inking a wrong square is a mistake — it wipes off and costs a strike (in strike modes).',
                  '• Completed rows and columns get struck through in red ink.',
                  '• Finish the whole picture to pull your print. 0 mistakes + 0 hints earns a PERFECT PULL seal.',
                  '• Undo is unlimited; hints void the perfect rating.',
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(line,
                        style: Press.body(14,
                            theme: t, color: t.paperText)),
                  ),
                const SizedBox(height: 16),
                Center(
                  child: BrassButton(
                    label: 'Got it!',
                    width: 180,
                    fontSize: 16,
                    theme: t,
                    onTap: () {
                      widget.audio.click();
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class _MenuIcon extends StatelessWidget {
  final PressThemeDef theme;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuIcon(
      {required this.theme,
      required this.icon,
      required this.label,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [theme.iron, theme.benchDeep],
              ),
              border: Border.all(color: theme.brass, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  offset: const Offset(0, 4),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Icon(icon, color: theme.brassLight, size: 28),
          ),
          const SizedBox(height: 6),
          Text(label, style: Press.label(12, theme: theme)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Game setup: grid size, mistake rule, challenge modes.
class _ModeCard extends StatelessWidget {
  final PressThemeDef theme;
  const _ModeCard({required this.theme});

  @override
  Widget build(BuildContext context) {
    final screen = context.findAncestorStateOfType<_MenuScreenState>()!;
    final s = screen._s;
    final audio = screen.widget.audio;
    return PressCard(
      theme: theme,
      title: 'Press Setup',
      child: Column(
        children: [
          Text('Grid size', style: Press.engraved(15, theme: theme)),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              for (final gz in [5, 10, 15, 20])
                TypeSlug(
                  theme: theme,
                  label: gz == 20 && !s.isPro ? '🔒 20×20' : '$gz×$gz',
                  selected: s.gridSize == gz,
                  onTap: () {
                    audio.click();
                    if (gz == 20 && !s.isPro) {
                      screen._goPro();
                      return;
                    }
                    s.setGridSize(gz);
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Mistake rule', style: Press.engraved(15, theme: theme)),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              for (final m in [0, 3, 5])
                TypeSlug(
                  theme: theme,
                  label: m == 0 ? 'Off' : '$m Strikes',
                  selected: s.mistakeLimit == m,
                  onTap: () {
                    audio.click();
                    s.setMistakeLimit(m);
                  },
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 4,
            children: [
              TypeSlug(
                theme: theme,
                label: '⏱ Timed',
                selected: false,
                onTap: () {
                  audio.click();
                  screen._startGame(screen._quickConfig(
                      timed: timedSecondsFor(s.gridSize)));
                },
              ),
              TypeSlug(
                theme: theme,
                label:
                    '${s.isPro ? '' : '🔒 '}Mistake-Free',
                selected: false,
                onTap: () {
                  audio.click();
                  if (!s.isPro) {
                    screen._goPro();
                    return;
                  }
                  screen._startGame(screen._quickConfig(mistakes: 1));
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Timed: beat the clock. Mistake-Free: one wrong ink ends the run (PRO).',
            style: Press.body(12, theme: theme, color: theme.paperTextDim),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Pack progression: folios of puzzles with star ratings.
class _PackCard extends StatelessWidget {
  final PressThemeDef theme;
  const _PackCard({required this.theme});

  @override
  Widget build(BuildContext context) {
    final screen = context.findAncestorStateOfType<_MenuScreenState>()!;
    final s = screen._s;
    final audio = screen.widget.audio;
    return PressCard(
      theme: theme,
      title: 'Print Folios',
      child: Column(
        children: [
          for (final pack in packs) ...[
            _PackRow(
              theme: theme,
              pack: pack,
              stars: s.packStars[pack.id]!,
              isPro: s.isPro,
              onLevel: (level) {
                audio.click();
                if (pack.pro && !s.isPro) {
                  screen._goPro();
                  return;
                }
                screen._startGame(GameConfig(
                  size: pack.size,
                  mistakeLimit: s.mistakeLimit,
                  seed: 0,
                  label: '${pack.name} · ${level + 1}',
                  packId: pack.id,
                  level: level,
                ));
              },
              onProTap: screen._goPro,
            ),
            const SizedBox(height: 10),
          ],
          Text(
            'Finish a level to unlock the next. Stars: 3 perfect, 2 clean, 1 finished.',
            style: Press.body(12, theme: theme, color: theme.paperTextDim),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PackRow extends StatelessWidget {
  final PressThemeDef theme;
  final PackDef pack;
  final List<int> stars;
  final bool isPro;
  final void Function(int level) onLevel;
  final VoidCallback onProTap;
  const _PackRow({
    required this.theme,
    required this.pack,
    required this.stars,
    required this.isPro,
    required this.onLevel,
    required this.onProTap,
  });

  @override
  Widget build(BuildContext context) {
    final lockedPack = pack.pro && !isPro;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${lockedPack ? '🔒 ' : ''}${pack.name}  (${pack.size}×${pack.size})',
                style: Press.engraved(15, theme: theme),
              ),
            ),
            Text(
              '${stars.where((s) => s > 0).length}/${stars.length}',
              style: Press.label(13, theme: theme),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (int i = 0; i < pack.levels; i++)
              Builder(builder: (_) {
                final unlocked =
                    i == 0 || stars[i - 1] > 0;
                final st = stars[i];
                return GestureDetector(
                  onTap: () {
                    if (lockedPack) {
                      onProTap();
                      return;
                    }
                    if (!unlocked) return;
                    onLevel(i);
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: lockedPack || !unlocked
                            ? [
                                theme.benchDeep.withValues(alpha: 0.6),
                                theme.benchDeep.withValues(alpha: 0.4)
                              ]
                            : st > 0
                                ? [theme.brassLight, theme.brass]
                                : [theme.iron, theme.benchDeep],
                      ),
                      border: Border.all(
                          color: st == 3
                              ? theme.vermilion
                              : theme.brass.withValues(alpha: 0.6),
                          width: st == 3 ? 2.5 : 1.5),
                    ),
                    child: Text(
                      lockedPack || !unlocked
                          ? '🔒'
                          : st > 0
                              ? '★' * st
                              : '${i + 1}',
                      style: Press.label(st > 0 ? 10 : 14,
                          theme: theme,
                          color: st > 0
                              ? theme.benchDeep
                              : theme.brassLight),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
/// Style picker: colorways + ink styles + custom creator.
class _StyleCard extends StatelessWidget {
  final PressThemeDef theme;
  const _StyleCard({required this.theme});

  @override
  Widget build(BuildContext context) {
    final screen = context.findAncestorStateOfType<_MenuScreenState>()!;
    final s = screen._s;
    final audio = screen.widget.audio;
    return PressCard(
      theme: theme,
      title: 'Press Style',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Colorway', style: Press.engraved(15, theme: theme)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final th in PressThemes.all)
                _SwatchTile(
                  theme: theme,
                  swatch: th,
                  name: th.name,
                  selected: s.themeId == th.id,
                  locked: PressThemes.isProTheme(th.id) && !s.isPro,
                  onTap: () {
                    audio.click();
                    if (PressThemes.isProTheme(th.id) && !s.isPro) {
                      screen._goPro();
                      return;
                    }
                    s.setTheme(th.id);
                  },
                ),
              _SwatchTile(
                theme: theme,
                swatch: s.customTheme,
                name: 'My Colorway',
                selected: s.themeId == 'custom',
                locked: !s.isPro,
                onTap: () {
                  audio.click();
                  if (!s.isPro) {
                    screen._goPro();
                    return;
                  }
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => CustomThemeScreen(
                      audio: audio,
                      settings: s,
                    ),
                  ));
                },
              ),
            ],
          ),
          if (!s.isPro)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '🔒 ${PressThemes.all.length - PressThemes.freeThemeIds.length} more colorways in PRO',
                style: Press.label(12,
                    theme: theme, color: theme.paperTextDim),
              ),
            ),
          const SizedBox(height: 14),
          Text('Ink style', style: Press.engraved(15, theme: theme)),
          const SizedBox(height: 6),
          Wrap(
            children: [
              for (int i = 0; i < InkStyle.values.length; i++)
                TypeSlug(
                  theme: theme,
                  label:
                      '${InkStyle.isPro(i) && !s.isPro ? '🔒 ' : ''}${InkStyle.values[i].name}',
                  selected: s.inkStyle == i,
                  onTap: () {
                    audio.click();
                    if (InkStyle.isPro(i) && !s.isPro) {
                      screen._goPro();
                      return;
                    }
                    s.setInkStyle(i);
                  },
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text('× mark style', style: Press.engraved(15, theme: theme)),
          const SizedBox(height: 6),
          Wrap(
            children: [
              for (int i = 0; i < MarkStyle.values.length; i++)
                TypeSlug(
                  theme: theme,
                  label: MarkStyle.values[i].name,
                  selected: s.markStyle == i,
                  onTap: () {
                    audio.click();
                    s.setMarkStyle(i);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SwatchTile extends StatelessWidget {
  final PressThemeDef theme;
  final PressThemeDef swatch;
  final String name;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;
  const _SwatchTile({
    required this.theme,
    required this.swatch,
    required this.name,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 96,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: theme.benchDeep.withValues(alpha: 0.55),
              border: Border.all(
                color: selected
                    ? theme.vermilion
                    : theme.brass.withValues(alpha: 0.35),
                width: selected ? 3 : 1.5,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _dot(swatch.paper),
                    _dot(swatch.ink),
                    _dot(swatch.brass),
                    _dot(swatch.vermilion),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  name,
                  style: Press.label(10,
                      theme: theme, color: theme.paperText),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (locked)
            Container(
              width: 96,
              height: 62,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.black.withValues(alpha: 0.55),
              ),
              child:
                  Icon(Icons.lock, color: theme.brassLight, size: 22),
            ),
        ],
      ),
    );
  }

  Widget _dot(Color c) => Container(
        width: 14,
        height: 14,
        margin: const EdgeInsets.symmetric(horizontal: 1.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: c,
          border: Border.all(color: theme.brassLight, width: 1),
        ),
      );
}

// ---------------------------------------------------------------------------
/// Player profile: renameable, persisted.
class _ProfileCard extends StatelessWidget {
  final PressThemeDef theme;
  const _ProfileCard({required this.theme});

  @override
  Widget build(BuildContext context) {
    final screen = context.findAncestorStateOfType<_MenuScreenState>()!;
    final s = screen._s;
    return PressCard(
      theme: theme,
      title: 'Printer Profile',
      child: _NameField(
        theme: theme,
        initial: s.playerName,
        onDone: (v) => s.setPlayerName(v),
      ),
    );
  }
}

class _NameField extends StatefulWidget {
  final PressThemeDef theme;
  final String initial;
  final ValueChanged<String> onDone;
  const _NameField(
      {required this.theme, required this.initial, required this.onDone});

  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  late final TextEditingController _c;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.initial);
  }

  @override
  void didUpdateWidget(covariant _NameField old) {
    super.didUpdateWidget(old);
    if (old.initial != widget.initial && _c.text != widget.initial) {
      _c.text = widget.initial;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.black.withValues(alpha: 0.08),
        border: Border.all(color: widget.theme.brass.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              offset: const Offset(0, 2),
              blurRadius: 3),
        ],
      ),
      child: TextField(
        controller: _c,
        style: Press.engraved(17, theme: widget.theme),
        maxLength: 16,
        decoration: InputDecoration(
          counterText: '',
          border: InputBorder.none,
          hintText: 'Your printer name',
          hintStyle: Press.body(15,
              theme: widget.theme,
              color: widget.theme.paperTextDim.withValues(alpha: 0.7)),
        ),
        onSubmitted: widget.onDone,
        onEditingComplete: () => widget.onDone(_c.text),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Tip jar (IAP).
class _SupportCard extends StatelessWidget {
  final PressThemeDef theme;
  final StoreService store;
  const _SupportCard({required this.theme, required this.store});

  @override
  Widget build(BuildContext context) {
    final screen = context.findAncestorStateOfType<_MenuScreenState>()!;
    final audio = screen.widget.audio;
    return PressCard(
      theme: theme,
      title: 'Support Wajiha',
      child: Column(
        children: [
          Text(
            'Nonogram is 100% free. If it made you smile, a small tip keeps the press running!',
            style: Press.body(14, theme: theme, color: theme.paperText),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Builder(builder: (_) {
            final tips = [
              store.coffeeProduct,
              store.chocolateProduct,
            ].whereType<ProductDetails>().toList();
            if (!store.storeReady) {
              return Text(
                store.error ?? 'Loading…',
                style: Press.body(13,
                    theme: theme,
                    color: theme.paperTextDim),
                textAlign: TextAlign.center,
              );
            }
            if (tips.isEmpty) {
              return Text('Tips coming soon.',
                  style: Press.body(13,
                      theme: theme, color: theme.paperTextDim));
            }
            return Wrap(
              spacing: 10,
              alignment: WrapAlignment.center,
              children: [
                for (final p in tips)
                  TypeSlug(
                    theme: theme,
                    label: p.id == StoreService.chocolateId
                        ? '🍫 ${p.price}'
                        : '☕ ${p.price}',
                    selected: false,
                    onTap: () {
                      audio.click();
                      store.buyTip(p);
                    },
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}
