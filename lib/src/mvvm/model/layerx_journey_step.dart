/// A single step in the reconstructed "journey" that led to a log entry.
///
/// Steps are ordered chronologically and rendered as a timeline in the in-app
/// viewer, e.g. screen → controller → service → repository → network → error.
class LayerXJourneyStep {
  /// When this step occurred.
  final DateTime timestamp;

  /// A short title for the step, e.g. the screen or endpoint name.
  final String title;

  /// An optional longer description of what happened during the step.
  final String? description;

  /// A coarse category for the step.
  ///
  /// One of `ui`, `controller`, `service`, `repository`, `network`, `error`
  /// or `log`. Used to pick an icon and color in the timeline.
  final String? type;

  /// Creates a journey step.
  LayerXJourneyStep({
    required this.timestamp,
    required this.title,
    this.description,
    this.type,
  });

  /// Serializes this step to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'title': title,
        'description': description,
        'type': type,
      };

  /// Recreates a step from a map produced by [toJson].
  factory LayerXJourneyStep.fromJson(Map<String, dynamic> json) =>
      LayerXJourneyStep(
        timestamp: DateTime.parse(json['timestamp'] as String),
        title: json['title'] as String,
        description: json['description'] as String?,
        type: json['type'] as String?,
      );
}
