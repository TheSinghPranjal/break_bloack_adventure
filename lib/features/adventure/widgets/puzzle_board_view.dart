import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../shared/components/block_paint.dart';
import '../controllers/adventure_controller.dart';
import '../models/puzzle_models.dart';

typedef MaxDistanceFn = int Function(String blockId, Direction d);
typedef MoveFn = bool Function(PuzzleMove move);

class PuzzleBoardView extends StatefulWidget {
  const PuzzleBoardView({
    super.key,
    required this.session,
    required this.boardColor,
    required this.maxDistance,
    required this.onMove,
  });

  final AdventureSession session;
  final Color boardColor;
  final MaxDistanceFn maxDistance;
  final MoveFn onMove;

  @override
  State<PuzzleBoardView> createState() => _PuzzleBoardViewState();
}

class _PuzzleBoardViewState extends State<PuzzleBoardView> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant PuzzleBoardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
  }

  void _syncPulse() {
    if (widget.session.hint != null) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final level = widget.session.level;
    final st = widget.session.state;
    return LayoutBuilder(
      builder: (context, c) {
        final cell = math.min((c.maxWidth - 16) / level.columns, (c.maxHeight - 16) / level.rows);
        final w = cell * level.columns, h = cell * level.rows;
        final out = widget.session.lastOutcome;
        final hint = widget.session.hint;
        final hintBlock = hint == null ? null : st.blockById(hint.blockId);
        return Center(
          child: Container(
            width: w + 16,
            height: h + 16,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.boardColor,
              borderRadius: BorderRadius.circular(cell * 0.45),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 20, offset: const Offset(0, 10)),
              ],
            ),
            child: SizedBox(
              width: w,
              height: h,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _GridPainter(level: level, state: st, cell: cell),
                      ),
                    ),
                  ),
                  for (final b in st.blocks)
                    _BlockWidget(
                      key: ValueKey(b.id),
                      block: b,
                      cell: cell,
                      locked: b.isLocked(st.totalCleared),
                      locksRemaining: b.lockClears - st.totalCleared,
                      enabled: st.status == PuzzleStatus.playing,
                      maxDistance: widget.maxDistance,
                      onMove: widget.onMove,
                    ),
                  if (out != null) ...[
                    for (final b in out.cleared)
                      _Vanish(key: ValueKey('v${b.id}@${widget.session.tick}'), block: b, cell: cell),
                    if (out.exited != null)
                      _Vanish(
                        key: ValueKey('x${out.exited!.id}@${widget.session.tick}'),
                        block: out.exited!,
                        cell: cell,
                        flyUp: true,
                      ),
                    for (final e in out.explosions)
                      _Blast(key: ValueKey('b$e@${widget.session.tick}'), center: e, cell: cell),
                    for (final s in out.starsCollected)
                      _StarPop(key: ValueKey('s$s@${widget.session.tick}'), at: s, cell: cell),
                  ],
                  // Pad outlines drawn above blocks so pads under blockers stay visible.
                  Positioned.fill(
                    child: IgnorePointer(child: CustomPaint(painter: _PadOutlinePainter(st.targets, cell))),
                  ),
                  if (hint != null && hintBlock != null)
                    _HintOverlay(block: hintBlock, dir: hint.direction, cell: cell, pulse: _pulse),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({required this.level, required this.state, required this.cell});
  final PuzzleLevel level;
  final PuzzleState state;
  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    final pad = cell * 0.05;
    final tile = Paint()..color = Colors.white.withValues(alpha: 0.10);
    for (var r = 0; r < level.rows; r++) {
      for (var c = 0; c < level.columns; c++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(c * cell + pad, r * cell + pad, cell - 2 * pad, cell - 2 * pad),
            Radius.circular(cell * 0.2),
          ),
          tile,
        );
      }
    }
    // Target pads: tinted fill + dashed-look ring.
    for (final e in state.targets.entries) {
      final rect = Rect.fromLTWH(e.key.col * cell + pad, e.key.row * cell + pad, cell - 2 * pad, cell - 2 * pad);
      final color = AppColors.named_(e.value);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.2)),
        Paint()..color = color.withValues(alpha: 0.28),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(cell * 0.08), Radius.circular(cell * 0.16)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.06
          ..color = color,
      );
      canvas.drawCircle(rect.center, cell * 0.1, Paint()..color = color);
    }
    for (final s in state.stars) {
      final rect = Rect.fromCenter(
        center: Offset((s.col + 0.5) * cell, (s.row + 0.5) * cell),
        width: cell * 0.6,
        height: cell * 0.6,
      );
      canvas.drawPath(starPath(rect), Paint()..color = AppColors.star);
      canvas.drawPath(starPath(rect.deflate(cell * 0.1)), Paint()..color = const Color(0xFFFFE27A));
    }
    for (final e in level.exits) {
      final rect = Rect.fromLTWH(e.col * cell + pad, e.row * cell + pad, cell - 2 * pad, cell - 2 * pad);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.2)),
        Paint()..shader = const RadialGradient(colors: [Color(0xFFFFF3B0), Color(0xFFFFB800)]).createShader(rect),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(Icons.flag_rounded.codePoint),
          style: TextStyle(
            fontFamily: Icons.flag_rounded.fontFamily,
            package: Icons.flag_rounded.fontPackage,
            fontSize: cell * 0.55,
            color: const Color(0xFF7A5226),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, rect.center - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) => old.state != state || old.cell != cell;
}

