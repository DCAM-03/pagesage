import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/app/responsive/app_breakpoints.dart';

void main() {
  test('maps widths to compact medium and expanded breakpoints', () {
    expect(AppBreakpoint.fromWidth(320), AppBreakpoint.compact);
    expect(AppBreakpoint.fromWidth(599), AppBreakpoint.compact);
    expect(AppBreakpoint.fromWidth(600), AppBreakpoint.medium);
    expect(AppBreakpoint.fromWidth(900), AppBreakpoint.medium);
    expect(AppBreakpoint.fromWidth(1024), AppBreakpoint.expanded);
    expect(AppBreakpoint.fromWidth(1440), AppBreakpoint.expanded);
  });

  test('maps side panel support to desktop and large tablet widths', () {
    expect(AppBreakpoint.supportsSidePanelWidth(899), isFalse);
    expect(AppBreakpoint.supportsSidePanelWidth(900), isTrue);
  });
}
