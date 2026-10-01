import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Receives text/URLs shared into Snag from Android's share sheet.
///
/// Handles both a cold start ([ReceiveSharingIntent.getInitialMedia]) and
/// shares while the app is running ([ReceiveSharingIntent.getMediaStream]).
/// Every error is swallowed and reported as an empty share — never a crash.
class ShareIntentService {
  ShareIntentService({ReceiveSharingIntent? plugin})
    : _plugin = plugin ?? ReceiveSharingIntent.instance;

  final ReceiveSharingIntent _plugin;
  StreamSubscription<List<SharedMediaFile>>? _sub;

  String? _lastText;
  DateTime? _lastAt;

  /// [onShare] gets the shared text (possibly null/empty for unsupported
  /// shares — the caller shows "Nothing to save from this share").
  Future<void> start(void Function(String? text) onShare) async {
    if (kIsWeb) return; // The website has no Android share sheet.
    try {
      _sub = _plugin.getMediaStream().listen(
        (files) => _handle(files, onShare),
        onError: (Object e) => debugPrint('share stream error: $e'),
      );
    } catch (e) {
      debugPrint('share stream unavailable: $e');
    }
    try {
      final initial = await _plugin.getInitialMedia();
      if (initial.isNotEmpty) _handle(initial, onShare);
    } catch (e) {
      debugPrint('initial share unavailable: $e');
    }
  }

  void _handle(List<SharedMediaFile> files, void Function(String?) onShare) {
    String? text;
    try {
      final parts = <String>[];
      for (final f in files) {
        if (f.type == SharedMediaType.text || f.type == SharedMediaType.url) {
          // Text shares arrive in `path`; some apps also set `message`.
          for (final s in [f.path, f.message]) {
            if (s != null && s.trim().isNotEmpty && !parts.contains(s)) {
              parts.add(s);
            }
          }
        }
      }
      text = parts.join('\n');
    } catch (_) {
      text = null;
    }
    unawaited(_reset());

    // The same intent can be delivered twice (initial + stream).
    final now = DateTime.now();
    if (text != null &&
        text == _lastText &&
        _lastAt != null &&
        now.difference(_lastAt!) < const Duration(seconds: 3)) {
      return;
    }
    _lastText = text;
    _lastAt = now;
    onShare(text);
  }

  Future<void> _reset() async {
    try {
      await _plugin.reset();
    } catch (_) {}
  }

  Future<void> dispose() async => _sub?.cancel();
}
