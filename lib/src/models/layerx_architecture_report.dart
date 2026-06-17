/// The result of LayerX's best-effort architecture detection.
///
/// A released Flutter app cannot inspect its own source folders at runtime, so
/// LayerX detects what it *can* observe: whether GetX is in use, and which
/// modules (controllers, services, network) have been exercised so far. Module
/// flags light up incrementally as the app runs.
class LayerXArchitectureReport {
  /// Whether LayerX considers this a LayerX-architecture app (and therefore
  /// whether the debugger should inject itself).
  final bool isLayerX;

  /// Whether GetX is being used as the state manager.
  final bool getxDetected;

  /// Whether LayerX GetX services have been registered.
  final bool servicesDetected;

  /// Whether at least one GetX controller (with LayerX logging) has run.
  final bool controllersDetected;

  /// Whether the HTTP/network layer has produced any logs yet.
  final bool networkDetected;

  /// Whether only UI has been observed so far (no controllers/services/network).
  final bool uiOnly;

  /// Creates an architecture report.
  const LayerXArchitectureReport({
    required this.isLayerX,
    required this.getxDetected,
    required this.servicesDetected,
    required this.controllersDetected,
    required this.networkDetected,
    required this.uiOnly,
  });

  /// Whether the integration is partial (LayerX, but not all modules are
  /// active yet).
  bool get isPartial =>
      isLayerX && (uiOnly || !controllersDetected || !networkDetected);
}
