import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';
import 'game_screen.dart';

void main() => runApp(const NonogramApp());

class NonogramApp extends StatelessWidget {
  const NonogramApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GameShell(
      variant: ShellVariant.neonArcade,
      title: 'Nonogram',
      tagline: 'Paint pixel pictures with clever row and column logic. Pure brain candy!',
      emoji: '🎨',
      slug: 'nonogram',
      howToPlay:
          '• Numbers on rows and columns tell you how many filled squares sit in a row.\n• TAP a square to paint it, LONG-PRESS (or ✖️ mode) to cross out empties.\n• Wrong paint job? That\'s a mistake — 3 mistakes unlocks a 💡 hint.\n• Finish the grid to reveal the hidden pixel masterpiece. Plus a fresh daily puzzle every day! 🎨',
      playerOptions: const [1],
      supportsBots: false,
      gameBuilder: (ctx, players, cb) => NonogramScreen(players: players, callbacks: cb),
    );
  }
}
