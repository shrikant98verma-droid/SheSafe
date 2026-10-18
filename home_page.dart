import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../utils.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: s.sosActive
                ? const [Color(0xFFFFE4E6), Color(0xFFFFC2CC)]
                : const [Palette.blush, Palette.blush2],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 12),
                const _Header(),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: s.sosActive
                        ? const _ActiveSos(key: ValueKey('active'))
                        : const _Idle(key: ValueKey('idle')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final demo = context.read<AppState>().backend.isDemo;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [Palette.rose, Palette.roseDark]),
          ),
          child: const Icon(Icons.shield, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        const Text(
          'SheSafe',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Palette.plum,
            letterSpacing: -0.5,
          ),
        ),
        const Spacer(),
        if (demo)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Palette.amber.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'DEMO MODE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF92400E),
                letterSpacing: 1,
              ),
            ),
          ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Idle: just the SOS button
// -----------------------------------------------------------------------------
class _Idle extends StatelessWidget {
  const _Idle({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SosButton(),
          const SizedBox(height: 24),
          Text(
            'Press and hold for ${s.holdSeconds} seconds',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Palette.plum.withValues(alpha: 0.75),
            ),
          ),
          if (s.contacts.isEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Add a trusted contact first, in the Contacts tab.',
              style: TextStyle(fontSize: 13, color: Palette.muted),
            ),
          ],
        ],
      ),
    );
  }
}

/// Big pulsing SOS button. It has to be held so it cannot be sent by accident;
/// a ring fills up while she holds it.
class SosButton extends StatefulWidget {
  const SosButton({super.key});

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton> with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _hold;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _hold = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _hold.addStatusListener((status) {
      if (status == AnimationStatus.completed) _fire();
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    _hold.dispose();
    super.dispose();
  }

  void _fire() {
    final state = context.read<AppState>();
    HapticFeedback.heavyImpact();
    _hold.value = 0;
    if (state.contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one trusted contact first.')),
      );
      return;
    }
    state.triggerSos();
  }

  void _down(TapDownDetails _) {
    _hold.duration = Duration(seconds: context.read<AppState>().holdSeconds);
    HapticFeedback.selectionClick();
    _hold.forward(from: 0);
  }

