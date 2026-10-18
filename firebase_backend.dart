import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models.dart';
import '../utils.dart';
import 'backend.dart';

/// Real server backend on Firebase.
///
/// Data model (see firestore.rules):
///   users/{uid}                    her profile, push token, rounded location
///   sos/{sosId}                    one document per SOS
///   sos/{sosId}/live/loc           her latest position
///   sos/{sosId}/responses/{uid}    "seen / on the way / calling" from others
///
/// The Cloud Function in functions/index.js sends the push messages.
class FirebaseBackend implements SafetyBackend {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? _sosId;
  Map<String, String> _keyByPhone = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _respSub;
  final _responses = StreamController<ResponderUpdate>.broadcast();
  String? _myName;

  @override
  bool get isDemo => false;

  double _round(double v) => (v * 1000).round() / 1000; // about 100 m

  @override
  Future<void> saveProfile({
    required String name,
    required bool receiveNearbyAlerts,
    double? lat,
    double? lng,
  }) async {
    final u = _auth.currentUser;
    if (u == null) return;
    _myName = name;
    await _db.collection('users').doc(u.uid).set({
      'name': name,
      'phone': u.phoneNumber,
      'receiveNearbyAlerts': receiveNearbyAlerts,
      if (lat != null) 'lat': _round(lat),
      if (lng != null) 'lng': _round(lng),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> saveFcmToken(String token) async {
    final u = _auth.currentUser;
    if (u == null) return;
    await _db.collection('users').doc(u.uid).set({
      'fcmToken': token,
      'phone': u.phoneNumber,
    }, SetOptions(merge: true));
  }

  @override
  Future<SosResult> sendSos({
    required String userName,
    required List<TrustedContact> contacts,
    required bool alertNearby,
    required double radiusM,
    double? lat,
    double? lng,
  }) async {
    final u = _auth.currentUser;
    if (u == null) throw StateError('Not signed in');

    _keyByPhone = {for (final c in contacts) normalizePhone(c.phone): c.id};
    final ref = _db.collection('sos').doc();
    _sosId = ref.id;

    await ref.set({
      'ownerUid': u.uid,
      'ownerName': userName,
      'ownerPhone': u.phoneNumber,
      'status': 'active',
      'contactPhones': _keyByPhone.keys.toList(),
      'alertNearby': alertNearby,
      'radiusM': radiusM,
      'helperUids': <String>[],
      'nearbyUids': <String>[],
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      'startedAt': FieldValue.serverTimestamp(),
    });
    if (lat != null && lng != null) {
      await updateLocation(lat, lng);
    }

    // Responses from family and from nearby women who chose to help.
    await _respSub?.cancel();
    _respSub = ref.collection('responses').snapshots().listen((snap) {
      for (final change in snap.docChanges) {
        final d = change.doc.data();
        if (d == null) continue;
        final status = ResponderStatus.values.firstWhere(
          (s) => s.name == d['status'],
          orElse: () => ResponderStatus.seen,
        );
        final nearby = d['role'] == 'nearby';
        final key = nearby
            ? change.doc.id
            : (_keyByPhone[d['phone']] ?? change.doc.id);
        _responses.add(ResponderUpdate(
          key,
          status,
          name: d['name'] as String?,
          nearby: nearby,
        ));
      }
    }, onError: (_) {});

    // The Cloud Function writes how many nearby women it alerted.
    var count = 0;
    try {
      final snap = await ref
          .snapshots()
          .firstWhere((s) => s.data()?['nearbyCount'] != null)
          .timeout(const Duration(seconds: 10));
      count = (snap.data()!['nearbyCount'] as num).toInt();
    } catch (_) {}
    return SosResult(ref.id, count);
  }

  @override
  Future<void> updateLocation(double lat, double lng) async {
    final id = _sosId;
    if (id == null) return;
    await _db.collection('sos').doc(id).collection('live').doc('loc').set({
      'lat': lat,
      'lng': lng,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Stream<ResponderUpdate> responderUpdates() => _responses.stream;

  @override
  Future<void> respond(
    String sosId,
    ResponderStatus status, {
    bool nearby = false,
  }) async {
    final u = _auth.currentUser;
    if (u == null) return;
    var name = _myName;
    if (name == null) {
      final me = await _db.collection('users').doc(u.uid).get();
      name = (me.data()?['name'] as String?) ?? 'Someone';
      _myName = name;
    }
    await _db
        .collection('sos')
        .doc(sosId)
        .collection('responses')
        .doc(u.uid)
        .set({
      'name': name,
      'phone': u.phoneNumber,
      'status': status.name,
      'role': nearby ? 'nearby' : 'family',
      'at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Stream<({double lat, double lng})> liveLocation(String sosId) {
    final doc = _db.collection('sos').doc(sosId).collection('live').doc('loc');
    return _retrying(() => doc.snapshots()).where((s) {
      final d = s.data();
      return d != null && d['lat'] != null && d['lng'] != null;
    }).map((s) {
      final d = s.data()!;
      return (lat: (d['lat'] as num).toDouble(), lng: (d['lng'] as num).toDouble());
    });
  }

  @override
  Stream<bool> isSosActive(String sosId) {
    final doc = _db.collection('sos').doc(sosId);
    return _retrying(() => doc.snapshots())
        .map((s) => s.data()?['status'] == 'active');
  }

  @override
  Future<void> cancelSos() async {
    await _respSub?.cancel();
    _respSub = null;
    final id = _sosId;
    _sosId = null;
    if (id == null) return;
    await _db.collection('sos').doc(id).update({
      'status': 'ended',
      'endedAt': FieldValue.serverTimestamp(),
    });
  }

  /// A helper only gets permission to read an SOS a moment after she taps
  /// "I can help", so a first "permission denied" is expected. Retry quietly.
  Stream<T> _retrying<T>(Stream<T> Function() make) async* {
    while (true) {
      try {
        await for (final value in make()) {
          yield value;
        }
        return;
      } catch (_) {
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
  }
}
