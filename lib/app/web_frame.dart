import 'package:flutter/material.dart';

/// Website only: on wide windows, show the app as a centred column at a
/// comfortable width instead of stretching chats across the screen.
/// Narrow windows (phones) are untouched.
class WebFrame extends StatelessWidget {
  const WebFrame({super.key, required this.child});
  final Widget child;

  static const maxWidth = 760.0;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    if (mq.size.width <= maxWidth + 48) return child;
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: SizedBox(
          width: maxWidth,
          child: Material(
            elevation: 2,
            clipBehavior: Clip.antiAlias,
            // Children measure themselves against the column, not the window.
            child: MediaQuery(
              data: mq.copyWith(size: Size(maxWidth, mq.size.height)),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
