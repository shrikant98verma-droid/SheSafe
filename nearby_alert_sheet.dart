import 'package:flutter/material.dart';

import '../pages/family_alert_page.dart';
import '../theme.dart';
import '../utils.dart';

/// What another SheSafe user sees when a woman near her presses SOS.
/// It is deliberately calmer than the family alert and hides her location
/// until she agrees to help. With no [sosId] it is only a preview.
Future<void> showNearbyAlertSheet(
  BuildContext context, {
  String? sosId,
  String distanceText = 'About 300 m away',
}) {
  final nav = Navigator.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Palette.amber.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.campaign, size: 38, color: Palette.amber),
          ),
          const SizedBox(height: 16),
          const Text(
            'A woman near you may need help',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Palette.plum,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            distanceText,
            style: const TextStyle(
              color: Palette.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Her exact location is shared only if you tap "I can help". '
            'If you are not safe to approach, call 112 instead.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Palette.plum),
          ),
          const SizedBox(height: 24),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Palette.green),
            onPressed: () {
              Navigator.pop(ctx);
              if (sosId == null) {
                messenger?.showSnackBar(
                  const SnackBar(
                    content: Text('Preview only. In a real alert, her live location opens now.'),
                  ),
                );
                return;
              }
              nav.push(MaterialPageRoute<void>(
                fullscreenDialog: true,
                builder: (_) => FamilyAlertPage(
                  name: 'A woman nearby',
                  phone: '',
                  sosId: sosId,
                  helper: true,
                ),
              ));
            },
            child: const Text('I can help'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => dial('112'),
            icon: const Icon(Icons.call),
            label: const Text('Call 112'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Not now'),
          ),
        ],
      ),
    ),
  );
}
