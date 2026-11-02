enum BoosterMode { classic, adventure }

class BoosterDef {
  const BoosterDef({
    required this.id,
    required this.name,
    required this.description,
    required this.mode,
    required this.price,
  });

  final String id;
  final String name;
  final String description;
  final BoosterMode mode;

  /// Coin price, both to buy one in the shop and to use one in-game
  /// without owning it.
  final int price;
}

abstract final class Boosters {
  static const undo = BoosterDef(
    id: 'undo',
    name: 'Undo',
    description: 'Revert your last placement, including cleared lines.',
    mode: BoosterMode.classic,
    price: 200,
  );
  static const hammer = BoosterDef(
    id: 'hammer',
    name: 'Hammer',
    description: 'Smash one occupied cell.',
    mode: BoosterMode.classic,
    price: 300,
  );
  static const remove = BoosterDef(
    id: 'remove',
    name: 'Remove',
    description: 'Clear up to 3 occupied cells of your choice.',
    mode: BoosterMode.classic,
    price: 450,
  );
  static const shuffle = BoosterDef(
    id: 'shuffle',
    name: 'Shuffle',
    description: 'Swap your tray for a fresh set of shapes.',
    mode: BoosterMode.classic,
    price: 200,
  );
  static const rainbow = BoosterDef(
    id: 'rainbow',
    name: 'Rainbow',
    description: 'Fill any empty cell with a wild block.',
    mode: BoosterMode.classic,
    price: 400,
  );
  static const extraSpace = BoosterDef(
    id: 'extra_space',
    name: 'Extra Space',
    description: 'Rescue: clears the most crowded row.',
    mode: BoosterMode.classic,
    price: 500,
  );
  static const advUndo = BoosterDef(
    id: 'adv_undo',
    name: 'Extra Undo',
    description: 'Undo after your 3 free undos are used.',
    mode: BoosterMode.adventure,
    price: 120,
  );
  static const advHint = BoosterDef(
    id: 'adv_hint',
    name: 'Extra Hint',
    description: 'Reveal the next move of a solution.',
    mode: BoosterMode.adventure,
    price: 250,
  );

  static const all = [undo, hammer, remove, shuffle, rainbow, extraSpace, advUndo, advHint];
  static const classic = [undo, hammer, remove, shuffle, rainbow, extraSpace];
  static BoosterDef byId(String id) => all.firstWhere((b) => b.id == id);
}
