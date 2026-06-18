import 'package:flutter/material.dart';

import 'package:layerx_debugger/src/mvvm/model/layerx_log_entry.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_level.dart';
import 'package:layerx_debugger/src/config/enums/layerx_log_source.dart';

/// The result of a blame analysis: who most likely owns a failure and what QA
/// should write in the bug report.
class LayerXBlameInfo {
  /// The team or layer most likely responsible (e.g. backend, network, app).
  final String responsibleParty;

  /// A human-readable explanation of why this party is implicated.
  final String explanation;

  /// A short, actionable note for QA to include in the bug report.
  final String qaNote;

  /// The accent color used when rendering the blame card.
  final Color color;

  /// The icon used when rendering the blame card.
  final IconData icon;

  /// Creates a blame result.
  LayerXBlameInfo({
    required this.responsibleParty,
    required this.explanation,
    required this.qaNote,
    required this.color,
    required this.icon,
  });
}

/// Analyzes a log entry and attributes the most likely owner of the problem.
///
/// Pure and stateless. Returns `null` for non-actionable levels
/// (verbose/debug/info/success).
class LayerXBlameEngine {
  LayerXBlameEngine._();

  /// Returns a [LayerXBlameInfo] for [log], or `null` when no blame is warranted.
  static LayerXBlameInfo? analyze(LayerXLogEntry log) {
    if (log.level != LayerXLogLevel.warning &&
        log.level != LayerXLogLevel.error &&
        log.level != LayerXLogLevel.fatal) {
      return null;
    }

    final msg = log.message.toLowerCase();
    final trace = (log.stackTrace ?? '').toLowerCase();
    final resp = (log.responsePayload ?? '').toLowerCase();
    final code = log.statusCode;
    final source = log.source;

    // ── 1. Server crashes / infrastructure failures (5xx) ──────────────────
    if (code != null && code >= 500 && code < 600) {
      if (code == 503) {
        return LayerXBlameInfo(
          responsibleParty: '🖥️ Backend / DevOps (Service Unavailable)',
          explanation:
              'HTTP 503 Service Unavailable. The server is temporarily offline due to maintenance, '
              'overload, or a crash. The mobile app cannot work around this — the backend team must fix it.',
          qaNote:
              'Assign to: Backend / DevOps. Steps: Check server status page, deployment logs.',
          color: Colors.red.shade900,
          icon: Icons.cloud_off_outlined,
        );
      }
      if (code == 502) {
        return LayerXBlameInfo(
          responsibleParty: '🖥️ Backend / DevOps (Bad Gateway)',
          explanation:
              'HTTP 502 Bad Gateway. The reverse proxy (nginx/load-balancer) received an invalid '
              'response from the upstream app server. This is an infrastructure issue, not mobile code.',
          qaNote:
              'Assign to: DevOps. Steps: Check nginx/proxy logs and upstream service health.',
          color: Colors.red.shade900,
          icon: Icons.dns_outlined,
        );
      }
      if (code == 504) {
        return LayerXBlameInfo(
          responsibleParty: '🖥️ Backend / DevOps (Gateway Timeout)',
          explanation:
              'HTTP 504 Gateway Timeout. The proxy timed out waiting for the upstream server. '
              'Usually caused by a slow DB query or external dependency on the backend.',
          qaNote:
              'Assign to: Backend. Steps: Profile slow endpoints, check DB query performance.',
          color: Colors.deepOrange.shade900,
          icon: Icons.hourglass_disabled_outlined,
        );
      }
      return LayerXBlameInfo(
        responsibleParty: '🖥️ Backend Server (${code}xx Internal Error)',
        explanation:
            'HTTP $code. The server threw an unhandled exception. This means a crash inside the '
            'backend code. The mobile app is sending a valid request — the problem is server-side.',
        qaNote:
            'Assign to: Backend. Steps: Share endpoint, request payload, and timestamp with backend team.',
        color: Colors.red.shade900,
        icon: Icons.report_gmailerrorred_outlined,
      );
    }

    // ── 2. Network / connectivity ───────────────────────────────────────────
    if (source == LayerXLogSource.network ||
        msg.contains('socketexception') ||
        msg.contains('connection refused') ||
        msg.contains('connection reset') ||
        msg.contains('network is unreachable') ||
        msg.contains('failed host lookup') ||
        msg.contains('no route to host') ||
        trace.contains('socketexception')) {
      return LayerXBlameInfo(
        responsibleParty: '🌐 Network / Device Connectivity',
        explanation:
            'The device could not reach the server. Possible causes: (1) no internet on device, '
            '(2) server DNS not resolving, (3) firewall blocking, (4) VPN issue.',
        qaNote:
            'Test on Wi-Fi AND 4G. If issue persists on both, assign to: DevOps (DNS/firewall).',
        color: Colors.teal.shade800,
        icon: Icons.wifi_off_outlined,
      );
    }

    // ── 3. Timeout (client or server side) ─────────────────────────────────
    if (code == 408 ||
        msg.contains('timeoutexception') ||
        msg.contains('connect timeout') ||
        msg.contains('receive timeout') ||
        msg.contains('send timeout')) {
      return LayerXBlameInfo(
        responsibleParty: '⏱️ Timeout — App Config or Backend Slowness',
        explanation:
            'HTTP 408 / TimeoutException. The server did not respond within the configured time limit. '
            'If timeout is too short it may be an app config issue. If the endpoint is genuinely slow, '
            'it is a backend performance problem.',
        qaNote:
            'Check: (1) Dio timeout config in the app, (2) endpoint response time in Postman. If Postman is also slow → Backend issue.',
        color: Colors.orange.shade900,
        icon: Icons.timer_off_outlined,
      );
    }

    // ── 4. Rate limiting ────────────────────────────────────────────────────
    if (code == 429 ||
        msg.contains('too many requests') ||
        msg.contains('rate limit')) {
      return LayerXBlameInfo(
        responsibleParty: '⚠️ Backend Rate Limiter (Too Many Requests)',
        explanation:
            'HTTP 429 Too Many Requests. The app is sending requests faster than the server '
            'allows. This could be an infinite retry loop in the app code, or the backend rate '
            'limit being too aggressive for normal usage.',
        qaNote:
            'Check: (1) Is the app retrying in a loop? (Frontend issue) (2) Is rate-limit threshold correct? (Backend issue)',
        color: Colors.deepOrange.shade900,
        icon: Icons.speed_outlined,
      );
    }

    // ── 5. Auth / token issues ──────────────────────────────────────────────
    if (code == 401 ||
        msg.contains('unauthorized') ||
        msg.contains('unauthenticated')) {
      return LayerXBlameInfo(
        responsibleParty: '🔑 Authentication — Token Expired or Missing',
        explanation:
            'HTTP 401 Unauthorized. The auth token is expired, revoked, or was not sent in '
            'the request headers. Check: (1) Is the token being attached by Dio interceptor? '
            '(2) Is refresh-token flow working correctly?',
        qaNote:
            'Test: Log out → log in → retry. If it persists after fresh login → Backend (token validation bug).',
        color: Colors.orange.shade900,
        icon: Icons.vpn_key_outlined,
      );
    }

    // ── 6. Permission / role issues ─────────────────────────────────────────
    if (code == 403 ||
        msg.contains('forbidden') ||
        msg.contains('access denied') ||
        msg.contains('not allowed')) {
      return LayerXBlameInfo(
        responsibleParty: '⚙️ Backend — Permission / Role Configuration',
        explanation:
            'HTTP 403 Forbidden. The authenticated user does not have permission to access this '
            'resource. Usually a backend roles/ACL configuration problem, not a mobile bug.',
        qaNote:
            'Verify the user\'s role in the database. If role is correct → Backend (permission rule bug).',
        color: Colors.orange.shade800,
        icon: Icons.gpp_bad_outlined,
      );
    }

    // ── 7. Conflict (e.g. duplicate record) ─────────────────────────────────
    if (code == 409 ||
        msg.contains('conflict') ||
        msg.contains('already exists') ||
        msg.contains('duplicate')) {
      return LayerXBlameInfo(
        responsibleParty: '⚙️ Backend — Data Conflict / Duplicate Entry',
        explanation:
            'HTTP 409 Conflict. The request conflicts with existing server state (e.g., trying to '
            'create a record that already exists). The app may be missing a uniqueness check or the '
            'backend should return a more descriptive error.',
        qaNote:
            'Check if the app does a pre-check before the POST. If yes → Backend should handle idempotency.',
        color: Colors.blueGrey.shade800,
        icon: Icons.merge_outlined,
      );
    }

    // ── 8. Validation / bad request (app sending wrong payload) ─────────────
    if (code == 422 || code == 400) {
      final hasValidationKeyword = resp.contains('validation') ||
          resp.contains('required') ||
          resp.contains('invalid') ||
          resp.contains('field') ||
          resp.contains('must be');
      if (hasValidationKeyword || code == 422) {
        return LayerXBlameInfo(
          responsibleParty:
              '📱 Mobile App — Request Payload / Validation Mismatch',
          explanation:
              'HTTP $code. The backend rejected the request body due to failed validation. '
              'The app is sending a field with the wrong type, missing a required field, or using '
              'an outdated API schema. This is typically a frontend model/serialization bug.',
          qaNote:
              'Compare the request payload in this log with the backend API docs. Look for missing/renamed fields.',
          color: Colors.blue.shade900,
          icon: Icons.app_registration_outlined,
        );
      }
      return LayerXBlameInfo(
        responsibleParty: '📱 Mobile App or Backend — Bad Request Parameters',
        explanation:
            'HTTP $code Bad Request. The server could not process the request due to client-side '
            'error (malformed syntax, invalid request message framing, or deceptive request routing).',
        qaNote:
            'Inspect the request payload below. Compare fields against the API contract.',
        color: Colors.blue.shade900,
        icon: Icons.broken_image_outlined,
      );
    }

    // ── 9. Not found (URL mismatch) ─────────────────────────────────────────
    if (code == 404 ||
        msg.contains('not found') ||
        msg.contains('no such route')) {
      return LayerXBlameInfo(
        responsibleParty: '🔗 API Endpoint Mismatch (App URL vs Server Route)',
        explanation:
            'HTTP 404 Not Found. The request URL does not exist on the server. Either the app '
            'has a typo in the endpoint path, or the backend route was deleted/renamed without '
            'updating the app.',
        qaNote:
            'Copy the endpoint from this log and test in Postman. If Postman also gets 404 → Backend deleted/renamed it.',
        color: Colors.deepOrange.shade900,
        icon: Icons.link_off_outlined,
      );
    }

    // ── 10. JSON parse / deserialization (API contract broken) ──────────────
    if (msg.contains('formatexception') ||
        msg.contains('json') ||
        msg.contains('unexpected character') ||
        msg.contains('type is not a subtype') ||
        msg.contains('is not subtype') ||
        msg.contains('fromjson') ||
        msg.contains('deserializ') ||
        msg.contains('xmlhttprequest') ||
        trace.contains('fromjson') ||
        trace.contains('formatexception')) {
      if (log.responseChanged) {
        return LayerXBlameInfo(
          responsibleParty: '🔄 Backend Changed API Contract Without Notice',
          explanation:
              'A JSON parsing error occurred AND the API response has changed since the previous '
              'call. The backend likely renamed, removed, or changed the type of a field that the '
              'app is trying to parse. This broke the mobile data model.',
          qaNote:
              'CRITICAL: Compare "Previous Response" vs "Current Response" in this log. Show the diff to the backend team.',
          color: Colors.red.shade800,
          icon: Icons.swap_horiz_outlined,
        );
      }
      return LayerXBlameInfo(
        responsibleParty: '📱 Mobile App — JSON Parse / Model Mismatch',
        explanation:
            'A JSON parsing or type-cast error occurred while processing the server response. '
            'The fromJson() method is receiving a field type it doesn\'t expect (e.g., int instead '
            'of String, null instead of a list). Check the model\'s fromJson() vs the actual response.',
        qaNote:
            'Look at the Response Payload in this log. Find the field whose type differs from the Dart model.',
        color: Colors.purple.shade900,
        icon: Icons.data_object_outlined,
      );
    }

    // ── 11. Flutter runtime errors (app code bugs) ──────────────────────────
    if (source == LayerXLogSource.app ||
        msg.contains('null check operator') ||
        msg.contains('rangeerror') ||
        msg.contains('nosuchmethod') ||
        msg.contains('bad state: no element') ||
        msg.contains('concurrent modification') ||
        msg.contains('stack overflow') ||
        msg.contains('setstate') ||
        msg.contains('renderflex overflowed') ||
        trace.contains('null check') ||
        trace.contains('rangeerror') ||
        trace.contains('nosuchmethod') ||
        trace.contains('setstate') ||
        trace.contains('bad state')) {
      var detail = 'A client-side Flutter exception occurred.';
      var note =
          'Assign to: Mobile Team. Attach the stack trace from this log.';

      if (msg.contains('null check') || trace.contains('null check')) {
        detail =
            'A null-check (!) was used on a null value. Usually caused by the backend '
            'returning null for a field the app assumes is always non-null.';
        note =
            'Check if the backend is returning null for a required field. If yes → shared blame (backend + mobile model).';
      } else if (msg.contains('bad state: no element') ||
          trace.contains('bad state')) {
        detail =
            'firstWhere() / single was called on an empty list. The app assumes data always '
            'exists but the backend returned an empty list.';
        note =
            'Add an isEmpty check before accessing the list, or verify the backend returns data consistently.';
      } else if (msg.contains('renderflex')) {
        detail =
            'A Flutter layout overflow. This is a pure UI/frontend bug — widget is too large '
            'for its parent container on certain screen sizes.';
        note =
            'Assign to: Mobile Team (UI). Test on a smaller device (320px width).';
      } else if (msg.contains('concurrent modification')) {
        detail =
            'A list was modified while being iterated. This is a threading/state management bug in the app.';
        note =
            'Assign to: Mobile Team. Use a copy of the list before modifying it inside a loop.';
      }

      return LayerXBlameInfo(
        responsibleParty: '📱 Flutter Mobile App (Frontend Code Bug)',
        explanation: detail,
        qaNote: note,
        color: Colors.purple.shade900,
        icon: Icons.developer_mode_outlined,
      );
    }

    // ── 12. Platform / plugin issues ─────────────────────────────────────────
    if (msg.contains('platformexception') ||
        trace.contains('platformexception')) {
      return LayerXBlameInfo(
        responsibleParty: '📱 Mobile App — Native Plugin / Platform Error',
        explanation:
            'A PlatformException was thrown by a native plugin (camera, location, push notifications, '
            'etc.). This is a mobile integration bug — either missing permissions in AndroidManifest/'
            'Info.plist or the plugin is misconfigured.',
        qaNote:
            'Check app permissions on device settings. If permissions are granted → Plugin setup bug (Mobile Team).',
        color: Colors.indigo.shade800,
        icon: Icons.phonelink_erase_outlined,
      );
    }

    // ── 13. Unclassified — generic fallback ──────────────────────────────────
    return LayerXBlameInfo(
      responsibleParty: '❓ Undetermined — Needs Manual Review',
      explanation:
          'No specific signature was detected to automatically attribute this error to a team. '
          'Review the stack trace, endpoint, request payload, and response body for clues.',
      qaNote:
          'Share the full log export (clipboard icon in list) with both Mobile and Backend teams.',
      color: Colors.grey.shade700,
      icon: Icons.help_outline,
    );
  }
}
