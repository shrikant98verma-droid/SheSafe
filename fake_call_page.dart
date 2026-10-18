import 'dart:async';

import 'package:flutter/material.dart';

import '../services/alert_service.dart';
import '../utils.dart';

/// Looks like an incoming phone call so she can leave an uncomfortable
/// situation without explaining.
class FakeCallPage extends StatefulWidget {
  const FakeCallPage({super.key, required this.caller});
  final String caller;

  @override
  State<FakeCallPage> createState() => _FakeCallPageState();
}

class _FakeCallPageState extends State<FakeCallPage> {
  final _alerts = AlertService();
  bool _connected = false;
  Duration _elapsed = Duration.zero;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _alerts.startVibration();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _alerts.stopVibration();
    super.dispose();
  }

  void _accept() {
    _alerts.stopVibration();
    setState(() => _connected = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  void _end() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final initial = widget.caller.isEmpty ? '?' : widget.caller[0].toUpperCase();
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF334155)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 72),
              Text(
                _connected ? mmss(_elapsed) : 'Incoming call',
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 28),
              CircleAvatar(
                radius: 56,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                widget.caller,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 6),
              const Text('mobile', style: TextStyle(color: Colors.white60)),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 64),
                child: _connected
                    ? _RoundButton(
                        color: const Color(0xFFEF4444),
                        icon: Icons.call_end,
                        label: 'End',
                        onTap: _end,
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _RoundButton(
                            color: const Color(0xFFEF4444),
                            icon: Icons.call_end,
                            label: 'Decline',
                            onTap: _end,
                          ),
                          _RoundButton(
                            color: const Color(0xFF22C55E),
                            icon: Icons.call,
                            label: 'Accept',
                            onTap: _accept,
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white70)),
        ],
      );
}
