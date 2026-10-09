import 'package:flutter_test/flutter_test.dart';
import 'package:nonogram/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression tests for player-name persistence (2026-10-09 batch):
///
/// Player names in Nonogram are a SINGLE name stored with the order-safe
/// plain string key `nono_player_name` (never SharedPreferences.setStringList,
/// which Android backs with an UNORDERED StringSet and which MASTER_RULES.md
/// bans for names after the batch-1 scramble bug in other games). No
/// migration was needed. These tests pin that behavior: a rename must
/// survive a full settings reload (simulated app restart), and blanks fall
/// back to the default name.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('rename survives a simulated app restart', () async {
    SharedPreferences.setMockInitialValues({});
    final s = PressSettings();
    await s.load();
    await s.setPlayerName('Wajiha');
    // Fresh settings object = app restart: same prefs store, new instance.
    final reloaded = PressSettings();
    await reloaded.load();
    expect(reloaded.playerName, 'Wajiha');
  });

  test('keystroke-level renames persist the final value', () async {
    SharedPreferences.setMockInitialValues({});
    final s = PressSettings();
    await s.load();
    // Mirrors the rename field's save-on-keystroke + focus-loss commit.
    await s.setPlayerName('W');
    await s.setPlayerName('Wa');
    await s.setPlayerName('Wajiha');
    expect(s.playerName, 'Wajiha');
    final reloaded = PressSettings();
    await reloaded.load();
    expect(reloaded.playerName, 'Wajiha');
  });

  test('blank rename falls back to the default name', () async {
    SharedPreferences.setMockInitialValues({});
    final s = PressSettings();
    await s.load();
    await s.setPlayerName('   ');
    final reloaded = PressSettings();
    await reloaded.load();
    expect(reloaded.playerName, 'Printer');
  });

  test('surrounding whitespace is trimmed', () async {
    SharedPreferences.setMockInitialValues({});
    final s = PressSettings();
    await s.load();
    await s.setPlayerName('  Zara  ');
    final reloaded = PressSettings();
    await reloaded.load();
    expect(reloaded.playerName, 'Zara');
  });
}
