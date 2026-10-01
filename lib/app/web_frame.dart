import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Website only: on desktop-sized windows, show the app as a rounded window
/// on a soft brand backdrop instead of stretching edge to edge. Phones and
/// narrow windows get the plain full-screen app.
class WebFrame extends StatelessWidget {
  const WebFrame({super.key, required this.child});
  final Widget child;

  /// Widest the app window grows on large monitors.
  static const maxWidth = 1180.0;

  /// Below this the app is shown full screen, exactly like on a phone.
  static const desktopBreakpoint = 900.0;

  static const _gutter = 24.0;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    if (mq.size.width < desktopBreakpoint) return child;

    final scheme = Theme.of(context).colorScheme;
    final width = math.min(mq.size.width - _gutter * 2, maxWidth);
    final height = mq.size.height - _gutter * 2;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer,
            scheme.surfaceContainerLow,
            scheme.tertiaryContainer,
          ],
        ),
      ),
      child: Center(
        child: SizedBox(
          width: width,
          height: height,
          child: Material(
            elevation: 12,
            shadowColor: scheme.shadow.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(28),
            clipBehavior: Clip.antiAlias,
            color: scheme.surface,
            // Screens measure themselves against the window, not the monitor.
            child: MediaQuery(
              data: mq.copyWith(
                size: Size(width, height),
                padding: EdgeInsets.zero,
                viewPadding: EdgeInsets.zero,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
