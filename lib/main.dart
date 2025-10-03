import 'package:fidh_ai/firebase_options.dart';
import 'package:fidh_ai/screens/auth_gate.dart';
import 'package:fidh_ai/theme/dark_theme.dart'; // <-- Impor tema baru
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FIDH - AI',
      debugShowCheckedModeBanner: false,
      theme: buildDarkTheme(), // <-- Terapkan tema baru di sini
      home: const AuthGate(),
    );
  }
}
