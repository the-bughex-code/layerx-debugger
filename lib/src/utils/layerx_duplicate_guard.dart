import '../models/layerx_log_entry.dart';
import 'layerx_log_store.dart';

/// Collapses identical entries that occur in quick succession so the viewer
/// shows an occurrence count instead of a flood of duplicates.
class LayerXDuplicateGuard {
  LayerXDuplicateGuard._();

  /// Builds a stable key from the level, message and optional location.
  static String generateKey({
    required String levelName,
    required String message,
    String? screenName,
    String? methodName,
  }) {
    return '${levelName}_${message}_${screenName ?? ''}_${methodName ?? ''}';
  }

  /// Returns an existing entry matching [key] within two seconds of
  /// [newTimestamp], or `null` if none is found.
  static LayerXLogEntry? findDuplicate(String key, DateTime newTimestamp) {
    final logs = LayerXLogStore.logs;
    for (final log in logs) {
      if (log.dedupKey == key) {
        final difference = newTimestamp.difference(log.timestamp).abs();
        if (difference.inSeconds <= 2) {
          return log;
        }
      }
    }
    return null;
  }
}
