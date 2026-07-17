import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/repository/layerx_log_store.dart';

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

  /// The most repeat timestamps kept per entry. An error firing in a tight
  /// loop (a broken timer/stream) would otherwise grow its entry without
  /// bound; the occurrence count keeps the true total.
  static const int maxRepeatTimestamps = 100;

  /// Registers one more occurrence of [duplicate]: bumps the count and appends
  /// [timestamp], keeping only the newest [maxRepeatTimestamps] timestamps.
  static void registerRepeat(LayerXLogEntry duplicate, DateTime timestamp) {
    duplicate.occurrenceCount++;
    duplicate.repeatTimestamps.add(timestamp);
    if (duplicate.repeatTimestamps.length > maxRepeatTimestamps) {
      duplicate.repeatTimestamps.removeRange(
        0,
        duplicate.repeatTimestamps.length - maxRepeatTimestamps,
      );
    }
  }

  /// Returns an existing entry matching [key] within two seconds of
  /// [newTimestamp], or `null` if none is found.
  ///
  /// Delegates to the store's in-place scan: this runs on EVERY ingest, and
  /// going through `LayerXLogStore.logs` would copy the whole list each time —
  /// O(n²) allocation churn during a console flood.
  static LayerXLogEntry? findDuplicate(String key, DateTime newTimestamp) =>
      LayerXLogStore.findRecentByDedupKey(key, newTimestamp);
}
