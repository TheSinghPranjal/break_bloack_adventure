// Generates validated Adventure levels into assets/levels/world_<n>.json.
//
//   dart run tool/generate_levels.dart [worldId ...] [--count=100]
//
// Every emitted level has been solved by the BFS solver within its move
// limit, so no impossible configuration can be written.
import 'dart:convert';
import 'dart:io';

import 'package:break_block_adventure/features/adventure/levels/level_generator.dart';
import 'package:break_block_adventure/features/adventure/levels/world_catalog.dart';

void main(List<String> args) {
  var count = WorldCatalog.levelsPerWorld;
  final worlds = <int>[];
  for (final a in args) {
    if (a.startsWith('--count=')) {
      count = int.parse(a.substring(8));
    } else {
      worlds.add(int.parse(a));
    }
  }
  if (worlds.isEmpty) worlds.addAll(WorldCatalog.worlds.map((w) => w.id));

  Directory('assets/levels').createSync(recursive: true);
  for (final w in worlds) {
    final sw = Stopwatch()..start();
    final gen = LevelGenerator(seed: 1000 * w + 7);
    final levels = <Map<String, dynamic>>[];
    for (var i = 1; i <= count; i++) {
      levels.add(gen.generate(w, i).toJson());
      stderr.write('\rWorld $w: level $i/$count');
    }
    stderr.writeln();
    File('assets/levels/world_$w.json').writeAsStringSync(const JsonEncoder.withIndent(' ').convert(levels));
    stdout.writeln('World $w: ${levels.length} levels in ${sw.elapsed.inSeconds}s');
  }
}
