/// Static world definitions (pure Dart; colours are resolved in the UI).
library;

enum Mechanic { colors, long, stones, ice, stars, group, locks, bomb, exit }

class WorldInfo {
  const WorldInfo({
    required this.id,
    required this.name,
    required this.tagline,
    required this.mechanics,
    required this.themeKey,
  });

  final int id;
  final String name;
  final String tagline;
  final Set<Mechanic> mechanics;

  /// Used by the UI to pick colours/illustrations.
  final String themeKey;

  String get assetPath => 'assets/levels/world_$id.json';
}

abstract final class WorldCatalog {
  static const levelsPerWorld = 100;

  static const _base = {Mechanic.colors, Mechanic.long, Mechanic.stones};

  static final worlds = <WorldInfo>[
    const WorldInfo(
      id: 1,
      name: 'Candy Valley',
      tagline: 'Slide sweets onto matching pads',
      mechanics: _base,
      themeKey: 'candy',
    ),
    WorldInfo(
      id: 2,
      name: 'Forest Adventure',
      tagline: 'Crack the ice blocks',
      mechanics: {..._base, Mechanic.ice},
      themeKey: 'forest',
    ),
    WorldInfo(
      id: 3,
      name: 'Ocean World',
      tagline: 'Collect stars and match groups',
      mechanics: {..._base, Mechanic.stars, Mechanic.group},
      themeKey: 'ocean',
    ),
    WorldInfo(
      id: 4,
      name: 'Desert Kingdom',
      tagline: 'Unlock the locked blocks',
      mechanics: {..._base, Mechanic.locks, Mechanic.ice},
      themeKey: 'desert',
    ),
    WorldInfo(
      id: 5,
      name: 'Snow Wonderland',
      tagline: 'Blast through with bombs',
      mechanics: {..._base, Mechanic.bomb, Mechanic.ice, Mechanic.stars},
      themeKey: 'snow',
    ),
    WorldInfo(
      id: 6,
      name: 'Space Adventure',
      tagline: 'Guide the key to the exit',
      mechanics: {..._base, Mechanic.exit, Mechanic.bomb, Mechanic.locks, Mechanic.group},
      themeKey: 'space',
    ),
  ];

  static WorldInfo byId(int id) => worlds.firstWhere((w) => w.id == id);
}
