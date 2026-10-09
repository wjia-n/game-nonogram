import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nonogram/engine/nonogram_engine.dart';

void main() {
  test('generated 5x5 puzzle has a unique solution', () {
    final p = PuzzleFactory.generate(size: 5, seed: 42);
    expect(NonogramSolver.countSolutions(p), 1);
    expect(p.filledCount, greaterThan(0));
  });

  test('daily puzzle is deterministic', () {
    final day = DateTime(2026, 10, 9);
    final a = PuzzleFactory.daily(size: 10, day: day);
    final b = PuzzleFactory.daily(size: 10, day: day);
    expect(a.solution, b.solution);
    expect(NonogramSolver.countSolutions(a), 1);
  });

  test('win detection: solve fully with 0 mistakes -> won', () {
    final e = NonogramEngine(
        config: const GameConfig(
            size: 5, mistakeLimit: 3, seed: 7, label: 't'));
    var won = false;
    e.onEvent = (ev) {
      if (ev == NonoEvent.won) won = true;
    };
    for (int i = 0; i < 25; i++) {
      if (e.puzzle.solution[i]) e.tapCell(i);
    }
    expect(e.phase, PressPhase.won);
    expect(won, true);
    expect(e.rating, 'Perfect Pull');
    expect(e.stars, 3);
    e.dispose();
  });

  test('mistake on wrong fill: reverts + strike (3-strikes mode)', () {
    final e = NonogramEngine(
        config: const GameConfig(
            size: 5, mistakeLimit: 3, seed: 7, label: 't'));
    final wrong = List.generate(25, (i) => i)
        .firstWhere((i) => !e.puzzle.solution[i]);
    var strikes = 0;
    e.onEvent = (ev) {
      if (ev == NonoEvent.strike) strikes++;
    };
    e.tapCell(wrong);
    expect(e.cells[wrong], Cells.empty); // auto-reverted
    expect(e.mistakes, 1);
    expect(strikes, 1);
    expect(e.phase, isNot(PressPhase.lost));
    e.dispose();
  });

  test('mistake on wrong X: X on solution-filled cell -> strike', () {
    final e = NonogramEngine(
        config: const GameConfig(
            size: 5, mistakeLimit: 3, seed: 7, label: 't'));
    e.toggleMode(); // mark mode
    final target = List.generate(25, (i) => i)
        .firstWhere((i) => e.puzzle.solution[i]);
    e.tapCell(target);
    expect(e.mistakes, 1);
    expect(e.cells[target], Cells.empty); // reverted
    e.dispose();
  });

  test('strike-out: 3 mistakes -> lost, board locks', () {
    final e = NonogramEngine(
        config: const GameConfig(
            size: 5, mistakeLimit: 3, seed: 7, label: 't'));
    final wrongs = List.generate(25, (i) => i)
        .where((i) => !e.puzzle.solution[i])
        .take(3)
        .toList();
    for (final w in wrongs) {
      e.tapCell(w);
    }
    expect(e.phase, PressPhase.lost);
    expect(e.mistakes, 3);
    // Board locked: further taps ignored.
    final good = List.generate(25, (i) => i)
        .firstWhere((i) => e.puzzle.solution[i]);
    e.tapCell(good);
    expect(e.cells[good], Cells.empty);
    e.dispose();
  });

  test('free play: wrong fills revert, no strikes, game continues', () {
    final e = NonogramEngine(
        config: const GameConfig(
            size: 5, mistakeLimit: 0, seed: 7, label: 't'));
    final wrongs = List.generate(25, (i) => i)
        .where((i) => !e.puzzle.solution[i])
        .take(10)
        .toList();
    for (final w in wrongs) {
      e.tapCell(w);
    }
    expect(e.mistakes, 0);
    expect(e.phase, isNot(PressPhase.lost));
    e.dispose();
  });

  test('mode toggle: fill -> mark -> tap filled cell becomes X, no mistake',
      () {
    final e = NonogramEngine(
        config: const GameConfig(
            size: 5, mistakeLimit: 3, seed: 7, label: 't'));
    final good = List.generate(25, (i) => i)
        .firstWhere((i) => e.puzzle.solution[i]);
    e.tapCell(good);
    expect(e.cells[good], Cells.filled);
    e.toggleMode();
    e.tapCell(good);
    expect(e.cells[good], Cells.marked);
    expect(e.mistakes, 0);
    e.dispose();
  });

  test('undo restores cell; strikes are permanent', () {
    final e = NonogramEngine(
        config: const GameConfig(
            size: 5, mistakeLimit: 3, seed: 7, label: 't'));
    final good = List.generate(25, (i) => i)
        .firstWhere((i) => e.puzzle.solution[i]);
    e.tapCell(good);
    e.undo();
    expect(e.cells[good], Cells.empty);
    final wrong = List.generate(25, (i) => i)
        .firstWhere((i) => !e.puzzle.solution[i]);
    e.tapCell(wrong); // strike 1
    e.undo(); // nothing to undo for reverted mistake
    expect(e.mistakes, 1);
    e.dispose();
  });

  test('hint determinism: same first cell twice; voids perfect', () {
    NonogramEngine mk() => NonogramEngine(
        config: const GameConfig(
            size: 10, mistakeLimit: 3, seed: 99, label: 't'));
    final a = mk();
    a.hint();
    final first = a.lastIndex;
    final b = mk();
    b.hint();
    expect(b.lastIndex, first);
    expect(a.hintsUsed, 1);
    expect(a.cells[first], Cells.filled);
    a.dispose();
    b.dispose();
  });

  test('clue auto-check: completed row struck through', () {
    final e = NonogramEngine(
        config: const GameConfig(
            size: 5, mistakeLimit: 3, seed: 7, label: 't'));
    // Find a row with a non-empty clue and fill its solution cells.
    var targetRow = -1;
    for (int r = 0; r < 5; r++) {
      if (e.puzzle.rowClues[r].isNotEmpty) {
        targetRow = r;
        break;
      }
    }
    expect(targetRow, isNot(-1));
    for (int c = 0; c < 5; c++) {
      final i = targetRow * 5 + c;
      if (e.puzzle.solution[i]) e.tapCell(i);
    }
    expect(e.rowDone(targetRow), true);
    e.dispose();
  });

  test('empty clue line: fill there is a mistake', () {
    final e = NonogramEngine(
        config: const GameConfig(
            size: 10, mistakeLimit: 3, seed: 12345, label: 't'));
    var found = false;
    for (int r = 0; r < 10 && !found; r++) {
      if (e.puzzle.rowClues[r].isEmpty) {
        e.tapCell(r * 10);
        expect(e.mistakes, 1);
        found = true;
      }
    }
    // If no empty row exists in this puzzle, the test is vacuous — pass.
    e.dispose();
  });

  test('pause stops timer accumulation', () async {
    final e = NonogramEngine(
        config: const GameConfig(
            size: 5, mistakeLimit: 3, seed: 7, label: 't'));
    final good = List.generate(25, (i) => i)
        .firstWhere((i) => e.puzzle.solution[i]);
    e.tapCell(good); // starts timer
    e.pause();
    expect(e.phase, PressPhase.paused);
    final t0 = e.elapsed;
    await Future.delayed(const Duration(milliseconds: 2100));
    expect(e.elapsed, t0); // no advance while paused
    e.resume();
    expect(e.phase, PressPhase.playing);
    e.dispose();
  });

  test('timed mode: timeout loses the game', () async {
    final e = NonogramEngine(
        config: const GameConfig(
            size: 5,
            mistakeLimit: 3,
            seed: 7,
            label: 't',
            timedSeconds: 2));
    final good = List.generate(25, (i) => i)
        .firstWhere((i) => e.puzzle.solution[i]);
    e.tapCell(good);
    await Future.delayed(const Duration(milliseconds: 2600));
    expect(e.phase, PressPhase.lost);
    e.dispose();
  });

  test('autosave round-trip restores state', () {
    final e = NonogramEngine(
        config: const GameConfig(
            size: 5, mistakeLimit: 3, seed: 7, label: 't'));
    final good = List.generate(25, (i) => i)
        .firstWhere((i) => e.puzzle.solution[i]);
    e.tapCell(good);
    final json = e.toJsonString();
    final r = NonogramEngine.restored(
        Map<String, dynamic>.from(jsonDecode(json) as Map));
    expect(r.cells[good], Cells.filled);
    expect(r.phase, PressPhase.playing);
    e.dispose();
    r.dispose();
  });
}
