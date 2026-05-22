import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'presentation/screens/login/login_screen.dart';
import 'presentation/screens/main_layout.dart';
import 'core/auth/auth_gate.dart';
import 'core/theme/theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://amnojexqosxdsjzgrmtf.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFtbm9qZXhxb3N4ZHNqemdybXRmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY2ODA3NjYsImV4cCI6MjA5MjI1Njc2Nn0.5oPqEzpibbaz8ccAX4CmLX9dre6wJ0WsDz0T4CUyQeY',
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: mode,
          home: AuthGate(),
        );
      },
    );
  }
}
