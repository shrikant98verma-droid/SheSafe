import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/nearby_alert_sheet.dart';
import 'family_alert_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          const SectionLabel('Profile'),
          SoftCard(
            child: Column(
              children: [
                TextFormField(
                  initialValue: s.userName == 'Me' ? '' : s.userName,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Your name (shown in alerts)',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  onChanged: (v) => s.update(
                    () => s.userName = v.trim().isEmpty ? 'Me' : v.trim(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: s.fakeCallerName,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Fake call: caller name',
                    prefixIcon: Icon(Icons.phone_in_talk_outlined),
                  ),
                  onChanged: (v) => s.update(
                    () => s.fakeCallerName = v.trim().isEmpty ? 'Mom' : v.trim(),
                  ),
                ),
              ],
            ),
          ),
          const SectionLabel('SOS'),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hold the button for',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 1, label: Text('1 sec')),
                      ButtonSegment(value: 2, label: Text('2 sec')),
                      ButtonSegment(value: 3, label: Text('3 sec')),
                    ],
                    selected: {s.holdSeconds},
                    onSelectionChanged: (v) =>
                        s.update(() => s.holdSeconds = v.first),
                  ),
                ),
                const Divider(height: 28),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Siren on my phone during SOS',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Off by default. A loud siren can scare someone off in public '
                    'but may put you at risk if you are hiding.',
                  ),
                  value: s.sirenOnSos,
                  onChanged: (v) => s.update(() => s.sirenOnSos = v),
                ),
              ],
            ),
          ),
          const SectionLabel('Nearby alerts'),
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
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Radius',
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
          const SectionLabel('Try it out'),
          SoftCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.warning_amber_rounded, color: Palette.rose),
                  title: const Text('Preview the family alert'),
                  subtitle: const Text('What your contacts see with siren and vibration'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      fullscreenDialog: true,
                      builder: (_) => FamilyAlertPage(
                        name: s.userName == 'Me' ? 'Priya' : s.userName,
                        phone: s.contacts.isNotEmpty ? s.contacts.first.phone : '',
                        lat: s.position?.latitude ?? 28.6139,
                        lng: s.position?.longitude ?? 77.2090,
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.campaign_outlined, color: Palette.amber),
                  title: const Text('Preview a nearby alert'),
                  subtitle: const Text('What other SheSafe users near you see'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showNearbyAlertSheet(context),
                ),
              ],
            ),
          ),
          const SectionLabel('About'),
          SoftCard(
            child: Text(
              s.backend.isDemo
                  ? 'SheSafe 0.1.0 · Demo mode. Alerts are simulated on this phone '
                      'and nothing is sent to anyone until the SheSafe server is '
                      'connected. Do not rely on this build in a real emergency. '
                      'Call 112.'
                  : 'SheSafe 0.1.0',
              style: const TextStyle(color: Palette.plum),
            ),
          ),
        ],
      ),
    );
  }
}
