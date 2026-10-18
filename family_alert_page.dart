import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/alert_service.dart';
import '../services/backend.dart';
import '../state.dart';
import '../theme.dart';
import '../utils.dart';

/// The full-screen alert a family member sees when she presses SOS.
/// It vibrates and sounds the siren until it is silenced, follows her live
/// location, and lets them tell her they are responding.
///
/// With [helper] set it is the calmer version for a nearby woman who chose to
/// help: no siren, no vibration.
///
/// On a locked phone it is opened by the push notification's full-screen
/// intent (see services/push_service.dart). It can be previewed from Settings.
class FamilyAlertPage extends StatefulWidget {
  const FamilyAlertPage({
    super.key,
    required this.name,
    required this.phone,
    this.sosId,
    this.lat,
    this.lng,
    this.helper = false,
  });

  final String name;
  final String phone;
  final String? sosId;
  final double? lat;
  final double? lng;
  final bool helper;

  @override
  State<FamilyAlertPage> createState() => _FamilyAlertPageState();
}

class _FamilyAlertPageState extends State<FamilyAlertPage>
    with SingleTickerProviderStateMixin {
  // Own instance so closing this screen never stops a siren elsewhere.
  final _alerts = AlertService();
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  SafetyBackend? _backend;
  StreamSubscription<({double lat, double lng})>? _locSub;
  StreamSubscription<bool>? _activeSub;

  double? _lat;
  double? _lng;
  late bool _silenced = widget.helper;
  bool _responding = false;
  bool _ended = false;

  @override
  void initState() {
    super.initState();
    _lat = widget.lat;
    _lng = widget.lng;
    if (!widget.helper) {
      _alerts.startSiren();
      _alerts.startVibration();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _connect());
  }

  void _connect() {
    final id = widget.sosId;
    if (id == null || !mounted) return;
    final backend = _backend = context.read<AppState>().backend;

    // Opening the screen tells her "saw your alert".
    backend
        .respond(id, ResponderStatus.seen, nearby: widget.helper)
        .catchError((_) {});

    _locSub = backend.liveLocation(id).listen((p) {
      if (mounted) {
        setState(() {
          _lat = p.lat;
          _lng = p.lng;
        });
      }
    }, onError: (_) {});

    _activeSub = backend.isSosActive(id).listen((active) {
      if (!active) _onEnded();
    }, onError: (_) {});
  }

  Future<void> _onEnded() async {
    await _alerts.stopAll();
    if (mounted) {
      setState(() {
        _ended = true;
        _silenced = true;
      });
    }
  }

  @override
  void dispose() {
    _locSub?.cancel();
    _activeSub?.cancel();
    _pulse.dispose();
    _alerts.stopAll();
    super.dispose();
  }

  Future<void> _silence() async {
    await _alerts.stopAll();
    if (mounted) setState(() => _silenced = true);
  }

  Future<void> _onMyWay() async {
    setState(() => _responding = true);
    final id = widget.sosId;
    if (id != null) {
      await _backend
          ?.respond(id, ResponderStatus.onTheWay, nearby: widget.helper)
          .catchError((_) {});
    }
  }

  Future<void> _call() async {
    final id = widget.sosId;
    if (id != null && !widget.helper) {
      _backend?.respond(id, ResponderStatus.calling).catchError((_) {});
    }
    await dial(widget.phone);
  }

  @override
  Widget build(BuildContext context) {
    final lat = _lat;
    final lng = _lng;
    final title = _ended
        ? '${widget.name.toUpperCase()} IS SAFE NOW'
        : widget.helper
            ? 'A WOMAN NEARBY NEEDS HELP'
            : '${widget.name.toUpperCase()} IS IN DANGER';
    final subtitle = _ended
        ? 'She marked herself safe. Thank you for responding.'
        : widget.helper
            ? 'Only go if it is safe. Otherwise call 112.'
            : 'She needs help right now.';

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final bg = _ended
            ? const Color(0xFF166534)
            : Color.lerp(
                const Color(0xFFB91C1C),
                const Color(0xFF7F1D1D),
                _pulse.value,
              )!;
        return Scaffold(backgroundColor: bg, body: child);
      },
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            children: [
              const Spacer(),
              ScaleTransition(
                scale: Tween(begin: 0.92, end: 1.08).animate(_pulse),
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _ended ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                    size: 72,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                _ended ? 'ALL CLEAR' : 'EMERGENCY',
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: Palette.rose, size: 30),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _ended ? 'Last known location' : 'Live location',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Palette.plum,
                            ),
                          ),
                          Text(
                            lat == null || lng == null
                                ? 'Waiting for her location…'
                                : '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                            style: const TextStyle(color: Palette.muted),
                          ),
                        ],
                      ),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onPressed:
                          lat == null || lng == null ? null : () => openMapAt(lat, lng),
                      child: const Text('Open map'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (!_ended)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _responding
                      ? Container(
                          key: const ValueKey('responding'),
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Palette.green,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle, color: Colors.white),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  '${widget.name} can see you are on the way',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : FilledButton(
                          key: const ValueKey('onmyway'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Palette.green,
                            minimumSize: const Size.fromHeight(60),
                          ),
                          onPressed: _onMyWay,
                          child: const Text("I'm on my way"),
                        ),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                      ),
                      onPressed: widget.helper
                          ? () => dial('112')
                          : (widget.phone.isEmpty ? null : _call),
                      icon: const Icon(Icons.call),
                      label: Text(widget.helper ? 'Call 112' : 'Call ${widget.name}'),
                    ),
                  ),
                  if (!widget.helper) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                        ),
                        onPressed: _silenced ? null : _silence,
                        icon: const Icon(Icons.volume_off),
                        label: const Text('Silence'),
                      ),
                    ),
                  ],
                ],
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Close',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
