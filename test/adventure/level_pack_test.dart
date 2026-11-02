import 'dart:convert';
import 'dart:io';

import 'package:break_block_adventure/features/adventure/engine/level_validator.dart';
import 'package:break_block_adventure/features/adventure/engine/sliding_puzzle_engine.dart';
import 'package:break_block_adventure/features/adventure/levels/world_catalog.dart';
import 'package:break_block_adventure/features/adventure/models/puzzle_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every shipped level must be well-formed and provably solvable within its
/// move limit, and replaying the solver's solution must actually win.
void main() {
  const engine = SlidingPuzzleEngine();
  const validator = LevelValidator();

  for (final world in WorldCatalog.worlds) {
    final file = File(world.assetPath);
    if (!file.existsSync()) continue; // packs are generated incrementally
    group('World ${world.id} (${world.name})', () {
      final levels = [
        for (final j in jsonDecode(file.readAsStringSync()) as List)
          PuzzleLevel.fromJson((j as Map).cast<String, dynamic>()),
      ];

      test('has sequential level ids', () {
        expect([for (final l in levels) l.levelId], List.generate(levels.length, (i) => i + 1));
        expect(levels.every((l) => l.worldId == world.id), isTrue);
      });

      test('all levels valid, solvable, and solutions replay to a win', () {
        for (final l in levels) {
          final r = validator.validate(l);
          expect(r.isValid, isTrue, reason: r.toString());
          var s = engine.initializeLevel(l);
          for (final m in r.solution!) {
            final out = engine.moveBlock(l, s, m);
            expect(out, isNotNull, reason: 'level ${l.key}: solver move $m rejected');
            s = out!.state;
          }
          expect(s.status, PuzzleStatus.won, reason: 'level ${l.key}');
          expect(l.starsFor(s.movesUsed), 3, reason: 'optimal play must earn 3 stars on ${l.key}');
        }
      }, timeout: const Timeout(Duration(minutes: 10)));
    });
  }
}
