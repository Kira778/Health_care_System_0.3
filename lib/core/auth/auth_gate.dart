import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../presentation/screens/login/login_screen.dart';
import '../../presentation/screens/main_layout.dart';

/// ════════════════════════════════════════════════════════════
/// AuthGate — Custom Auth (No Supabase Session)
///
/// يعتمد على SharedPreferences أو local state بسبب غياب
/// Supabase Auth Session. هنستخدم approach بسيط:
///   - لما المستخدم يعمل login → نخزّن userEmail في memory
///   - AuthGate يبدأ بـ LoginScreen دايماً (cold start)
/// ════════════════════════════════════════════════════════════
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // Custom auth — ابدأ بـ LoginScreen دائماً
    // LoginScreen هي اللي بتروّح للـ MainLayout بعد تسجيل الدخول
    return const LoginScreen();
  }
}