/// Paints a single puzzle block according to its kind.
class _BlockPainter extends CustomPainter {
  _BlockPainter(this.block, this.locked, this.cell);
  final PuzzleBlock block;
  final bool locked;
  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    final pad = cell * 0.06;
    final rect = Rect.fromLTWH(pad, pad, size.width - 2 * pad, size.height - 2 * pad);
    final rf = (cell * 0.22) / rect.shortestSide;
    switch (block.kind) {
      case BlockKind.stone:
        paintCandyBlock(canvas, rect, AppColors.stone, radiusFactor: rf);
        final p = Paint()
          ..color = Colors.black.withValues(alpha: 0.18)
          ..strokeWidth = cell * 0.04
          ..style = PaintingStyle.stroke;
        canvas.drawLine(rect.topLeft + Offset(rect.width * 0.3, rect.height * 0.25), rect.center, p);
        canvas.drawLine(rect.center, rect.bottomRight - Offset(rect.width * 0.25, rect.height * 0.3), p);
      case BlockKind.ice:
        final rr = RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.2));
        canvas.drawRRect(rr, Paint()..color = AppColors.ice.withValues(alpha: 0.9));
        canvas.drawRRect(rr.deflate(cell * 0.08), Paint()..color = Colors.white.withValues(alpha: 0.5));
        canvas.drawLine(
          rect.topLeft + Offset(cell * 0.2, cell * 0.55),
          rect.topLeft + Offset(cell * 0.55, cell * 0.2),
          Paint()
            ..color = Colors.white
            ..strokeWidth = cell * 0.06
            ..strokeCap = StrokeCap.round,
        );
        if (block.hp > 1) _label(canvas, rect, '${block.hp}', const Color(0xFF2A6FA8));
      case BlockKind.key:
        paintCandyBlock(canvas, rect, const Color(0xFFFFC233), radiusFactor: rf);
        _icon(canvas, rect, Icons.vpn_key_rounded, const Color(0xFF7A5226));
      case BlockKind.bomb:
        paintCandyBlock(canvas, rect, AppColors.named_(block.color), radiusFactor: rf);
        canvas.drawCircle(rect.center, cell * 0.24, Paint()..color = const Color(0xFF2A2150));
        canvas.drawCircle(
          rect.center + Offset(-cell * 0.07, -cell * 0.07),
          cell * 0.06,
          Paint()..color = Colors.white54,
        );
      case BlockKind.normal:
        if (block.color == null) {
          paintCandyBlock(canvas, rect, AppColors.crate, radiusFactor: rf);
          final p = Paint()
            ..color = Colors.black.withValues(alpha: 0.15)
            ..strokeWidth = cell * 0.05;
          canvas.drawLine(
            rect.topLeft + Offset(cell * 0.2, cell * 0.2),
            rect.bottomRight - Offset(cell * 0.2, cell * 0.25),
            p,
          );
          canvas.drawLine(
            rect.topRight + Offset(-cell * 0.2, cell * 0.2),
            rect.bottomLeft + Offset(cell * 0.2, -cell * 0.25),
            p,
          );
        } else {
          paintCandyBlock(canvas, rect, AppColors.named_(block.color), radiusFactor: rf);
        }
    }
    // Axis hint arrows for movable blocks constrained to one axis.
    if (block.isMovableKind && block.axis != MoveAxis.both && block.kind != BlockKind.key) {
      _icon(
        canvas,
        rect,
        block.axis == MoveAxis.horizontal ? Icons.swap_horiz_rounded : Icons.swap_vert_rounded,
        Colors.white.withValues(alpha: 0.85),
        scale: 0.5,
      );
    }
    if (locked) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.2)),
        Paint()..color = Colors.black.withValues(alpha: 0.35),
      );
      _icon(canvas, rect, Icons.lock_rounded, Colors.white);
    }
  }

  void _icon(Canvas canvas, Rect rect, IconData icon, Color color, {double scale = 0.55}) {
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(fontFamily: icon.fontFamily, package: icon.fontPackage, fontSize: cell * scale, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, rect.center - Offset(tp.width / 2, tp.height / 2));
  }

  void _label(Canvas canvas, Rect rect, String text, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: cell * 0.4, fontWeight: FontWeight.w900, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, rect.center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _BlockPainter old) =>
      old.block.hp != block.hp || old.locked != locked || old.cell != cell || old.block.kind != block.kind;
}

