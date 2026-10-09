import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/letterpress.dart';
import '../theme/press_themes.dart';

/// Workshop Settings — hanging wooden shop sign, brass-rimmed paper cards,
/// brass press-lever toggles and type-slug selectors. No flat iOS switches.
class SettingsScreen extends StatefulWidget {
  final PressAudio audio;
  final PressSettings settings;
  const SettingsScreen(
      {super.key, required this.audio, required this.settings});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  PressSettings get _s => widget.settings;
  PressThemeDef get _t =>
      PressThemes.byId(_s.themeId, custom: _s.customTheme);

  void _applyAudio() {
    widget.audio.configure(
      musicOn: _s.musicOn,
      sfxOn: _s.sfxOn,
      volume: _s.volume,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
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
                  _hangingSign(t),
                  const SizedBox(height: 18),
                  PressCard(
                    theme: t,
                    title: 'Sound & Music',
                    child: Column(
                      children: [
                        EngravedRow(
                          theme: t,
                          label: 'Sound effects',
                          control: PressLever(
                            theme: t,
                            value: _s.sfxOn,
                            onChanged: (v) {
                              widget.audio.click();
                              _s.setSfx(v);
                              _applyAudio();
                            },
                          ),
                        ),
                        EngravedRow(
                          theme: t,
                          label: 'Music',
                          control: PressLever(
                            theme: t,
                            value: _s.musicOn,
                            onChanged: (v) {
                              widget.audio.click();
                              _s.setMusic(v);
                              _applyAudio();
                              if (v) widget.audio.startMenuMusic();
                            },
                          ),
                        ),
                        EngravedRow(
                          theme: t,
                          label: 'Vibration',
                          control: PressLever(
                            theme: t,
                            value: _s.vibrationOn,
                            onChanged: (v) {
                              widget.audio.click();
                              _s.setVibration(v);
                            },
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text('Volume',
                                style: Press.engraved(15, theme: t)),
                            Expanded(
                              child: BeadSlider(
                                theme: t,
                                value: _s.volume,
                                onChanged: (v) {
                                  _s.setVolume(v);
                                  _applyAudio();
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  PressCard(
                    theme: t,
                    title: 'Press Defaults',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Grid size',
                            style: Press.engraved(15, theme: t)),
                        const SizedBox(height: 6),
                        Wrap(
                          children: [
                            for (final gz in [5, 10, 15, 20])
                              TypeSlug(
                                theme: t,
                                label: gz == 20 && !_s.isPro
                                    ? '🔒 20×20'
                                    : '$gz×$gz',
                                selected: _s.gridSize == gz,
                                onTap: () {
                                  widget.audio.click();
                                  _s.setGridSize(gz);
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text('Mistake limit',
                            style: Press.engraved(15, theme: t)),
                        const SizedBox(height: 6),
                        Wrap(
                          children: [
                            for (final m in [0, 3, 5])
                              TypeSlug(
                                theme: t,
                                label:
                                    m == 0 ? 'Off' : '$m Strikes',
                                selected: _s.mistakeLimit == m,
                                onTap: () {
                                  widget.audio.click();
                                  _s.setMistakeLimit(m);
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        EngravedRow(
                          theme: t,
                          label: 'Auto-check marks',
                          control: PressLever(
                            theme: t,
                            value: _s.autoCheck,
                            onChanged: (v) {
                              widget.audio.click();
                              _s.setAutoCheck(v);
                            },
                          ),
                        ),
                        Text(
                          'Strike through clues and pinprick empty cells when a line is solved.',
                          style: Press.body(12,
                              theme: t,
                              color: t.paperTextDim),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  PressCard(
                    theme: t,
                    title: 'Records',
                    child: Column(
                      children: [
                        for (final gz in [5, 10, 15, 20])
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text('$gz×$gz best',
                                      style: Press.engraved(15,
                                          theme: t)),
                                ),
                                Text(
                                  _s.bestTime(gz) > 0
                                      ? _fmt(_s.bestTime(gz))
                                      : '—',
                                  style: Press.label(15,
                                      theme: t,
                                      color: t.umber),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 10),
                        // Vermilion reset stamp.
                        GestureDetector(
                          onTap: () => _confirmReset(t),
                          child: Transform.rotate(
                            angle: -0.04,
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 10),
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: t.vermilion, width: 3),
                                borderRadius:
                                    BorderRadius.circular(4),
                              ),
                              child: Text(
                                'RESET BEST TIMES',
                                style: Press.label(15,
                                    theme: t,
                                    color: t.vermilion),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  BrassButton(
                    label: '⬅  Back to Menu',
                    width: 250,
                    theme: t,
                    onTap: () {
                      widget.audio.click();
                      Navigator.of(context).pop();
                    },
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

  String _fmt(int secs) =>
      '${(secs ~/ 60).toString().padLeft(2, '0')}:${(secs % 60).toString().padLeft(2, '0')}';

  /// Hanging wooden shop sign header.
  Widget _hangingSign(PressThemeDef t) {
    return Column(
      children: [
        // Chains.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _chain(t),
            const SizedBox(width: 120),
            _chain(t),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 30, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [t.benchMid, t.benchDeep],
            ),
            border: Border.all(color: t.brass, width: 3),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  offset: const Offset(0, 8),
                  blurRadius: 14),
            ],
          ),
          child: Text('WORKSHOP SETTINGS',
              style: Press.display(24, theme: t),
              textAlign: TextAlign.center),
        ),
      ],
    );
  }

  Widget _chain(PressThemeDef t) => Container(
        width: 6,
        height: 26,
        decoration: BoxDecoration(
          color: t.brassDark,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: t.brassLight, width: 1),
        ),
      );

  void _confirmReset(PressThemeDef t) {
    widget.audio.click();
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: PaperSheet(
          theme: t,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Wipe the record books?',
                  style: Press.engraved(20, theme: t),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('All best times return to —.',
                  style: Press.body(14,
                      theme: t, color: t.paperText),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  BrassButton(
                    label: 'Keep',
                    width: 120,
                    fontSize: 15,
                    theme: t,
                    onTap: () {
                      widget.audio.click();
                      Navigator.of(context).pop();
                    },
                  ),
                  const SizedBox(width: 12),
                  BrassButton(
                    label: 'Wipe',
                    width: 120,
                    fontSize: 15,
                    theme: t,
                    primary: true,
                    onTap: () {
                      widget.audio.strike();
                      _s.resetBestTimes();
                      Navigator.of(context).pop();
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
}
