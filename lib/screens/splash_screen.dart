import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/letterpress.dart';
import '../theme/press_themes.dart';
import 'menu_screen.dart';

/// Launch splash: game logo + name, animated loading line, credits line.
/// Single splash only — no separate company moment.
class SplashScreen extends StatefulWidget {
  final PressAudio audio;
  final PressSettings settings;
  const SplashScreen({super.key, required this.audio, required this.settings});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loader;

  @override
  void initState() {
    super.initState();
    _loader = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _run();
  }

  Future<void> _run() async {
    // Pre-warm audio while the splash shows, then start menu music.
    widget.audio.prewarm();
    widget.audio.startMenuMusic();
    _loader.forward();
    await Future.delayed(const Duration(milliseconds: 1900));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MenuScreen(
          audio: widget.audio,
          settings: widget.settings,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _loader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = PressThemes.byId(
      widget.settings.themeId,
      custom: widget.settings.customTheme,
    );
    return Scaffold(
      backgroundColor: theme.benchDeep,
      body: WorkshopBackdrop(
        theme: theme,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: theme.brass, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      offset: const Offset(0, 10),
                      blurRadius: 24,
                    ),
                    BoxShadow(
                      color: theme.brassLight.withValues(alpha: 0.3),
                      offset: const Offset(0, -2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child:
                    Image.asset('assets/nonogram_logo.png', fit: BoxFit.cover),
              ),
              const SizedBox(height: 22),
              Text('Nonogram', style: Press.display(52, theme: theme)),
              const SizedBox(height: 6),
              Text(
                'THE LETTERPRESS EDITION',
                style: Press.label(13, theme: theme),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: 220,
                child: AnimatedBuilder(
                  animation: _loader,
                  builder: (_, _) => Column(
                    children: [
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: Colors.black.withValues(alpha: 0.45),
                          border: Border.all(
                              color: theme.brass.withValues(alpha: 0.5)),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: _loader.value.clamp(0.02, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              gradient: LinearGradient(
                                colors: [theme.brassLight, theme.brass],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _loader.value < 1 ? 'Inking the press…' : 'Ready!',
                        style: Press.body(13,
                            theme: theme,
                            color: theme.paper.withValues(alpha: 0.75)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 44),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/wajiha_logo.png',
                    width: 30,
                    height: 30,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Credits: WAJIHA',
                    style: Press.label(14, theme: theme),
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