class _BlockWidget extends StatefulWidget {
  const _BlockWidget({
    super.key,
    required this.block,
    required this.cell,
    required this.locked,
    required this.locksRemaining,
    required this.enabled,
    required this.maxDistance,
    required this.onMove,
  });
  final PuzzleBlock block;
  final double cell;
  final bool locked;
  final int locksRemaining;
  final bool enabled;
  final MaxDistanceFn maxDistance;
  final MoveFn onMove;

  @override
  State<_BlockWidget> createState() => _BlockWidgetState();
}

class _BlockWidgetState extends State<_BlockWidget> {
  Offset _drag = Offset.zero; // clamped, displayed offset
  Offset _raw = Offset.zero; // accumulated finger movement
  bool _dragging = false;
  bool? _horizontal; // locked drag axis
  Map<Direction, int> _max = const {};

  bool get _movable => widget.enabled && widget.block.isMovableKind && !widget.locked;

  void _start(DragStartDetails _) {
    if (!_movable) return;
    _max = {for (final d in Direction.values) d: widget.maxDistance(widget.block.id, d)};
    _horizontal = switch (widget.block.axis) {
      MoveAxis.horizontal => true,
      MoveAxis.vertical => false,
      MoveAxis.both => null,
    };
    setState(() {
      _dragging = true;
      _drag = Offset.zero;
      _raw = Offset.zero;
    });
  }

  void _update(DragUpdateDetails d) {
    if (!_dragging) return;
    _raw += d.delta;
    if (_horizontal == null && _raw.distance > 8) _horizontal = _raw.dx.abs() >= _raw.dy.abs();
    final cell = widget.cell;
    final Offset next;
    if (_horizontal == true) {
      next = Offset(_raw.dx.clamp(-(_max[Direction.left]! * cell), _max[Direction.right]! * cell), 0);
    } else if (_horizontal == false) {
      next = Offset(0, _raw.dy.clamp(-(_max[Direction.up]! * cell), _max[Direction.down]! * cell));
    } else {
      next = Offset.zero;
    }
    setState(() => _drag = next);
  }

  void _end(DragEndDetails d) {
    if (!_dragging) return;
    final horizontal = _horizontal;
    final along = horizontal == true ? _drag.dx : (horizontal == false ? _drag.dy : 0.0);
    final vel = horizontal == true
        ? d.velocity.pixelsPerSecond.dx
        : (horizontal == false ? d.velocity.pixelsPerSecond.dy : 0.0);
    final cells = (along / widget.cell).round();
    PuzzleMove? move;
    Direction dirFor(double sign) =>
        horizontal == true ? (sign > 0 ? Direction.right : Direction.left) : (sign > 0 ? Direction.down : Direction.up);
    if (horizontal != null) {
      if (cells != 0) {
        move = PuzzleMove(widget.block.id, dirFor(cells.toDouble()), cells.abs());
      } else if (vel.abs() > 350) {
        // Quick swipe: slide as far as possible.
        final dir = dirFor(vel);
        final dist = _max[dir] ?? 0;
        if (dist > 0) move = PuzzleMove(widget.block.id, dir, dist);
      }
    }
    setState(() {
      _dragging = false;
      _drag = Offset.zero;
    });
    if (move != null) widget.onMove(move);
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.block;
    final cell = widget.cell;
    return AnimatedPositioned(
      duration: _dragging ? Duration.zero : const Duration(milliseconds: 200),
      curve: Curves.easeOutBack,
      left: b.col * cell + _drag.dx,
      top: b.row * cell + _drag.dy,
      width: b.width * cell,
      height: b.height * cell,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: _start,
        onPanUpdate: _update,
        onPanEnd: _end,
        onPanCancel: () => setState(() {
          _dragging = false;
          _drag = Offset.zero;
        }),
        child: AnimatedScale(
          scale: _dragging ? 1.06 : 1,
          duration: const Duration(milliseconds: 120),
          child: CustomPaint(painter: _BlockPainter(b, widget.locked, cell)),
        ),
      ),
    );
  }
}

