import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_nav.dart';
import 'pages/auth_gate.dart';
import 'pages/shell.dart';
import 'services/backend.dart';
import 'services/firebase_backend.dart';
import 'services/push_service.dart';
import 'state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // If Firebase is not set up yet (no google-services.json), the app still
  // runs in demo mode so the screens can be tried.
  SafetyBackend? backend;
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
    backend = FirebaseBackend();
  } catch (e) {
    debugPrint('Firebase is not set up, running in demo mode: $e');
  }

  final state = AppState(backend: backend);
  await state.load();
  runApp(
    ChangeNotifierProvider.value(value: state, child: const SheSafeApp()),
  );
  if (backend != null) unawaited(PushService.init());
}

class SheSafeApp extends StatelessWidget {
  const SheSafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final demo = context.read<AppState>().backend.isDemo;
    return MaterialApp(
      title: 'SheSafe',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      navigatorKey: navigatorKey,
      home: demo ? const Shell() : const AuthGate(child: Shell()),
    );
  }
}
