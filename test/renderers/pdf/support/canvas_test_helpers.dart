import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The painted page's box inside the reader.
///
/// The page is painted by a `CustomPaint` whose painter is not null and whose
/// aspect ratio equals the PDF page's (the only such large element in the
/// reader). Matching by ratio rather than by size keeps working when zoom
/// makes the page larger than the window.
Rect? paintedPageRect(WidgetTester tester, {double aspect = 612 / 792}) {
  Rect? best;
  for (final element in find.byType(CustomPaint).evaluate()) {
    final widget = element.widget as CustomPaint;
    if (widget.painter == null) continue;
    final object = element.renderObject;
    if (object is! RenderBox || !object.hasSize) continue;
    final size = object.size;
    if (size.width < 100 || size.height < 100) continue;
    if ((size.width / size.height - aspect).abs() > 0.01) continue;
    final rect = object.localToGlobal(Offset.zero) & size;
    if (best == null || rect.width * rect.height > best.width * best.height) {
      best = rect;
    }
  }
  return best;
}

/// Sends one mouse-wheel event to the centre of the reader.
///
/// Uses [TestPointer.scroll] rather than a bare [PointerScrollEvent]: the
/// helper stamps the event with the implicit view and device, which is what
/// routes it through the real hit-test path in a test binding.
Future<void> simulateWheel(WidgetTester tester, Offset delta) async {
  final center = tester.getCenter(find.byType(Scaffold));
  final pointer = TestPointer(1, PointerDeviceKind.mouse);
  pointer.hover(center);
  GestureBinding.instance.handlePointerEvent(pointer.scroll(delta));
  await tester.pump();
}
