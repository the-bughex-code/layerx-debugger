// Internal viewer widget — not part of the public API.
// ignore_for_file: public_member_api_docs
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:layerx_debugger/src/mvvm/model/layerx_journey_step.dart';

class LxJourneyTimeline extends StatelessWidget {
  final List<LayerXJourneyStep> journey;

  const LxJourneyTimeline({super.key, required this.journey});

  @override
  Widget build(BuildContext context) {
    if (journey.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No journey data available.'),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Journey Timeline',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: journey.length,
              itemBuilder: (context, index) {
                final step = journey[index];
                final isLast = index == journey.length - 1;
                final isError = step.type == 'error';

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isError
                                ? Colors.red.shade100
                                : _stepColor(step.type).withValues(alpha: 0.15),
                            border: Border.all(
                              color:
                                  isError ? Colors.red : _stepColor(step.type),
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              _stepIcon(step.type),
                              size: 12,
                              color:
                                  isError ? Colors.red : _stepColor(step.type),
                            ),
                          ),
                        ),
                        if (!isLast)
                          Container(
                            width: 2,
                            height: 36,
                            color: isError
                                ? Colors.red.shade200
                                : Colors.grey.shade300,
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isError
                              ? const Color(0xFFFFF0F0)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: isError
                              ? Border.all(color: Colors.red.shade200)
                              : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    step.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: isError
                                          ? Colors.red.shade900
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                                Text(
                                  DateFormat('HH:mm:ss.SSS')
                                      .format(step.timestamp),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                            if (step.description != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                step.description!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isError
                                      ? Colors.red.shade800
                                      : Colors.black54,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _stepColor(String? type) {
    switch (type) {
      case 'ui':
        return Colors.purple;
      case 'controller':
        return Colors.blue;
      case 'service':
        return Colors.green;
      case 'repository':
        return Colors.teal;
      case 'network':
        return Colors.cyan;
      case 'error':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _stepIcon(String? type) {
    switch (type) {
      case 'ui':
        return Icons.phone_android;
      case 'controller':
        return Icons.gamepad_outlined;
      case 'service':
        return Icons.miscellaneous_services_outlined;
      case 'repository':
        return Icons.storage_outlined;
      case 'network':
        return Icons.cloud_outlined;
      case 'error':
        return Icons.error_outline;
      default:
        return Icons.info_outline;
    }
  }
}
