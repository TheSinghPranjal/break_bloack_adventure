import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../shared/components/block_paint.dart';
import '../models/block_shape.dart';
import '../models/classic_state.dart';

/// Ghost preview while dragging.
class GhostPreview {
  const GhostPreview(this.shape, this.origin, this.valid);
  final BlockShape shape;
  final GridPoint origin;
  final bool valid;
}

/// Efficient board rendering: one CustomPainter for cells, ghost, line
/// highlights and the clear animation (single AnimationController).
class ClassicBoardView extends StatefulWidget {
  const ClassicBoardView({
    super.key,
    required this.board,
    required this.ghost,
    required this.clearedColors,
    required this.fxTick,
    required this.selection,
    this.onTapCell,
  });

  final ClassicBoard board;
  final ValueNotifier<GhostPreview?> ghost;
  final Map<GridPoint, int> clearedColors;
  final int fxTick;
  final List<GridPoint> selection;
  final void Function(GridPoint)? onTapCell;

  @override
  State<ClassicBoardView> createState() => _ClassicBoardViewState();
}

class _ClassicBoardViewState extends State<ClassicBoardView> with SingleTickerProviderStateMixin {
  late final AnimationController _fx = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));

  @override
  void didUpdateWidget(covariant ClassicBoardView old) {
    super.didUpdateWidget(old);
    if (widget.fxTick != old.fxTick && widget.clearedColors.isNotEmpty) {
      _fx.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _fx.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final side = c.biggest.shortestSide;
        return GestureDetector(
          onTapUp: widget.onTapCell == null
              ? null
              : (d) {
                  final cell = side / widget.board.size;
                  final p = GridPoint((d.localPosition.dy / cell).floor(), (d.localPosition.dx / cell).floor());
                  if (widget.board.inBounds(p.row, p.col)) widget.onTapCell!(p);
                },
          child: RepaintBoundary(
            child: CustomPaint(
              size: Size.square(side),
              painter: _BoardPainter(
                board: widget.board,
                ghost: widget.ghost,
                fx: _fx,
                cleared: widget.clearedColors,
                selection: widget.selection,
                tick: widget.fxTick,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BoardPainter extends CustomPainter {
  _BoardPainter({
    required this.board,
    required this.ghost,
    required this.fx,
    required this.cleared,
    required this.selection,
    required this.tick,
  }) : super(repaint: Listenable.merge([ghost, fx]));

  final ClassicBoard board;
  final ValueNotifier<GhostPreview?> ghost;
  final AnimationController fx;
  final Map<GridPoint, int> cleared;
  final List<GridPoint> selection;
  final int tick;

  @override
  void paint(Canvas canvas, Size size) {
    final n = board.size;
    final cell = size.width / n;
    final pad = cell * 0.06;
    final bg = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(cell * 0.4));
    canvas.drawRRect(bg, Paint()..color = AppColors.boardBg);

    Rect cellRect(int r, int c) => Rect.fromLTWH(c * cell + pad, r * cell + pad, cell - pad * 2, cell - pad * 2);
    final empty = Paint()..color = AppColors.boardCell;

    // Lines that the ghost would complete -> highlight.
    final g = ghost.value;
    Set<GridPoint> ghostCells = {};
    final highlightRows = <int>{}, highlightCols = <int>{};
    if (g != null) {
      ghostCells = {for (final c in g.shape.cells) g.origin + c};
      if (g.valid) {
        for (var r = 0; r < n; r++) {
          if (List.generate(n, (c) => !board.isEmpty(r, c) || ghostCells.contains(GridPoint(r, c))).every((x) => x)) {
            highlightRows.add(r);
          }
        }
        for (var c = 0; c < n; c++) {
          if (List.generate(n, (r) => !board.isEmpty(r, c) || ghostCells.contains(GridPoint(r, c))).every((x) => x)) {
            highlightCols.add(c);
          }
        }
      }
    }

    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        final rect = cellRect(r, c);
        final v = board.at(r, c);
        if (v == CellValue.empty) {
          canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.18)), empty);
        } else {
          final glow = highlightRows.contains(r) || highlightCols.contains(c);
          if (v == CellValue.wild) {
            paintWildBlock(canvas, rect);
          } else {
            final color = glow && g != null
                ? AppColors.blockColor(g.shape.colorIndex)
                : AppColors.blockColor(CellValue.toColor(v));
            paintCandyBlock(canvas, rect, color);
          }
        }
      }
    }

    // Ghost preview.
    if (g != null) {
      for (final p in ghostCells) {
        if (!board.inBounds(p.row, p.col)) continue;
        final rect = cellRect(p.row, p.col);
        if (g.valid) {
          paintCandyBlock(canvas, rect, AppColors.blockColor(g.shape.colorIndex), opacity: 0.55);
        } else {
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.18)),
            Paint()..color = AppColors.danger.withValues(alpha: 0.55),
          );
        }
      }
    }

    // Selected cells (Remove booster).
    for (final p in selection) {
      final rect = cellRect(p.row, p.col).inflate(pad * 0.5);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.2)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Colors.white,
      );
    }

    // Clear animation: blocks pop, flash white and scatter particles.
    final t = fx.value;
    if (fx.isAnimating && cleared.isNotEmpty) {
      final rnd = math.Random(tick);
      for (final e in cleared.entries) {
        final rect = cellRect(e.key.row, e.key.col);
        final scale = 1 - Curves.easeInBack.transform(t.clamp(0, 1));
        final rr = Rect.fromCenter(
          center: rect.center,
          width: rect.width * scale.clamp(0, 1.2),
          height: rect.height * scale.clamp(0, 1.2),
        );
        if (rr.width > 0.5) {
          paintCandyBlock(canvas, rr, e.value < 0 ? Colors.white : AppColors.blockColor(e.value));
          canvas.drawRRect(
            RRect.fromRectAndRadius(rr, Radius.circular(cell * 0.18)),
            Paint()..color = Colors.white.withValues(alpha: (1 - t) * 0.6),
          );
        }
        final paint = Paint()
          ..color = (e.value < 0 ? Colors.white : AppColors.blockColor(e.value)).withValues(alpha: (1 - t).clamp(0, 1));
        for (var k = 0; k < 2; k++) {
          final a = rnd.nextDouble() * math.pi * 2;
          final d = cell * (0.6 + rnd.nextDouble()) * Curves.easeOut.transform(t);
          final o = rect.center + Offset(math.cos(a) * d, math.sin(a) * d - cell * 0.4 * t);
          canvas.drawRect(Rect.fromCenter(center: o, width: cell * 0.18, height: cell * 0.18), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) =>
      old.board != board || old.tick != tick || old.selection != selection;
}

/// Draws a shape (tray item and drag feedback).
class ShapeView extends StatelessWidget {
  const ShapeView({super.key, required this.shape, required this.cell, this.opacity = 1});
  final BlockShape shape;
  final double cell;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(shape.width * cell, shape.height * cell), painter: _ShapePainter(shape, opacity));
  }
}

class _ShapePainter extends CustomPainter {
  _ShapePainter(this.shape, this.opacity);
  final BlockShape shape;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / shape.width;
    final pad = cell * 0.06;
    for (final c in shape.cells) {
      paintCandyBlock(
        canvas,
        Rect.fromLTWH(c.col * cell + pad, c.row * cell + pad, cell - pad * 2, cell - pad * 2),
        AppColors.blockColor(shape.colorIndex),
        opacity: opacity,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ShapePainter old) => old.shape != shape || old.opacity != opacity;
}
