import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/push_service.dart';
import '../state.dart';
import '../theme.dart';
import '../utils.dart';

/// Shows the login screen until she is signed in with her phone number.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.data == null) return const LoginPage();
        return _SignedIn(child: child);
      },
    );
  }
}

class _SignedIn extends StatefulWidget {
  const _SignedIn({required this.child});
  final Widget child;

  @override
  State<_SignedIn> createState() => _SignedInState();
}

class _SignedInState extends State<_SignedIn> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final state = context.read<AppState>();
      await state.onSignedIn();
      await PushService.registerToken(state.backend);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  String? _verificationId;
  int? _resendToken;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _otp.dispose();
    super.dispose();
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = message;
    });
  }

  Future<void> _sendCode() async {
    final name = _name.text.trim();
    final phone = normalizePhone(_phone.text);
    if (name.isEmpty) return _fail('Please enter your name.');
    if (!RegExp(r'^\+\d{10,15}$').hasMatch(phone)) {
      return _fail('Please enter a valid phone number.');
    }
    final app = context.read<AppState>();
    app.update(() => app.userName = name);
    setState(() {
      _busy = true;
      _error = null;
    });
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      forceResendingToken: _resendToken,
      verificationCompleted: (credential) async {
        try {
          await FirebaseAuth.instance.signInWithCredential(credential);
        } catch (_) {}
      },
      verificationFailed: (e) => _fail(e.message ?? 'Could not send the code.'),
      codeSent: (id, token) {
        if (!mounted) return;
        setState(() {
          _verificationId = id;
          _resendToken = token;
          _busy = false;
        });
      },
      codeAutoRetrievalTimeout: (id) => _verificationId = id,
    );
  }

  Future<void> _verify() async {
    final id = _verificationId;
    if (id == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: id,
        smsCode: _otp.text.trim(),
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      _fail(e.message ?? 'That code did not work.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final codeSent = _verificationId != null;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Palette.blush, Palette.blush2],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 40),
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [Palette.rose, Palette.roseDark]),
                ),
                child: const Icon(Icons.shield, color: Colors.white, size: 38),
              ),
              const SizedBox(height: 24),
              const Text(
                'Welcome to SheSafe',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: Palette.plum,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                codeSent
                    ? 'Enter the 6-digit code we sent by SMS.'
                    : 'Sign in with your phone number so your trusted contacts '
                        'can reach you and receive your alerts.',
                style: const TextStyle(color: Palette.muted, fontSize: 15),
              ),
              const SizedBox(height: 28),
              if (!codeSent) ...[
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Your name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    hintText: '98765 43210',
                    prefixText: '+91  ',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
              ] else
                TextField(
                  controller: _otp,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: '6-digit code',
                    prefixIcon: Icon(Icons.sms_outlined),
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Palette.roseDark)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : (codeSent ? _verify : _sendCode),
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                      )
                    : Text(codeSent ? 'Verify and continue' : 'Send code'),
              ),
              if (codeSent)
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _verificationId = null;
                            _otp.clear();
                          }),
                  child: const Text('Use a different number'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
