import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/usage.dart';

/// Lifecycle state of a debug session.
enum SessionStatus { pending, streaming, done, error }

/// Category used to colour and filter events in the timeline.
enum DebugCategory { request, response, system, error }

/// One entry in a session's event timeline. [subtitle] is mutable so a burst
/// of streamed deltas can be coalesced into a single growing event.
class DebugEvent {
  DebugEvent({
    required this.time,
    required this.category,
    required this.title,
    String? subtitle,
    this.status,
    this.detail,
  }) : _subtitle = StringBuffer(subtitle ?? '');

  final DateTime time;
  final DebugCategory category;
  final String title;
  final StringBuffer _subtitle;

  /// e.g. `200 OK` for request/response events.
  String? status;

  /// Expandable raw/JSON payload, when relevant.
  final String? detail;

  String get subtitle => _subtitle.toString();
  void append(String s) => _subtitle.write(s);
}

/// One API exchange — for chat, a single user prompt and the model's streamed
/// reply. Groups everything you need to see what happened: which model, for
/// which prompt, how long it took, the assembled response, tokens and cost.
class DebugSession {
  DebugSession({
    required this.id,
    required this.title,
    this.model,
    this.requestBody,
  }) : startedAt = DateTime.now();

  /// Short session id, e.g. `sess_a1b2c3`.
  final String id;

  /// The user prompt (chat) or endpoint label, used as the session heading.
  final String title;

  final String? model;
  final String? requestBody;
  final DateTime startedAt;

  SessionStatus status = SessionStatus.pending;
  int? httpStatus;
  DateTime? firstTokenAt;
  DateTime? completedAt;
  int chunkCount = 0;
  TokenUsage? usage;
  String? error;
  String? responseBody;
  String? summary;

  final List<DebugEvent> events = [];
  final StringBuffer _content = StringBuffer();
  final StringBuffer _reasoning = StringBuffer();
  final List<String> _rawFrames = [];

  // Cumulative streamed characters over time, for the progress sparkline.
  final List<({Duration t, int chars})> progress = [];

  // The streaming event currently being appended to (for coalescing).
  DebugEvent? _currentStream;

  static const _maxRawFrames = 4000;
  static const _coalesceWindow = Duration(milliseconds: 250);

  String get content => _content.toString();
  String get reasoning => _reasoning.toString();
  bool get hasContent => _content.isNotEmpty;
  bool get hasReasoning => _reasoning.isNotEmpty;
  List<String> get rawFrames => List.unmodifiable(_rawFrames);

  bool get isLive =>
      status == SessionStatus.pending || status == SessionStatus.streaming;

  Duration? get timeToFirstToken => firstTokenAt?.difference(startedAt);
  Duration get duration => (completedAt ?? DateTime.now()).difference(startedAt);

  String? get prettyRequest => _pretty(requestBody);
  String? get prettyResponse => _pretty(responseBody);

  static String? _pretty(String? s) {
    if (s == null) return null;
    final t = s.trimLeft();
    if (!t.startsWith('{') && !t.startsWith('[')) return s;
    try {
      return const JsonEncoder.withIndent('  ').convert(jsonDecode(s));
    } catch (_) {
      return s;
    }
  }
}

/// A capped, in-memory record of API exchanges grouped into [DebugSession]s,
/// wired into [OpenRouterService] and surfaced by the debug panel.
class DebugLog extends ChangeNotifier {
  DebugLog({this.capacity = 50});

  final int capacity;
  final List<DebugSession> _sessions = [];
  bool _enabled = true;
  int _counter = 0;

  Timer? _throttle;
  bool _dirty = false;

  bool get enabled => _enabled;
  bool get isEmpty => _sessions.isEmpty;
  int get length => _sessions.length;

