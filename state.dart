import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'services/alert_service.dart';
import 'services/backend.dart';
import 'services/location_service.dart';

class AppState extends ChangeNotifier {
  AppState({SafetyBackend? backend}) : backend = backend ?? DemoBackend();

  final SafetyBackend backend;
  final AlertService alerts = AlertService();
  final LocationService location = LocationService();

  // ---- saved data ----------------------------------------------------------
  List<TrustedContact> contacts = [];
  String userName = 'Me';
  String fakeCallerName = 'Mom';
  int holdSeconds = 2;
  bool sirenOnSos = false;
  bool alertNearbyUsers = true;
  bool receiveNearbyAlerts = true;
  double nearbyRadiusM = 1000;

  // ---- live SOS ------------------------------------------------------------
  bool sosActive = false;
  DateTime? sosStartedAt;
  Position? position;
  bool locationDenied = false;
  int nearbyNotified = 0;
  String? sosId;
  List<Responder> responders = [];

  StreamSubscription<Position>? _posSub;
  StreamSubscription<ResponderUpdate>? _respSub;

  // ---- safety check-in -----------------------------------------------------
  DateTime? checkInEndsAt;
  Timer? _checkInTimer;
  Timer? _profileTimer;

  SharedPreferences? _prefs;

  // ---------------------------------------------------------------------------
  // Loading and saving
  // ---------------------------------------------------------------------------
  Future<void> load() async {
    final p = _prefs = await SharedPreferences.getInstance();
    userName = p.getString('userName') ?? userName;
    fakeCallerName = p.getString('fakeCallerName') ?? fakeCallerName;
    holdSeconds = p.getInt('holdSeconds') ?? holdSeconds;
    sirenOnSos = p.getBool('sirenOnSos') ?? sirenOnSos;
    alertNearbyUsers = p.getBool('alertNearbyUsers') ?? alertNearbyUsers;
    receiveNearbyAlerts = p.getBool('receiveNearbyAlerts') ?? receiveNearbyAlerts;
    nearbyRadiusM = p.getDouble('nearbyRadiusM') ?? nearbyRadiusM;
    final raw = p.getString('contacts');
    if (raw != null) {
      contacts = (jsonDecode(raw) as List)
          .map((e) => TrustedContact.fromJson(e as Map<String, dynamic>))
          .toList();
    }
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    await p.setString('userName', userName);
    await p.setString('fakeCallerName', fakeCallerName);
    await p.setInt('holdSeconds', holdSeconds);
    await p.setBool('sirenOnSos', sirenOnSos);
    await p.setBool('alertNearbyUsers', alertNearbyUsers);
    await p.setBool('receiveNearbyAlerts', receiveNearbyAlerts);
    await p.setDouble('nearbyRadiusM', nearbyRadiusM);
    await p.setString(
      'contacts',
      jsonEncode(contacts.map((c) => c.toJson()).toList()),
    );
  }

