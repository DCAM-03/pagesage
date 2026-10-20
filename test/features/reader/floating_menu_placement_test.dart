import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/domain/books/reading_position.dart';
import 'package:pagesage/features/reader/presentation/floating_menu_placement.dart';

/// Unit tests for the selection and annotation menu placement.
///
/// The renderer reports `sourceRect` in global pixels and the host converts it
/// to overlay-local coordinates before calling this function, so a target rect
/// here is in the same space the menus are positioned in.
///
/// These pin the S0 acceptance wording: the menu must appear *above* the text
/// it belongs to, and it must not leave the window.
void main() {
  const overlay = Size(1280, 800);
  const menuWidth = 520.0;
  const menuHeight = 56.0;

  ReaderRect rect(double x, double y, {double w = 240, double h = 18}) =>
      ReaderRect(page: 1, x: x, y: y, width: w, height: h);

  test('first line: menu goes above the selection', () {
    final target = rect(300, 120);
    final placement = placeFloatingMenu(
      overlaySize: overlay,
      target: target,
      menuWidth: menuWidth,
      menuHeight: menuHeight,
    );

    expect(placement.side, FloatingMenuSide.above);
    // 10px gap above the selection, centered on it.
    expect(placement.top + menuHeight, closeTo(120 - 10, 0.001));
    expect(placement.left + menuWidth / 2, closeTo(300 + 240 / 2, 0.001));
  });

  test('selection near the top flips below instead of leaving the window', () {
    final placement = placeFloatingMenu(
      overlaySize: overlay,
      target: rect(300, 20),
      menuWidth: menuWidth,
      menuHeight: menuHeight,
    );

    expect(placement.side, FloatingMenuSide.below);
    expect(placement.top, greaterThanOrEqualTo(12));
    // Still horizontally centered on the text.
    expect(placement.left + menuWidth / 2, closeTo(420, 0.001));
  });

  test('selection at the right edge keeps the menu inside the window', () {
    final placement = placeFloatingMenu(
      overlaySize: overlay,
      target: rect(1240, 400, w: 30),
      menuWidth: menuWidth,
      menuHeight: menuHeight,
    );

    expect(placement.left + menuWidth, lessThanOrEqualTo(overlay.width - 12));
    expect(placement.left, greaterThanOrEqualTo(12));
    expect(placement.top, greaterThanOrEqualTo(12));
    expect(placement.top + menuHeight, lessThanOrEqualTo(overlay.height - 12));
  });

  test('menu never overlaps the text it belongs to when space allows', () {
    final target = rect(400, 400);
    final placement = placeFloatingMenu(
      overlaySize: overlay,
      target: target,
      menuWidth: menuWidth,
      menuHeight: menuHeight,
    );

    final menu = Rect.fromLTWH(
      placement.left,
      placement.top,
      menuWidth,
      menuHeight,
    );
    final text = Rect.fromLTWH(target.x, target.y, target.width, target.height);
    expect(menu.overlaps(text), isFalse);
  });

  test('no geometry parks the menu near the top, not mid-page', () {
    final placement = placeFloatingMenu(
      overlaySize: overlay,
      target: null,
      menuWidth: menuWidth,
      menuHeight: menuHeight,
    );

    expect(placement.side, FloatingMenuSide.fallback);
    expect(placement.top, lessThan(overlay.height / 2));
    expect(placement.left, greaterThanOrEqualTo(12));
  });

  test('a window shorter than the menu still yields on-screen coordinates', () {
    // Degenerate case: the clamp can no longer fit the menu. It must still
    // produce finite, non-negative coordinates rather than throwing.
    final placement = placeFloatingMenu(
      overlaySize: const Size(320, 60),
      target: rect(100, 20, w: 80, h: 10),
      menuWidth: menuWidth,
      menuHeight: menuHeight,
    );

    expect(placement.left.isFinite, isTrue);
    expect(placement.top.isFinite, isTrue);
    expect(placement.left, greaterThanOrEqualTo(12));
    expect(placement.top, greaterThanOrEqualTo(12));
  });

  test('a selection larger than the window still places the menu', () {
    final placement = placeFloatingMenu(
      overlaySize: const Size(400, 300),
      target: rect(-20, -10, w: 600, h: 500),
      menuWidth: menuWidth,
      menuHeight: menuHeight,
    );

    expect(placement.left.isFinite, isTrue);
    expect(placement.top.isFinite, isTrue);
    expect(placement.left, inInclusiveRange(12, 400));
    expect(placement.top, inInclusiveRange(12, 300));
  });

  test('placement is a pure function of its inputs', () {
    final a = placeFloatingMenu(
      overlaySize: overlay,
      target: rect(300, 120),
      menuWidth: menuWidth,
      menuHeight: menuHeight,
    );
    final b = placeFloatingMenu(
      overlaySize: overlay,
      target: rect(300, 120),
      menuWidth: menuWidth,
      menuHeight: menuHeight,
    );

    expect(a, b);
  });
}
