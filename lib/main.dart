import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/splash_screen.dart';
import 'services/audio_service.dart';
import 'services/settings_service.dart';
import 'theme/letterpress.dart';
import 'theme/press_themes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  final settings = PressSettings();
  await settings.load();
  final audio = PressAudio();
  audio.configure(
    musicOn: settings.musicOn,
    sfxOn: settings.sfxOn,
    volume: settings.volume,
  );
  runApp(NonogramApp(settings: settings, audio: audio));
}

class NonogramApp extends StatefulWidget {
  final PressSettings settings;
  final PressAudio audio;
  const NonogramApp({super.key, required this.settings, required this.audio});

  @override
  State<NonogramApp> createState() => _NonogramAppState();
}

class _NonogramAppState extends State<NonogramApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.audio.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause (not stop) on interruption so music resumes exactly where it
    // left off; game engines freeze their own timers via the watchdog.
    if (state == AppLifecycleState.paused) {
      widget.audio.onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      widget.audio.onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (_, _) => MaterialApp(
        title: 'Nonogram',
        debugShowCheckedModeBanner: false,
        theme: Press.theme(PressThemes.byId(widget.settings.themeId,
            custom: widget.settings.customTheme)),
        home: SplashScreen(
            audio: widget.audio, settings: widget.settings),
      ),
    );
  }
}
