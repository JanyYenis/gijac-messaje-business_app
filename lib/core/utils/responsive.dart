import 'package:flutter/widgets.dart';

import '../constants/app_constants.dart';

/// Simple responsive utilities for phone / tablet adaptation.
class Responsive {
  Responsive._();

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < AppConstants.mobileMaxWidth;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= AppConstants.mobileMaxWidth &&
        width < AppConstants.tabletMaxWidth;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= AppConstants.tabletMaxWidth;

  /// Returns a value based on the current breakpoint.
  static T value<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop(context)) return desktop ?? tablet ?? mobile;
    if (isTablet(context)) return tablet ?? mobile;
    return mobile;
  }

  /// Horizontal content padding that grows on larger screens.
  static double horizontalPadding(BuildContext context) =>
      value(context, mobile: 16, tablet: 32, desktop: 64);
}
