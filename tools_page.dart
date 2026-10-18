import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state.dart';
import '../theme.dart';
import '../utils.dart';
import 'fake_call_page.dart';

class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final remaining = s.checkInRemaining;
    return Scaffold(
      appBar: AppBar(title: const Text('Safety tools')),
      body: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.05,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          _Tile(
            icon: Icons.phone_in_talk,
            color: Palette.blue,
            title: 'Fake call',
            subtitle: 'Get out of a situation',
            onTap: () => _fakeCallSheet(context),
          ),
          _Tile(
            icon: Icons.volume_up,
            color: Palette.rose,
            title: 'Siren',
            subtitle: s.alerts.sirenOn ? 'On. Tap to stop' : 'Loud alarm',
            active: s.alerts.sirenOn,
            onTap: s.toggleSiren,
          ),
          _Tile(
            icon: Icons.share_location,
            color: Palette.green,
            title: 'Share location',
            subtitle: 'Send to contacts by SMS',
            onTap: () => _shareLocation(context),
          ),
          _Tile(
            icon: Icons.timer_outlined,
            color: Palette.amber,
            title: 'Safe check-in',
            subtitle: remaining == null
                ? 'SOS if you do not arrive'
                : 'Ends in ${mmss(remaining)}',
            active: remaining != null,
            onTap: () => _checkInSheet(context),
          ),
          _Tile(
            icon: Icons.emergency,
            color: Palette.roseDark,
            title: 'Emergency numbers',
            subtitle: 'Police, ambulance, helplines',
            onTap: () => _numbersSheet(context),
          ),
          _Tile(
            icon: Icons.call,
            color: Palette.plum,
            title: 'Call 112',
            subtitle: 'National emergency',
            onTap: () => dial('112'),
          ),
        ],
      ),
    );
  }

  // ---- fake call ------------------------------------------------------------
  void _fakeCallSheet(BuildContext context) {
    final nav = Navigator.of(context);
    final caller = context.read<AppState>().fakeCallerName;

    void ring(int delaySeconds) async {
      Navigator.pop(context);
      if (delaySeconds > 0) {
        await Future<void>.delayed(Duration(seconds: delaySeconds));
      }
      nav.push(MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => FakeCallPage(caller: caller),
      ));
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fake call from $caller',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Palette.plum,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Change the caller name in Settings.',
              style: TextStyle(color: Palette.muted),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: () => ring(0), child: const Text('Ring now')),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => ring(10),
              child: const Text('Ring in 10 seconds'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => ring(30),
              child: const Text('Ring in 30 seconds'),
            ),
          ],
        ),
      ),
    );
  }

  // ---- share location by SMS -------------------------------------------------
  Future<void> _shareLocation(BuildContext context) async {
    final s = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    if (s.contacts.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Add a trusted contact first.')),
      );
      return;
    }
    final ok = await s.location.ensurePermission();
    final pos = ok ? await s.location.current() : null;
    if (pos == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not get your location. Is GPS on?')),
      );
      return;
    }
    await sendSms(
      s.contacts.map((c) => c.phone).toList(),
      "I'm sharing my location with you from SheSafe: "
      'https://www.google.com/maps/search/?api=1&query=${pos.latitude},${pos.longitude}',
    );
  }

  // ---- check-in ---------------------------------------------------------------
  void _checkInSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => const _CheckInSheet(),
    );
  }

  // ---- emergency numbers --------------------------------------------------------
  void _numbersSheet(BuildContext context) {
    const numbers = [
      ('112', 'National emergency number'),
      ('100', 'Police'),
      ('1091', 'Women helpline'),
      ('181', 'Women helpline (domestic abuse)'),
      ('102', 'Ambulance'),
      ('1098', 'Childline'),
    ];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Emergency numbers (India)',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Palette.plum,
                  ),
                ),
              ),
            ),
            for (final (number, label) in numbers)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Palette.blush2,
                  child: const Icon(Icons.call, color: Palette.rose, size: 20),
                ),
                title: Text(
                  number,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
                subtitle: Text(label),
                onTap: () => dial(number),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      margin: EdgeInsets.zero,
      onTap: onTap,
      color: active ? color.withValues(alpha: 0.12) : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Palette.plum,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Palette.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CheckInSheet extends StatefulWidget {
  const _CheckInSheet();

  @override
  State<_CheckInSheet> createState() => _CheckInSheetState();
}

class _CheckInSheetState extends State<_CheckInSheet> {
  int _minutes = 30;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final remaining = s.checkInRemaining;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Safe check-in',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Palette.plum,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'If you do not tap "I arrived safely" before the timer ends, SOS is '
            'sent automatically.',
            style: TextStyle(color: Palette.muted),
          ),
          const SizedBox(height: 20),
          if (remaining == null) ...[
            Wrap(
              spacing: 8,
              children: [
                for (final m in const [15, 30, 60, 120])
                  ChoiceChip(
                    label: Text(m < 60 ? '$m min' : '${m ~/ 60} hr'),
                    selected: _minutes == m,
                    onSelected: (_) => setState(() => _minutes = m),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                s.startCheckIn(_minutes);
                Navigator.pop(context);
              },
              child: const Text('Start check-in'),
            ),
          ] else ...[
            Center(
              child: Text(
                mmss(remaining),
                style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                  color: Palette.amber,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Palette.green),
              onPressed: () {
                s.cancelCheckIn();
                Navigator.pop(context);
              },
              child: const Text('I arrived safely'),
            ),
          ],
        ],
      ),
    );
  }
}