  /// Applies [change], saves everything, and rebuilds the UI.
  void update(VoidCallback change) {
    change();
    _save();
    _scheduleProfileSync();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Contacts
  // ---------------------------------------------------------------------------
  void addContact(String name, String phone, String relation) => update(() {
        contacts.add(TrustedContact(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: name,
          phone: phone,
          relation: relation,
        ));
      });

  void removeContact(String id) =>
      update(() => contacts.removeWhere((c) => c.id == id));

  void setAutoAnswer(String id, bool value) => update(() {
        contacts.firstWhere((c) => c.id == id).autoAnswer = value;
      });

  // ---------------------------------------------------------------------------
  // SOS
  // ---------------------------------------------------------------------------
  Future<void> triggerSos() async {
    if (sosActive) return;
    cancelCheckIn(silent: true);

    sosActive = true;
    sosStartedAt = DateTime.now();
    locationDenied = false;
    nearbyNotified = 0;
    responders = contacts.map((c) => Responder(name: c.name, key: c.id)).toList();
    notifyListeners();

    unawaited(alerts.buzz());
    if (sirenOnSos) unawaited(alerts.startSiren());

    _respSub = backend.responderUpdates().listen(_onResponder);

    final allowed = await location.ensurePermission();
    if (!sosActive) return;
    if (allowed) {
      position = await location.current();
      if (!sosActive) return;
      _posSub = location.stream().listen((p) {
        position = p;
        backend.updateLocation(p.latitude, p.longitude);
        notifyListeners();
      }, onError: (_) {});
    } else {
      locationDenied = true;
    }
    notifyListeners();

    final result = await backend.sendSos(
      userName: userName,
      contacts: List.of(contacts),
      alertNearby: alertNearbyUsers,
      radiusM: nearbyRadiusM,
      lat: position?.latitude,
      lng: position?.longitude,
    );
    if (!sosActive) return;
    sosId = result.sosId;
    nearbyNotified = result.nearbyCount;
    notifyListeners();
  }

  void _onResponder(ResponderUpdate u) {
    Responder? r;
    for (final x in responders) {
      if (x.key == u.key) r = x;
    }
    if (r == null) {
      // A nearby woman who chose to help is added to the list.
      if (!u.nearby) return;
      r = Responder(name: u.name ?? 'A woman nearby', key: u.key);
      responders.add(r);
    }
    if (u.status.index <= r.status.index) {
      notifyListeners();
      return;
    }
    r.status = u.status;
    unawaited(alerts.buzz()); // she feels the phone tick when someone responds
    notifyListeners();
  }

  Future<void> endSos() async {
    sosActive = false;
    sosStartedAt = null;
    await _posSub?.cancel();
    _posSub = null;
    await _respSub?.cancel();
    _respSub = null;
    await alerts.stopAll();
    await backend.cancelSos();
    responders = [];
    nearbyNotified = 0;
    sosId = null;
    notifyListeners();
  }

  Future<void> toggleSiren() async {
    if (alerts.sirenOn) {
      await alerts.stopSiren();
    } else {
      await alerts.startSiren();
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Safety check-in: if she does not confirm in time, SOS is sent.
  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------
  // Account / profile (real backend only)
  // ---------------------------------------------------------------------------
  /// Called once she has signed in.
  Future<void> onSignedIn() async {
    await location.ensurePermission();
    await syncProfile();
  }

  Future<void> syncProfile() async {
    if (backend.isDemo) return;
    double? lat;
    double? lng;
    if (receiveNearbyAlerts) {
      final p = await Geolocator.checkPermission();
      if (p == LocationPermission.always || p == LocationPermission.whileInUse) {
        final pos = await location.current();
        lat = pos?.latitude;
        lng = pos?.longitude;
      }
    }
    try {
      await backend.saveProfile(
        name: userName,
        receiveNearbyAlerts: receiveNearbyAlerts,
        lat: lat,
        lng: lng,
      );
    } catch (e) {
      debugPrint('Could not save profile: $e');
    }
  }

  void _scheduleProfileSync() {
    if (backend.isDemo) return;
    _profileTimer?.cancel();
    _profileTimer = Timer(const Duration(seconds: 1), syncProfile);
  }

  Duration? get checkInRemaining {
    final end = checkInEndsAt;
    if (end == null) return null;
    final d = end.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  void startCheckIn(int minutes) {
    _checkInTimer?.cancel();
    checkInEndsAt = DateTime.now().add(Duration(minutes: minutes));
    _checkInTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final end = checkInEndsAt;
      if (end == null) return;
      if (DateTime.now().isAfter(end)) {
        cancelCheckIn();
        triggerSos();
      } else {
        notifyListeners();
      }
    });
    notifyListeners();
  }

  void cancelCheckIn({bool silent = false}) {
    _checkInTimer?.cancel();
    _checkInTimer = null;
    checkInEndsAt = null;
    if (!silent) notifyListeners();
  }

  @override
  void dispose() {
    _checkInTimer?.cancel();
    _profileTimer?.cancel();
    _posSub?.cancel();
    _respSub?.cancel();
    super.dispose();
  }
}
