import 'dart:async';

import '../models.dart';

class SosResult {
  const SosResult(this.sosId, this.nearbyCount);
  final String? sosId;
  final int nearbyCount;
}

/// "Mom saw it", "Dad is on the way". [key] matches [Responder.key].
class ResponderUpdate {
  const ResponderUpdate(this.key, this.status, {this.name, this.nearby = false});
  final String key;
  final ResponderStatus status;
  final String? name;

  /// True when this is a nearby SheSafe user rather than a trusted contact.
  final bool nearby;
}

/// Everything the app needs from a server. [FirebaseBackend] is the real
/// implementation; [DemoBackend] simulates it on one phone.
abstract class SafetyBackend {
  /// True when alerts are only simulated. The UI shows a "DEMO MODE" badge.
  bool get isDemo;

  /// Saves her name, whether she wants nearby alerts, and a rounded location
  /// (about 100 m) used to find who is "nearby".
  Future<void> saveProfile({
    required String name,
    required bool receiveNearbyAlerts,
    double? lat,
    double? lng,
  });

  /// Saves this phone's push token so alerts can reach it.
  Future<void> saveFcmToken(String token);

  /// Sends the SOS to her trusted contacts and, if [alertNearby] is true, to
  /// other SheSafe users within [radiusM].
  Future<SosResult> sendSos({
    required String userName,
    required List<TrustedContact> contacts,
    required bool alertNearby,
    required double radiusM,
    double? lat,
    double? lng,
  });

  /// Pushes her latest position while an SOS is active.
  Future<void> updateLocation(double lat, double lng);

  /// Responses to her SOS (seen, on the way, calling).
  Stream<ResponderUpdate> responderUpdates();

  /// Called on a family member's (or nearby helper's) phone.
  Future<void> respond(String sosId, ResponderStatus status, {bool nearby = false});

  /// Her live position, for the family alert screen.
  Stream<({double lat, double lng})> liveLocation(String sosId);

  /// Becomes false when she taps "I'm safe", so alarms can stop.
  Stream<bool> isSosActive(String sosId);

  Future<void> cancelSos();
}

/// Pretends to be a server so the whole flow can be tried on one phone.
/// No message is ever sent to anyone.
class DemoBackend implements SafetyBackend {
  final _controller = StreamController<ResponderUpdate>.broadcast();
  final _timers = <Timer>[];

  @override
  bool get isDemo => true;

  @override
  Future<void> saveProfile({
    required String name,
    required bool receiveNearbyAlerts,
    double? lat,
    double? lng,
  }) async {}

  @override
  Future<void> saveFcmToken(String token) async {}

  @override
  Future<SosResult> sendSos({
    required String userName,
    required List<TrustedContact> contacts,
    required bool alertNearby,
    required double radiusM,
    double? lat,
    double? lng,
  }) async {
    _clear();
    for (var i = 0; i < contacts.length; i++) {
      final key = contacts[i].id;
      _later(4 + i * 3, ResponderUpdate(key, ResponderStatus.seen));
      if (i == 0) _later(11, ResponderUpdate(key, ResponderStatus.onTheWay));
      if (i == 1) _later(16, ResponderUpdate(key, ResponderStatus.calling));
    }
    return SosResult('demo', alertNearby ? 3 : 0);
  }

  @override
  Future<void> updateLocation(double lat, double lng) async {}

  @override
  Stream<ResponderUpdate> responderUpdates() => _controller.stream;

  @override
  Future<void> respond(String sosId, ResponderStatus status, {bool nearby = false}) async {}

  @override
  Stream<({double lat, double lng})> liveLocation(String sosId) => const Stream.empty();

  @override
  Stream<bool> isSosActive(String sosId) => const Stream.empty();

  @override
  Future<void> cancelSos() async => _clear();

  void _later(int seconds, ResponderUpdate update) {
    _timers.add(Timer(Duration(seconds: seconds), () {
      if (!_controller.isClosed) _controller.add(update);
    }));
  }

  void _clear() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
  }
}