  void _release() {
    if (_hold.status != AnimationStatus.completed) _hold.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'SOS. Press and hold to send an emergency alert.',
      child: GestureDetector(
        onTapDown: _down,
        onTapUp: (_) => _release(),
        onTapCancel: _release,
        child: SizedBox(
          width: 300,
          height: 300,
          child: AnimatedBuilder(
            animation: Listenable.merge([_pulse, _hold]),
            builder: (context, _) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(300, 300),
                    painter: _RingsPainter(_pulse.value),
                  ),
                  SizedBox(
                    width: 252,
                    height: 252,
                    child: CircularProgressIndicator(
                      value: _hold.value,
                      strokeWidth: 8,
                      color: Palette.roseDark,
                      backgroundColor: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                  Transform.scale(
                    scale: 1 - 0.04 * _hold.value,
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          center: Alignment(-0.3, -0.4),
                          colors: [Color(0xFFFF4D6D), Palette.rose, Palette.roseDark],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Palette.rose.withValues(alpha: 0.45),
                            blurRadius: 36,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'SOS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 54,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 4,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'HOLD',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    for (var i = 0; i < 3; i++) {
      final p = (t + i / 3) % 1.0;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Palette.rose.withValues(alpha: (1 - p) * 0.35);
      canvas.drawCircle(c, 110 + 40 * p, paint);
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) => old.t != t;
}

// -----------------------------------------------------------------------------
// Active SOS: who is responding, location, stop button
// -----------------------------------------------------------------------------
class _ActiveSos extends StatelessWidget {
  const _ActiveSos({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return ListView(
      padding: const EdgeInsets.only(top: 16, bottom: 24),
      children: [
        _StatusBanner(responders: s.responders),
        const SizedBox(height: 12),
        _LocationCard(state: s),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Your people',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Palette.plum,
                      ),
                    ),
                  ),
                  if (s.sosStartedAt != null) _Elapsed(since: s.sosStartedAt!),
                ],
              ),
              const SizedBox(height: 4),
              for (final r in s.responders) _ResponderTile(r),
            ],
          ),
        ),
        if (s.nearbyNotified > 0)
          SoftCard(
            child: Row(
              children: [
                const Icon(Icons.radar, color: Palette.rose),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${s.nearbyNotified} SheSafe users nearby were alerted '
                    '(within ${radiusLabel(s.nearbyRadiusM)}).',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        SoftCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Siren on my phone',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            value: s.alerts.sirenOn,
            onChanged: (_) => s.toggleSiren(),
          ),
        ),
        if (s.backend.isDemo)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Demo mode: nobody is actually being alerted.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF92400E),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        OutlinedButton.icon(
          onPressed: () => dial('112'),
          icon: const Icon(Icons.call),
          label: const Text('Call 112'),
        ),
        const SizedBox(height: 12),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Palette.green),
          onPressed: () => _confirmSafe(context, s),
          child: const Text("I'm safe, stop SOS"),
        ),
      ],
    );
  }

  Future<void> _confirmSafe(BuildContext context, AppState s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Are you safe?'),
        content: const Text(
          'Stopping will end live location sharing and the siren.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not yet'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Yes, I'm safe"),
          ),
        ],
      ),
    );
    if (ok == true) await s.endSos();
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.responders});
  final List<Responder> responders;

  @override
  Widget build(BuildContext context) {
    Responder? lead;
    for (final r in responders) {
      if (lead == null || r.status.index > lead.status.index) lead = r;
    }

    final String title;
    final String sub;
    final Color color;
    final IconData icon;
    switch (lead?.status) {
      case ResponderStatus.calling:
        title = '${lead!.name} is calling you';
        sub = 'Pick up when you can.';
        color = Palette.green;
        icon = Icons.call;
      case ResponderStatus.onTheWay:
        title = '${lead!.name} is on the way';
        sub = 'They can see your live location.';
        color = Palette.green;
        icon = Icons.directions_run;
      case ResponderStatus.seen:
        title = '${lead!.name} saw your alert';
        sub = 'Waiting for them to respond.';
        color = Palette.blue;
        icon = Icons.visibility;
      default:
        title = 'SOS sent';
        sub = 'Waiting for someone to respond.';
        color = Palette.rose;
        icon = Icons.sos;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(sub, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final pos = state.position;
    final String text;
    final Color color;
    if (state.locationDenied) {
      text = 'Location is off. Turn it on so your people can find you.';
      color = Palette.amber;
    } else if (pos == null) {
      text = 'Finding your location…';
      color = Palette.muted;
    } else {
      text = 'Sharing live location (±${pos.accuracy.round()} m)';
      color = Palette.green;
    }
    return SoftCard(
      child: Row(
        children: [
          Icon(Icons.my_location, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _ResponderTile extends StatelessWidget {
  const _ResponderTile(this.r);
  final Responder r;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (r.status) {
      ResponderStatus.notified => (Icons.check, Palette.muted),
      ResponderStatus.seen => (Icons.visibility, Palette.blue),
      ResponderStatus.onTheWay => (Icons.directions_run, Palette.green),
      ResponderStatus.calling => (Icons.call, Palette.green),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Palette.blush2,
            child: Text(
              r.name.isEmpty ? '?' : r.name[0].toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Palette.roseDark,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Palette.plum,
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    r.status.label,
                    key: ValueKey(r.status),
                    style: TextStyle(color: color, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: color),
          ),
        ],
      ),
    );
  }
}

class _Elapsed extends StatefulWidget {
  const _Elapsed({required this.since});
  final DateTime since;

  @override
  State<_Elapsed> createState() => _ElapsedState();
}

class _ElapsedState extends State<_Elapsed> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(
        mmss(DateTime.now().difference(widget.since)),
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Palette.roseDark,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      );
}
