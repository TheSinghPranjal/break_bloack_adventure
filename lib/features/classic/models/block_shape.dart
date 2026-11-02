/// Pure-Dart models for the Classic (block placement) mode.
/// No Flutter imports here: the engine must be testable and UI-independent.
library;

class GridPoint {
  const GridPoint(this.row, this.col);

  final int row;
  final int col;

  GridPoint operator +(GridPoint other) => GridPoint(row + other.row, col + other.col);

  @override
  bool operator ==(Object other) => other is GridPoint && other.row == row && other.col == col;

  @override
  int get hashCode => row * 1000 + col;

  @override
  String toString() => '($row,$col)';

  List<int> toJson() => [row, col];
  factory GridPoint.fromJson(List<dynamic> json) => GridPoint(json[0] as int, json[1] as int);
}

/// A placeable shape defined by relative grid coordinates (row, col).
class BlockShape {
  const BlockShape({
    required this.id,
    required this.name,
    required this.cells,
    required this.colorIndex,
    this.weight = 10,
  });

  final String id;
  final String name;
  final List<GridPoint> cells;

  /// Index into the block colour palette (resolved by the UI layer).
  final int colorIndex;

  /// Relative frequency used by the shape generator.
  final int weight;

  int get height => cells.fold(0, (m, c) => c.row + 1 > m ? c.row + 1 : m);
  int get width => cells.fold(0, (m, c) => c.col + 1 > m ? c.col + 1 : m);
  int get size => cells.length;

  Map<String, dynamic> toJson() => {'id': id};

  @override
  String toString() => 'BlockShape($id)';
}
