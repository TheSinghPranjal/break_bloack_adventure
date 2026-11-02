import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Shared "candy block" rendering used by both game boards and previews.
/// Painting (not widgets) keeps large grids cheap to draw.
void paintCandyBlock(Canvas canvas, Rect rect, Color color, {double radiusFactor = 0.22, double opacity = 1}) {
  final r = Radius.circular(rect.shortestSide * radiusFactor);
  final rr = RRect.fromRectAndRadius(rect, r);
  final hsl = HSLColor.fromColor(color);
  final light = hsl.withLightness((hsl.lightness + 0.12).clamp(0, 1)).toColor();
  final dark = hsl.withLightness((hsl.lightness - 0.16).clamp(0, 1)).toColor();

  // Bottom shade (depth).
  canvas.drawRRect(rr, Paint()..color = dark.withValues(alpha: opacity));
  // Body.
  final body = RRect.fromRectAndCorners(
    Rect.fromLTRB(rect.left, rect.top, rect.right, rect.bottom - rect.height * 0.1),
    topLeft: r,
    topRight: r,
    bottomLeft: r,
    bottomRight: r,
  );
  canvas.drawRRect(
    body,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          light.withValues(alpha: opacity),
          color.withValues(alpha: opacity),
        ],
      ).createShader(rect),
  );
  // Gloss highlight.
  final gloss = RRect.fromRectAndRadius(
    Rect.fromLTWH(rect.left + rect.width * 0.16, rect.top + rect.height * 0.1, rect.width * 0.68, rect.height * 0.2),
    Radius.circular(rect.height * 0.1),
  );
  canvas.drawRRect(gloss, Paint()..color = Colors.white.withValues(alpha: 0.35 * opacity));
}

/// Rainbow "wild" cell.
void paintWildBlock(Canvas canvas, Rect rect) {
  final rr = RRect.fromRectAndRadius(rect, Radius.circular(rect.shortestSide * 0.22));
  canvas.drawRRect(
    rr,
    Paint()
      ..shader = const SweepGradient(
        colors: [
          Color(0xFFFF5A6E),
          Color(0xFFFFD23F),
          Color(0xFF3DD68C),
          Color(0xFF4D8BFF),
          Color(0xFF9B5CFF),
          Color(0xFFFF5A6E),
        ],
      ).createShader(rect),
  );
  canvas.drawRRect(rr.deflate(rect.width * 0.18), Paint()..color = Colors.white.withValues(alpha: 0.35));
}

/// Five-point star path centred in [rect].
Path starPath(Rect rect) {
  final c = rect.center;
  final outer = rect.shortestSide / 2;
  final inner = outer * 0.45;
  final p = Path();
  for (var i = 0; i < 10; i++) {
    final rad = i.isEven ? outer : inner;
    final a = -math.pi / 2 + i * math.pi / 5;
    final pt = Offset(c.dx + rad * math.cos(a), c.dy + rad * math.sin(a));
    i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
  }
  return p..close();
}
