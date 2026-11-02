import 'block_shape.dart';
import 'shape_library.dart';

/// Cell value meanings on a [ClassicBoard].
abstract final class CellValue {
  static const empty = 0;

  /// Rainbow "wild" cell placed by the Rainbow booster.
  static const wild = -1;

  /// Converts a palette colour index to a stored cell value.
  static int fromColor(int colorIndex) => colorIndex + 1;

  /// Converts a stored value back into a palette colour index (or -1 for wild).
  static int toColor(int value) => value == wild ? -1 : value - 1;
}

/// Immutable square board.
class ClassicBoard {
  ClassicBoard._(this.size, List<int> cells) : cells = List.unmodifiable(cells);

  factory ClassicBoard.empty(int size) => ClassicBoard._(size, List.filled(size * size, CellValue.empty));

  factory ClassicBoard.fromRows(List<String> rows) {
    // Test helper: '#' = filled (colour 0), '.' = empty.
    final size = rows.length;
    final cells = <int>[];
    for (final row in rows) {
      assert(row.length == size);
      for (final ch in row.split('')) {
        cells.add(ch == '.' ? CellValue.empty : CellValue.fromColor(0));
      }
    }
    return ClassicBoard._(size, cells);
  }

  final int size;
  final List<int> cells;

  int at(int row, int col) => cells[row * size + col];
  bool inBounds(int row, int col) => row >= 0 && col >= 0 && row < size && col < size;
  bool isEmpty(int row, int col) => at(row, col) == CellValue.empty;

  int get filledCount => cells.where((c) => c != CellValue.empty).length;

  ClassicBoard withCells(Map<GridPoint, int> updates) {
    final next = List<int>.of(cells);
    updates.forEach((p, v) => next[p.row * size + p.col] = v);
    return ClassicBoard._(size, next);
  }

  Map<String, dynamic> toJson() => {'size': size, 'cells': cells};
  factory ClassicBoard.fromJson(Map<String, dynamic> json) =>
      ClassicBoard._(json['size'] as int, (json['cells'] as List).cast<int>());
}

/// Snapshot of a Classic game. Immutable.
class ClassicGameState {
  const ClassicGameState({
    required this.board,
    required this.tray,
    this.score = 0,
    this.combo = 0,
    this.maxCombo = 0,
    this.linesCleared = 0,
    this.shapesPlaced = 0,
    this.multiLineClears = 0,
    this.isGameOver = false,
    this.undoStack = const [],
  });

  final ClassicBoard board;

  /// Always three slots; `null` means the slot has been used this round.
  final List<BlockShape?> tray;
  final int score;

  /// Consecutive placements that cleared at least one line.
  final int combo;
  final int maxCombo;
  final int linesCleared;
  final int shapesPlaced;

  /// Number of placements that cleared two or more lines at once.
  final int multiLineClears;
  final bool isGameOver;

  /// Previous states (most recent last). Snapshots carry no nested stacks.
  final List<ClassicGameState> undoStack;

  List<BlockShape> get remainingShapes => [for (final s in tray) ?s];
  bool get canUndo => undoStack.isNotEmpty;

  ClassicGameState copyWith({
    ClassicBoard? board,
    List<BlockShape?>? tray,
    int? score,
    int? combo,
    int? maxCombo,
    int? linesCleared,
    int? shapesPlaced,
    int? multiLineClears,
    bool? isGameOver,
    List<ClassicGameState>? undoStack,
  }) {
    return ClassicGameState(
      board: board ?? this.board,
      tray: tray ?? this.tray,
      score: score ?? this.score,
      combo: combo ?? this.combo,
      maxCombo: maxCombo ?? this.maxCombo,
      linesCleared: linesCleared ?? this.linesCleared,
      shapesPlaced: shapesPlaced ?? this.shapesPlaced,
      multiLineClears: multiLineClears ?? this.multiLineClears,
      isGameOver: isGameOver ?? this.isGameOver,
      undoStack: undoStack ?? this.undoStack,
    );
  }

  /// A copy without undo history, used when pushing onto the stack.
  ClassicGameState get snapshot => copyWith(undoStack: const []);

  Map<String, dynamic> toJson() => {
    'board': board.toJson(),
    'tray': [for (final s in tray) s?.id],
    'score': score,
    'combo': combo,
    'maxCombo': maxCombo,
    'linesCleared': linesCleared,
    'shapesPlaced': shapesPlaced,
    'multiLineClears': multiLineClears,
    'isGameOver': isGameOver,
  };

  factory ClassicGameState.fromJson(Map<String, dynamic> json) => ClassicGameState(
    board: ClassicBoard.fromJson(json['board'] as Map<String, dynamic>),
    tray: [for (final id in json['tray'] as List) id == null ? null : ShapeLibrary.get(id as String)],
    score: json['score'] as int,
    combo: json['combo'] as int,
    maxCombo: json['maxCombo'] as int,
    linesCleared: json['linesCleared'] as int,
    shapesPlaced: json['shapesPlaced'] as int,
    multiLineClears: (json['multiLineClears'] as int?) ?? 0,
    isGameOver: json['isGameOver'] as bool,
  );
}

/// Outcome of a single placement, consumed by the UI for animations.
class PlacementResult {
  const PlacementResult({
    required this.state,
    required this.placedCells,
    required this.clearedRows,
    required this.clearedColumns,
    required this.clearedCells,
    required this.pointsGained,
    required this.trayRefilled,
  });

  final ClassicGameState state;
  final Set<GridPoint> placedCells;
  final List<int> clearedRows;
  final List<int> clearedColumns;
  final Set<GridPoint> clearedCells;
  final int pointsGained;
  final bool trayRefilled;

  int get linesCleared => clearedRows.length + clearedColumns.length;
}

/// All scoring values are configurable.
class ClassicScoringConfig {
  const ClassicScoringConfig({
    this.pointsPerCell = 1,
    this.lineBonuses = const [0, 10, 30, 60, 100],
    this.extraLineBonus = 50,
    this.comboBonusPerStep = 10,
  });

  final int pointsPerCell;

  /// Bonus indexed by number of simultaneously cleared lines.
  final List<int> lineBonuses;

  /// For more lines than [lineBonuses] covers: last bonus + extra per line.
  final int extraLineBonus;

  /// Bonus = comboBonusPerStep * (combo - 1) when combo >= 2.
  final int comboBonusPerStep;

  int lineBonus(int lines) {
    if (lines <= 0) return 0;
    if (lines < lineBonuses.length) return lineBonuses[lines];
    final over = lines - (lineBonuses.length - 1);
    return lineBonuses.last + over * extraLineBonus;
  }

  int comboBonus(int combo) => combo >= 2 ? comboBonusPerStep * (combo - 1) : 0;
}
