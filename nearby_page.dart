import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/nearby_alert_sheet.dart';

class NearbyPage extends StatelessWidget {
  const NearbyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Nearby'),
          bottom: const TabBar(
            labelColor: Palette.rose,
            indicatorColor: Palette.rose,
            unselectedLabelColor: Palette.muted,
            tabs: [Tab(text: 'Help nearby'), Tab(text: 'Nearby women')],
          ),
        ),
        body: const TabBarView(children: [_HelpTab(), _UsersTab()]),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Help nearby: opens Google Maps searches around her current location
// -----------------------------------------------------------------------------
class _Help {
  const _Help(this.title, this.icon, this.query, this.phone);
  final String title;
  final IconData icon;
  final String query;
  final String? phone;
}

const _helps = [
  _Help('Police station', Icons.local_police, 'police station near me', '100'),
  _Help('Hospital', Icons.local_hospital, 'hospital near me', '102'),
  _Help('Women help desk', Icons.support_agent, 'women help desk near me', '1091'),
  _Help('24-hour pharmacy', Icons.local_pharmacy, '24 hour pharmacy near me', null),
];

class _HelpTab extends StatelessWidget {
  const _HelpTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        for (final h in _helps)
          SoftCard(
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Palette.blush2,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(h.icon, color: Palette.rose),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    h.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Palette.plum,
                    ),
                  ),
                ),
                if (h.phone != null)
                  IconButton(
                    tooltip: 'Call ${h.phone}',
                    icon: const Icon(Icons.call, color: Palette.green),
                    onPressed: () => dial(h.phone!),
                  ),
                IconButton(
                  tooltip: 'Find on map',
                  icon: const Icon(Icons.directions, color: Palette.blue),
                  onPressed: () => openMapSearch(h.query),
                ),
              ],
            ),
          ),
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(
            'The map button opens Google Maps with the closest results to where you are.',
            style: TextStyle(color: Palette.muted, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Nearby women: settings for the nearby-alert network
// -----------------------------------------------------------------------------
class _UsersTab extends StatelessWidget {
  const _UsersTab();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        const SoftCard(child: _Radar()),
        SoftCard(
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Alert nearby women when I send SOS',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                value: s.alertNearbyUsers,
                onChanged: (v) => s.update(() => s.alertNearbyUsers = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Alert me when someone nearby needs help',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                value: s.receiveNearbyAlerts,
                onChanged: (v) => s.update(() => s.receiveNearbyAlerts = v),
              ),
              const Divider(),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Alert radius',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    radiusLabel(s.nearbyRadiusM),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Palette.rose,
                    ),
                  ),
                ],
              ),
              Slider(
                min: 200,
                max: 3000,
                divisions: 14,
                value: s.nearbyRadiusM.clamp(200.0, 3000.0).toDouble(),
                onChanged: (v) => s.update(() => s.nearbyRadiusM = v),
              ),
            ],
          ),
        ),
        const SoftCard(
          color: Palette.blush2,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline, color: Palette.roseDark),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Privacy: nearby women only see roughly how far away you '
                  'are. Your exact location is shared only if they tap '
                  '"I can help".',
                  style: TextStyle(color: Palette.plum),
                ),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => showNearbyAlertSheet(context),
          icon: const Icon(Icons.notifications_active_outlined),
          label: const Text('Preview a nearby alert'),
        ),
      ],
    );
  }
}

class _Radar extends StatefulWidget {
  const _Radar();

  @override
  State<_Radar> createState() => _RadarState();
}

class _RadarState extends State<_Radar> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          AspectRatio(
            aspectRatio: 1.5,
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => CustomPaint(painter: _RadarPainter(_c.value)),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sample radar. Real nearby women appear here once the SheSafe server is connected.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Palette.muted, fontSize: 12),
          ),
        ],
      );
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(this.t);
  final double t;

  // angle (radians), distance as a fraction of the radius
  static const _dots = [(0.9, 0.45), (2.4, 0.7), (4.0, 0.3), (5.2, 0.85)];

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final maxR = math.min(size.width, size.height) / 2 - 4;

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Palette.rose.withValues(alpha: 0.25);
    for (var i = 1; i <= 3; i++) {
      canvas.drawCircle(c, maxR * i / 3, ring);
    }

    final rect = Rect.fromCircle(center: c, radius: maxR);
    final sweep = Paint()
      ..shader = SweepGradient(
        colors: [
          Palette.rose.withValues(alpha: 0),
          Palette.rose.withValues(alpha: 0.35),
        ],
        transform: GradientRotation(t * 2 * math.pi),
      ).createShader(rect);
    canvas.drawCircle(c, maxR, sweep);

    final dot = Paint()..color = Palette.rose;
    for (final (angle, f) in _dots) {
      final p = c + Offset(math.cos(angle), math.sin(angle)) * (maxR * f);
      canvas.drawCircle(p, 6, dot);
    }
    canvas.drawCircle(c, 8, Paint()..color = Palette.plum);
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.t != t;
}
