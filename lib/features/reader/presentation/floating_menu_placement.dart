import 'dart:ui';

import '../../../domain/books/reading_position.dart';

/// Which side of the target a floating menu ended up on.
enum FloatingMenuSide { above, below, left, right, fallback }

/// Final position of a floating menu, in overlay coordinates.
final class FloatingMenuPlacement {
  const FloatingMenuPlacement({
    required this.left,
    required this.top,
    required this.side,
  });

  final double left;
  final double top;
  final FloatingMenuSide side;

  @override
  String toString() => 'FloatingMenuPlacement($left, $top, ${side.name})';

  @override
  bool operator ==(Object other) =>
      other is FloatingMenuPlacement &&
      other.left == left &&
      other.top == top &&
      other.side == side;

  @override
  int get hashCode => Object.hash(left, top, side);
}

/// Places a floating menu near [target] without covering it when possible.
///
/// [target] is in overlay-local coordinates (`ReaderRect` is only used as a
/// rect carrier here; its fields are read as plain doubles), which is what the
/// host produces after subtracting the Overlay origin from a renderer's
/// global-pixel `sourceRect`.
///
/// Preference: above → below → right → left → least-overlap fallback.
///
/// This is a pure function on purpose: it is the piece that decides whether
/// the selection and annotation menus land on the text the user clicked, and
/// it needs no widget tree to verify.
FloatingMenuPlacement placeFloatingMenu({
  required Size overlaySize,
  required ReaderRect? target,
  required double menuWidth,
  required double menuHeight,
  double gap = 10,
  double margin = 12,
}) {
  final maxLeft = (overlaySize.width - menuWidth - margin).clamp(
    margin,
    overlaySize.width,
  );
  final maxTop = (overlaySize.height - menuHeight - margin).clamp(
    margin,
    overlaySize.height,
  );

  if (target == null || target.width <= 0 || target.height <= 0) {
    // No geometry: park near the top of the reading area, not over mid-page.
    return FloatingMenuPlacement(
      left: (overlaySize.width * 0.5 - menuWidth / 2).clamp(margin, maxLeft),
      top: margin + 56,
      side: FloatingMenuSide.fallback,
    );
  }

  final selection = Rect.fromLTWH(
    target.x,
    target.y,
    target.width,
    target.height,
  );
  final centerX = selection.center.dx;

  double clampLeft(double raw) => raw.clamp(margin, maxLeft).toDouble();
  double clampTop(double raw) => raw.clamp(margin, maxTop).toDouble();

  Rect menuRect(double left, double top) =>
      Rect.fromLTWH(left, top, menuWidth, menuHeight);

  bool fits(Rect menu) {
    if (menu.left < margin - 0.5 ||
        menu.top < margin - 0.5 ||
        menu.right > overlaySize.width - margin + 0.5 ||
        menu.bottom > overlaySize.height - margin + 0.5) {
      return false;
    }
    // Keep a small gap so the bar never sits on the highlight.
    final padded = selection.inflate(gap * 0.35);
    return !menu.overlaps(padded);
  }

  final candidates = <({double left, double top, FloatingMenuSide side})>[
    (
      left: clampLeft(centerX - menuWidth / 2),
      top: clampTop(selection.top - gap - menuHeight),
      side: FloatingMenuSide.above,
    ),
    (
      left: clampLeft(centerX - menuWidth / 2),
      top: clampTop(selection.bottom + gap),
      side: FloatingMenuSide.below,
    ),
    (
      left: clampLeft(selection.right + gap),
      top: clampTop(selection.center.dy - menuHeight / 2),
      side: FloatingMenuSide.right,
    ),
    (
      left: clampLeft(selection.left - gap - menuWidth),
      top: clampTop(selection.center.dy - menuHeight / 2),
      side: FloatingMenuSide.left,
    ),
  ];

  for (final candidate in candidates) {
    final rect = menuRect(candidate.left, candidate.top);
    if (fits(rect)) {
      return FloatingMenuPlacement(
        left: candidate.left,
        top: candidate.top,
        side: candidate.side,
      );
    }
  }

  // Last resort: pick the candidate with minimal overlap area.
  var best = candidates.first;
  var bestOverlap = double.infinity;
  for (final candidate in candidates) {
    final rect = menuRect(candidate.left, candidate.top);
    final overlap = rect.intersect(selection);
    final area = overlap.isEmpty ? 0.0 : overlap.width * overlap.height;
    final offscreen =
        (rect.left < margin ? margin - rect.left : 0) +
        (rect.top < margin ? margin - rect.top : 0) +
        (rect.right > overlaySize.width - margin
            ? rect.right - (overlaySize.width - margin)
            : 0) +
        (rect.bottom > overlaySize.height - margin
            ? rect.bottom - (overlaySize.height - margin)
            : 0);
    final score = area + offscreen * 40;
    if (score < bestOverlap) {
      bestOverlap = score;
      best = candidate;
    }
  }
  return FloatingMenuPlacement(left: best.left, top: best.top, side: best.side);
}
