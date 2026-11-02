import 'block_shape.dart';

/// Colour indices (resolved to real colours in the theme).
abstract final class ShapeColor {
  static const red = 0;
  static const orange = 1;
  static const yellow = 2;
  static const green = 3;
  static const teal = 4;
  static const blue = 5;
  static const purple = 6;
  static const pink = 7;
  static const count = 8;
}

List<GridPoint> _p(List<List<int>> raw) => [for (final c in raw) GridPoint(c[0], c[1])];

/// The full library of Classic-mode shapes (40 shapes).
abstract final class ShapeLibrary {
  static final List<BlockShape> all = List.unmodifiable(<BlockShape>[
    // Lines
    BlockShape(
      id: 'single',
      name: 'Single',
      cells: _p([
        [0, 0],
      ]),
      colorIndex: ShapeColor.yellow,
      weight: 6,
    ),
    BlockShape(
      id: 'h2',
      name: 'Two Horizontal',
      cells: _p([
        [0, 0],
        [0, 1],
      ]),
      colorIndex: ShapeColor.orange,
      weight: 10,
    ),
    BlockShape(
      id: 'v2',
      name: 'Two Vertical',
      cells: _p([
        [0, 0],
        [1, 0],
      ]),
      colorIndex: ShapeColor.orange,
      weight: 10,
    ),
    BlockShape(
      id: 'h3',
      name: 'Three Horizontal',
      cells: _p([
        [0, 0],
        [0, 1],
        [0, 2],
      ]),
      colorIndex: ShapeColor.teal,
      weight: 10,
    ),
    BlockShape(
      id: 'v3',
      name: 'Three Vertical',
      cells: _p([
        [0, 0],
        [1, 0],
        [2, 0],
      ]),
      colorIndex: ShapeColor.teal,
      weight: 10,
    ),
    BlockShape(
      id: 'h4',
      name: 'Four Horizontal',
      cells: _p([
        [0, 0],
        [0, 1],
        [0, 2],
        [0, 3],
      ]),
      colorIndex: ShapeColor.blue,
      weight: 8,
    ),
    BlockShape(
      id: 'v4',
      name: 'Four Vertical',
      cells: _p([
        [0, 0],
        [1, 0],
        [2, 0],
        [3, 0],
      ]),
      colorIndex: ShapeColor.blue,
      weight: 8,
    ),
    BlockShape(
      id: 'h5',
      name: 'Five Horizontal',
      cells: _p([
        [0, 0],
        [0, 1],
        [0, 2],
        [0, 3],
        [0, 4],
      ]),
      colorIndex: ShapeColor.red,
      weight: 5,
    ),
    BlockShape(
      id: 'v5',
      name: 'Five Vertical',
      cells: _p([
        [0, 0],
        [1, 0],
        [2, 0],
        [3, 0],
        [4, 0],
      ]),
      colorIndex: ShapeColor.red,
      weight: 5,
    ),
    // Squares & rectangles
    BlockShape(
      id: 'sq2',
      name: 'Square 2x2',
      cells: _p([
        [0, 0],
        [0, 1],
        [1, 0],
        [1, 1],
      ]),
      colorIndex: ShapeColor.green,
      weight: 9,
    ),
    BlockShape(
      id: 'sq3',
      name: 'Square 3x3',
      cells: _p([
        [0, 0],
        [0, 1],
        [0, 2],
        [1, 0],
        [1, 1],
        [1, 2],
        [2, 0],
        [2, 1],
        [2, 2],
      ]),
      colorIndex: ShapeColor.purple,
      weight: 3,
    ),
    BlockShape(
      id: 'rect23',
      name: 'Rectangle 2x3',
      cells: _p([
        [0, 0],
        [0, 1],
        [0, 2],
        [1, 0],
        [1, 1],
        [1, 2],
      ]),
      colorIndex: ShapeColor.pink,
      weight: 4,
    ),
    BlockShape(
      id: 'rect32',
      name: 'Rectangle 3x2',
      cells: _p([
        [0, 0],
        [0, 1],
        [1, 0],
        [1, 1],
        [2, 0],
        [2, 1],
      ]),
      colorIndex: ShapeColor.pink,
      weight: 4,
    ),
    // L shapes
    BlockShape(
      id: 'l0',
      name: 'L',
      cells: _p([
        [0, 0],
        [1, 0],
        [2, 0],
        [2, 1],
      ]),
      colorIndex: ShapeColor.orange,
      weight: 6,
    ),
    BlockShape(
      id: 'l90',
      name: 'L (rotated)',
      cells: _p([
        [0, 0],
        [0, 1],
        [0, 2],
        [1, 0],
      ]),
      colorIndex: ShapeColor.orange,
      weight: 6,
    ),
    BlockShape(
      id: 'l180',
      name: 'L (flipped)',
      cells: _p([
        [0, 0],
        [0, 1],
        [1, 1],
        [2, 1],
      ]),
      colorIndex: ShapeColor.orange,
      weight: 6,
    ),
    BlockShape(
      id: 'l270',
      name: 'L (rotated 270)',
      cells: _p([
        [0, 2],
        [1, 0],
        [1, 1],
        [1, 2],
      ]),
      colorIndex: ShapeColor.orange,
      weight: 6,
    ),
    // Reverse L shapes
    BlockShape(
      id: 'j0',
      name: 'Reverse L',
      cells: _p([
        [0, 1],
        [1, 1],
        [2, 1],
        [2, 0],
      ]),
      colorIndex: ShapeColor.blue,
      weight: 6,
    ),
    BlockShape(
      id: 'j90',
      name: 'Reverse L (rotated)',
      cells: _p([
        [0, 0],
        [1, 0],
        [1, 1],
        [1, 2],
      ]),
      colorIndex: ShapeColor.blue,
      weight: 6,
    ),
    BlockShape(
      id: 'j180',
      name: 'Reverse L (flipped)',
      cells: _p([
        [0, 0],
        [0, 1],
        [1, 0],
        [2, 0],
      ]),
      colorIndex: ShapeColor.blue,
      weight: 6,
    ),
    BlockShape(
      id: 'j270',
      name: 'Reverse L (rotated 270)',
      cells: _p([
        [0, 0],
        [0, 1],
        [0, 2],
        [1, 2],
      ]),
      colorIndex: ShapeColor.blue,
      weight: 6,
    ),
    // T shapes
    BlockShape(
      id: 't0',
      name: 'T',
      cells: _p([
        [0, 0],
        [0, 1],
        [0, 2],
        [1, 1],
      ]),
      colorIndex: ShapeColor.purple,
      weight: 6,
    ),
    BlockShape(
      id: 't90',
      name: 'T (right)',
      cells: _p([
        [0, 1],
        [1, 0],
        [1, 1],
        [2, 1],
      ]),
      colorIndex: ShapeColor.purple,
      weight: 6,
    ),
    BlockShape(
      id: 't180',
      name: 'T (up)',
      cells: _p([
        [0, 1],
        [1, 0],
        [1, 1],
        [1, 2],
      ]),
      colorIndex: ShapeColor.purple,
      weight: 6,
    ),
    BlockShape(
      id: 't270',
      name: 'T (left)',
      cells: _p([
        [0, 0],
        [1, 0],
        [1, 1],
        [2, 0],
      ]),
      colorIndex: ShapeColor.purple,
      weight: 6,
    ),
    // Small corners
    BlockShape(
      id: 'c0',
      name: 'Corner',
      cells: _p([
        [0, 0],
        [0, 1],
        [1, 0],
      ]),
      colorIndex: ShapeColor.green,
      weight: 8,
    ),
    BlockShape(
      id: 'c90',
      name: 'Corner (right)',
      cells: _p([
        [0, 0],
        [0, 1],
        [1, 1],
      ]),
      colorIndex: ShapeColor.green,
      weight: 8,
    ),
    BlockShape(
      id: 'c180',
      name: 'Corner (bottom)',
      cells: _p([
        [0, 1],
        [1, 0],
        [1, 1],
      ]),
      colorIndex: ShapeColor.green,
      weight: 8,
    ),
    BlockShape(
      id: 'c270',
      name: 'Corner (left)',
      cells: _p([
        [0, 0],
        [1, 0],
        [1, 1],
      ]),
      colorIndex: ShapeColor.green,
      weight: 8,
    ),
    // Big corners
    BlockShape(
      id: 'bc0',
      name: 'Big Corner',
      cells: _p([
        [0, 0],
        [0, 1],
        [0, 2],
        [1, 0],
        [2, 0],
      ]),
      colorIndex: ShapeColor.teal,
      weight: 4,
    ),
    BlockShape(
      id: 'bc90',
      name: 'Big Corner (right)',
      cells: _p([
        [0, 0],
        [0, 1],
        [0, 2],
        [1, 2],
        [2, 2],
      ]),
      colorIndex: ShapeColor.teal,
      weight: 4,
    ),
    BlockShape(
      id: 'bc180',
      name: 'Big Corner (bottom)',
      cells: _p([
        [0, 2],
        [1, 2],
        [2, 0],
        [2, 1],
        [2, 2],
      ]),
      colorIndex: ShapeColor.teal,
      weight: 4,
    ),
    BlockShape(
      id: 'bc270',
      name: 'Big Corner (left)',
      cells: _p([
        [0, 0],
        [1, 0],
        [2, 0],
        [2, 1],
        [2, 2],
      ]),
      colorIndex: ShapeColor.teal,
      weight: 4,
    ),
    // Zigzags (S) and Z
    BlockShape(
      id: 's_h',
      name: 'Zigzag',
      cells: _p([
        [0, 1],
        [0, 2],
        [1, 0],
        [1, 1],
      ]),
      colorIndex: ShapeColor.pink,
      weight: 5,
    ),
    BlockShape(
      id: 's_v',
      name: 'Zigzag (vertical)',
      cells: _p([
        [0, 0],
        [1, 0],
        [1, 1],
        [2, 1],
      ]),
      colorIndex: ShapeColor.pink,
      weight: 5,
    ),
    BlockShape(
      id: 'z_h',
      name: 'Z',
      cells: _p([
        [0, 0],
        [0, 1],
        [1, 1],
        [1, 2],
      ]),
      colorIndex: ShapeColor.red,
      weight: 5,
    ),
    BlockShape(
      id: 'z_v',
      name: 'Z (vertical)',
      cells: _p([
        [0, 1],
        [1, 0],
        [1, 1],
        [2, 0],
      ]),
      colorIndex: ShapeColor.red,
      weight: 5,
    ),
    // Plus & small crosses (diagonal pairs)
    BlockShape(
      id: 'plus',
      name: 'Plus',
      cells: _p([
        [0, 1],
        [1, 0],
        [1, 1],
        [1, 2],
        [2, 1],
      ]),
      colorIndex: ShapeColor.yellow,
      weight: 3,
    ),
    BlockShape(
      id: 'x_d',
      name: 'Small Cross',
      cells: _p([
        [0, 0],
        [1, 1],
      ]),
      colorIndex: ShapeColor.yellow,
      weight: 4,
    ),
    BlockShape(
      id: 'x_a',
      name: 'Small Cross (mirrored)',
      cells: _p([
        [0, 1],
        [1, 0],
      ]),
      colorIndex: ShapeColor.yellow,
      weight: 4,
    ),
  ]);

  static final Map<String, BlockShape> byId = {for (final s in all) s.id: s};

  static BlockShape get(String id) {
    final shape = byId[id];
    if (shape == null) throw ArgumentError('Unknown shape id: $id');
    return shape;
  }
}
