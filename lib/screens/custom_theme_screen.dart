import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/letterpress.dart';
import '../theme/press_themes.dart';

/// Custom colorway creator (PRO): pick ink, paper, brass and vermilion
/// from press-room palettes, with a live board preview.
class CustomThemeScreen extends StatefulWidget {
  final PressAudio audio;
  final PressSettings settings;
  const CustomThemeScreen(
      {super.key, required this.audio, required this.settings});

  @override
  State<CustomThemeScreen> createState() => _CustomThemeScreenState();
}

class _CustomThemeScreenState extends State<CustomThemeScreen> {
  PressSettings get _s => widget.settings;

  static const _palettes = {
    'ink': [
      0xFF1E1C1A, 0xFF3B2C1E, 0xFF1D2438, 0xFF1E2A22, 0xFF241B1C,
      0xFF2E2118, 0xFF1B1E21, 0xFF4A1420, 0xFF5A3B22, 0xFF232419,
      0xFF0F0C0A, 0xFF3F1D24,
    ],
    'paper': [
      0xFFF4EFE6, 0xFFEAD9B8, 0xFFF0E6D2, 0xFFF6F0E4, 0xFFF3EDE0,
      0xFFF1EBD8, 0xFFF0ECE0, 0xFFF6ECE6, 0xFFECE9DE, 0xFFF7F0DE,
      0xFFF2EDDD, 0xFF2B2620,
    ],
    'brass': [
      0xFFB08D3F, 0xFFC9A24F, 0xFFB87333, 0xFFC9A227, 0xFFD4AF37,
      0xFFAB9040, 0xFFBC9450, 0xFF9A752F, 0xFFA5832F, 0xFFC0C6D4,
      0xFF8A6D1A, 0xFF7A5A2E,
    ],
    'vermilion': [
      0xFFC84B31, 0xFFB23A22, 0xFFA8431F, 0xFFC0402A, 0xFFB8472E,
      0xFFC0392B, 0xFFBC4A28, 0xFFE0603F, 0xFF922B21, 0xFF8E2F1D,
      0xFFD64545, 0xFFA31621,
    ],
  };

  static const _labels = {
    'ink': 'Ink blocks',
    'paper': 'Cotton paper',
    'brass': 'Brass fittings',
    'vermilion': 'Stamp red',
  };

  @override
  Widget build(BuildContext context) {
    final previewTheme = _s.customTheme;
    final t = PressThemes.byId('classic');
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
                  Text('My Colorway',
                      style: Press.display(30, theme: t)),
                  const SizedBox(height: 4),
                  Text('Mix your own press-room palette.',
                      style: Press.body(14,
                          theme: t,
                          color: t.paper.withValues(alpha: 0.7))),
                  const SizedBox(height: 14),
                  _preview(previewTheme),
                  const SizedBox(height: 14),
                  for (final key in _palettes.keys)
                    _colorRow(key, previewTheme),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      widget.audio.strike();
                      _s.resetCustomColors();
                    },
                    child: Transform.rotate(
                      angle: -0.04,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: t.vermilion, width: 3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'RESET PALETTE',
                          style: Press.label(15,
                              theme: t, color: t.vermilion),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  BrassButton(
                    label: _s.themeId == 'custom'
                        ? '✓  Using My Colorway'
                        : 'Use My Colorway',
                    width: 260,
                    theme: t,
                    primary: true,
                    onTap: () {
                      widget.audio.click();
                      _s.setTheme('custom');
                      Navigator.of(context).pop();
                    },
                  ),
                  const SizedBox(height: 10),
                  BrassButton(
                    label: '⬅  Back',
                    width: 260,
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

  Widget _preview(PressThemeDef pt) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [pt.paper, pt.paperDeep],
        ),
        border: Border.all(color: pt.brass, width: 2.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              offset: const Offset(0, 5),
              blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < 5; i++)
                Container(
                  width: 34,
                  height: 34,
                  margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    color: i % 2 == 0 ? pt.ink : pt.paperDeep,
                    border: Border.all(
                        color: pt.umber.withValues(alpha: 0.5)),
                    boxShadow: i % 2 == 0
                        ? [
                            BoxShadow(
                                color: Colors.black
                                    .withValues(alpha: 0.35),
                                offset: const Offset(0, 2),
                                blurRadius: 3),
                          ]
                        : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  gradient: LinearGradient(
                      colors: [pt.brassLight, pt.brass]),
                ),
                child: Text('Aa',
                    style: Press.engraved(16, theme: pt)),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: pt.vermilion, width: 2.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('SEAL',
                    style: Press.label(14,
                        theme: pt, color: pt.vermilion)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _colorRow(String key, PressThemeDef previewTheme) {
    final t = PressThemes.byId('classic');
    final current = _s.customColors[key]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_labels[key]!,
              style: Press.engraved(16, theme: t)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final argb in _palettes[key]!)
                GestureDetector(
                  onTap: () {
                    widget.audio.click();
                    _s.setCustomColor(key, argb);
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(argb),
                      border: Border.all(
                        color: current == argb
                            ? previewTheme.vermilion
                            : t.brass.withValues(alpha: 0.5),
                        width: current == argb ? 3.5 : 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black
                                .withValues(alpha: 0.4),
                            offset: const Offset(0, 2),
                            blurRadius: 4),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
