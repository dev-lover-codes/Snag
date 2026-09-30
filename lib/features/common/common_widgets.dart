import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/errors.dart';

/// Global messenger so services (share intent) can show snackbars.
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void showSnack(String message, {String? actionLabel, VoidCallback? onAction}) {
  final m = scaffoldMessengerKey.currentState;
  if (m == null) return;
  m
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        action: actionLabel == null
            ? null
            : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
      ),
    );
}

class ComingSoon extends StatelessWidget {
  const ComingSoon({
    super.key,
    required this.icon,
    required this.message,
    this.compact = false,
  });
  final IconData icon;
  final String message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? 16 : 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(compact ? 16 : 24),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: compact ? 32 : 48,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text('Coming soon', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: scheme.primary.withValues(alpha: 0.7)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 15),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.cloud_off_outlined,
      message: message,
      action: onRetry == null
          ? null
          : FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

/// Shown for deleted items *and* items owned by someone else — identical.
class ItemGoneView extends StatelessWidget {
  const ItemGoneView({super.key, required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.search_off_rounded,
    message: Messages.itemGone,
    action: FilledButton.tonal(
      onPressed: onBack,
      child: const Text('Back to Saved Messages'),
    ),
  );
}

/// Thin banner under the app bar: offline, or last sync failed (+ Retry).
class SyncBanner extends ConsumerWidget {
  const SyncBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(onlineProvider).value ?? true;
    final sync = ref.watch(syncProvider);
    final scheme = Theme.of(context).colorScheme;

    Widget bar(IconData icon, String text, {VoidCallback? retry}) => Material(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
        child: Row(
          children: [
            Icon(icon, size: 18, color: scheme.onSecondaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(color: scheme.onSecondaryContainer),
              ),
            ),
            if (retry != null)
              TextButton(onPressed: retry, child: const Text('Retry')),
          ],
        ),
      ),
    );

    final Widget child;
    if (!online) {
      child = bar(
        Icons.wifi_off_rounded,
        "You're offline — showing saved items.",
      );
    } else if (sync.error != null) {
      child = bar(
        Icons.sync_problem_rounded,
        sync.error!,
        retry: () => ref.read(syncProvider.notifier).refresh(),
      );
    } else if (sync.loading) {
      child = const LinearProgressIndicator(minHeight: 2);
    } else {
      child = const SizedBox.shrink();
    }
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: child,
    );
  }
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final scheme = Theme.of(context).colorScheme;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          style: destructive
              ? TextButton.styleFrom(foregroundColor: scheme.error)
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

enum ConflictChoice { overwrite, keepTheirs }

Future<ConflictChoice?> showConflictDialog(BuildContext context) =>
    showDialog<ConflictChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.devices_rounded),
        title: const Text('Changed on another device'),
        content: const Text(
          'This item was edited somewhere else after you opened it. '
          'Overwrite it with your version, or keep theirs?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ConflictChoice.keepTheirs),
            child: const Text('Keep theirs'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: () => Navigator.pop(ctx, ConflictChoice.overwrite),
            child: const Text('Overwrite'),
          ),
        ],
      ),
    );