  /// Sessions in chronological order (oldest first).
  List<DebugSession> get sessions => List.unmodifiable(_sessions);

  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    notifyListeners();
  }

  /// Starts a session and returns it (or null when capture is disabled).
  DebugSession? begin({
    required String title,
    String? model,
    String? requestBody,
  }) {
    if (!_enabled) return null;
    final id = 'sess_${(_counter++).toRadixString(36).padLeft(4, '0')}'
        '${DateTime.now().millisecondsSinceEpoch.toRadixString(36).substring(5)}';
    final s = DebugSession(
      id: id,
      title: title,
      model: model,
      requestBody: requestBody,
    );
    s.events.add(DebugEvent(
      time: s.startedAt,
      category: DebugCategory.system,
      title: 'Session started',
      subtitle: model != null ? 'Model: $model' : null,
    ));
    if (requestBody != null) {
      s.events.add(DebugEvent(
        time: DateTime.now(),
        category: DebugCategory.request,
        title: 'Request sent',
        detail: requestBody,
      ));
    }
    _sessions.add(s);
    if (_sessions.length > capacity) {
      _sessions.removeRange(0, _sessions.length - capacity);
    }
    _notifyThrottled();
    return s;
  }

  void response(DebugSession? s, {int? httpStatus}) {
    if (s == null) return;
    s
      ..httpStatus = httpStatus ?? s.httpStatus
      ..status = SessionStatus.streaming;
    s.events.add(DebugEvent(
      time: DateTime.now(),
      category: DebugCategory.response,
      title: 'Response started',
      status: httpStatus == null ? null : '$httpStatus',
    ));
    _notifyThrottled();
  }

  /// Records one streamed frame, coalescing content deltas into a single
  /// growing "Streaming" event per ~250 ms window.
  void chunk(
    DebugSession? s,
    String rawFrame, {
    String? content,
    String? reasoning,
  }) {
    if (s == null) return;
    s.chunkCount++;
    if (s._rawFrames.length < DebugSession._maxRawFrames) {
      s._rawFrames.add(rawFrame);
    }
    final now = DateTime.now();
    if (content != null && content.isNotEmpty) {
      s._content.write(content);
      s.firstTokenAt ??= now;
      final cur = s._currentStream;
      if (cur == null ||
          now.difference(cur.time) > DebugSession._coalesceWindow) {
        final ev = DebugEvent(
          time: now,
          category: DebugCategory.response,
          title: 'Streaming',
          subtitle: content,
        );
        s.events.add(ev);
        s._currentStream = ev;
      } else {
        cur.append(content);
      }
      s.progress.add((t: now.difference(s.startedAt), chars: s._content.length));
    }
    if (reasoning != null && reasoning.isNotEmpty) {
      s._reasoning.write(reasoning);
      s.firstTokenAt ??= now;
    }
    if (s.status == SessionStatus.pending) s.status = SessionStatus.streaming;
    _notifyThrottled();
  }

  /// Records a non-data SSE line (e.g. the `OPENROUTER PROCESSING` keep-alive).
  void note(DebugSession? s, String rawLine) {
    if (s == null) return;
    if (s._rawFrames.length < DebugSession._maxRawFrames) {
      s._rawFrames.add(rawLine);
    }
    _notifyThrottled();
  }

  void setUsage(DebugSession? s, TokenUsage usage) {
    if (s == null) return;
    s.usage = usage;
    _notifyThrottled();
  }

  void complete(
    DebugSession? s, {
    int? httpStatus,
    String? responseBody,
    String? summary,
    String? finishReason,
  }) {
    if (s == null) return;
    s
      ..status = SessionStatus.done
      ..completedAt = DateTime.now()
      ..httpStatus = httpStatus ?? s.httpStatus
      ..responseBody = responseBody ?? s.responseBody
      ..summary = summary ?? s.summary;
    final tokens = s.usage?.totalTokens;
    s.events.add(DebugEvent(
      time: s.completedAt!,
      category: DebugCategory.response,
      title: 'Completed',
      subtitle: [
        if (finishReason != null) 'Finish reason: $finishReason',
        if (tokens != null) '$tokens tokens',
      ].join('  ·  '),
    ));
    s.events.add(DebugEvent(
      time: s.completedAt!,
      category: DebugCategory.system,
      title: 'Session finished',
      subtitle: 'Total duration: ${_fmt(s.duration)}',
    ));
    _notifyNow();
  }

  void fail(DebugSession? s, String error, {int? httpStatus}) {
    if (s == null) return;
    s
      ..status = SessionStatus.error
      ..completedAt = DateTime.now()
      ..error = error
      ..httpStatus = httpStatus ?? s.httpStatus;
    s.events.add(DebugEvent(
      time: s.completedAt!,
      category: DebugCategory.error,
      title: 'Error',
      subtitle: error,
      status: httpStatus == null ? null : '$httpStatus',
    ));
    _notifyNow();
  }

  void clear() {
    _sessions.clear();
    _notifyNow();
  }

  static String _fmt(Duration d) {
    if (d.inMilliseconds < 1000) return '${d.inMilliseconds}ms';
    final s = d.inMilliseconds / 1000;
    return '${s.toStringAsFixed(s >= 10 ? 0 : 1)}s';
  }

  void _notifyNow() {
    _throttle?.cancel();
    _throttle = null;
    _dirty = false;
    notifyListeners();
  }

  void _notifyThrottled() {
    if (_throttle != null) {
      _dirty = true;
      return;
    }
    notifyListeners();
    _throttle = Timer(const Duration(milliseconds: 120), () {
      _throttle = null;
      if (_dirty) {
        _dirty = false;
        _notifyThrottled();
      }
    });
  }

  @override
  void dispose() {
    _throttle?.cancel();
    super.dispose();
  }
}