class _Vanish extends StatelessWidget {
  const _Vanish({super.key, required this.block, required this.cell, this.flyUp = false});
  final PuzzleBlock block;
  final double cell;
  final bool flyUp;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: block.col * cell,
      top: block.row * cell,
      width: block.width * cell,
      height: block.height * cell,
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 420),
          builder: (_, t, child) {
            final s = t < 0.3 ? 1 + t : (1.3 * (1 - (t - 0.3) / 0.7));
            return Opacity(
              opacity: (1 - t).clamp(0, 1),
              child: Transform.translate(
                offset: Offset(0, flyUp ? -cell * 2 * t : 0),
                child: Transform.scale(scale: s.clamp(0, 1.3), child: child),
              ),
            );
          },
          child: CustomPaint(painter: _BlockPainter(block, false, cell)),
        ),
      ),
    );
  }
}

class _Blast extends StatelessWidget {
  const _Blast({super.key, required this.center, required this.cell});
  final Cell center;
  final double cell;
  @override
  Widget build(BuildContext context) {
    final size = cell * 3.6;
    return Positioned(
      left: (center.col + 0.5) * cell - size / 2,
      top: (center.row + 0.5) * cell - size / 2,
      width: size,
      height: size,
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 500),
          builder: (_, t, _) => Opacity(
            opacity: 1 - t,
            child: Transform.scale(
              scale: 0.3 + t * 0.9,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white,
                      AppColors.accent.withValues(alpha: 0.8),
                      AppColors.danger.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StarPop extends StatelessWidget {
  const _StarPop({super.key, required this.at, required this.cell});
  final Cell at;
  final double cell;
  @override
  Widget build(BuildContext context) => Positioned(
    left: at.col * cell,
    top: at.row * cell,
    width: cell,
    height: cell,
    child: IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 600),
        builder: (_, t, _) => Opacity(
          opacity: 1 - t,
          child: Transform.translate(
            offset: Offset(0, -cell * t),
            child: Transform.scale(
              scale: 1 + t,
              child: Icon(Icons.star_rounded, color: AppColors.star, size: cell * 0.7),
            ),
          ),
        ),
      ),
    ),
  );
}

class _HintOverlay extends StatelessWidget {
  const _HintOverlay({required this.block, required this.dir, required this.cell, required this.pulse});
  final PuzzleBlock block;
  final Direction dir;
  final double cell;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    final icon = switch (dir) {
      Direction.up => Icons.arrow_upward_rounded,
      Direction.down => Icons.arrow_downward_rounded,
      Direction.left => Icons.arrow_back_rounded,
      Direction.right => Icons.arrow_forward_rounded,
    };
    return Positioned(
      left: block.col * cell,
      top: block.row * cell,
      width: block.width * cell,
      height: block.height * cell,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: pulse,
          builder: (_, _) {
            final t = pulse.value;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(cell * 0.22),
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.4 + 0.4 * t),
                          blurRadius: 10 + 10 * t,
                        ),
                      ],
                    ),
                  ),
                ),
                Center(
                  child: Transform.translate(
                    offset: Offset(dir.dc * cell * 0.3 * t, dir.dr * cell * 0.3 * t),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: Icon(icon, color: AppColors.primary, size: cell * 0.4),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PadOutlinePainter extends CustomPainter {
  _PadOutlinePainter(this.targets, this.cell);
  final Map<Cell, String> targets;
  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    for (final e in targets.entries) {
      final rect = Rect.fromLTWH(e.key.col * cell, e.key.row * cell, cell, cell).deflate(cell * 0.04);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.22)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.05
          ..color = AppColors.named_(e.value).withValues(alpha: 0.9),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PadOutlinePainter old) => old.targets != targets || old.cell != cell;
}
