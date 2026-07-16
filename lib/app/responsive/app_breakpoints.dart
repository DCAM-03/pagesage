import 'package:flutter/widgets.dart';

enum AppBreakpoint {
  compact,
  medium,
  expanded;

  static const mediumMinWidth = 600.0;
  static const expandedMinWidth = 1024.0;
  static const sidePanelMinWidth = 900.0;

  static AppBreakpoint fromWidth(double width) {
    if (width >= expandedMinWidth) {
      return AppBreakpoint.expanded;
    }
    if (width >= mediumMinWidth) {
      return AppBreakpoint.medium;
    }
    return AppBreakpoint.compact;
  }

  static bool supportsSidePanelWidth(double width) {
    return width >= sidePanelMinWidth;
  }
}

extension AppBreakpointProperties on AppBreakpoint {
  bool get isCompact => this == AppBreakpoint.compact;

  bool get isMediumOrLarger => this != AppBreakpoint.compact;

  bool get isExpanded => this == AppBreakpoint.expanded;
}

extension ResponsiveBuildContext on BuildContext {
  AppBreakpoint get appBreakpoint {
    return AppBreakpoint.fromWidth(MediaQuery.sizeOf(this).width);
  }

  bool get supportsSidePanel {
    return AppBreakpoint.supportsSidePanelWidth(MediaQuery.sizeOf(this).width);
  }
}
