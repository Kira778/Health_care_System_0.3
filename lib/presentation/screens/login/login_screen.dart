import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main_layout.dart';
import 'register_screen.dart';

/// ════════════════════════════════════════════════════════════
/// LoginScreen — Custom Auth via profiles table
///
/// يتحقق من email + password في جدول profiles
/// ثم يتحقق إن المستخدم عنده جهاز مفعّل
/// ════════════════════════════════════════════════════════════
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {

  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading        = false;
  bool _obscure        = true;
  String? _error;

  late final AnimationController _animCtrl;
  late final Animation<double>   _fadeAnim;
  late final Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 700));
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email    = _emailCtrl.text.trim().toLowerCase();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'الرجاء ملء جميع الحقول');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      // 1. تحقق من بيانات الدخول في profiles
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('id, full_name, email, serial_number, device_id')
          .eq('email', email)
          .eq('passwords', password)
          .maybeSingle();

      if (profile == null) {
        setState(() => _error = 'البريد الإلكتروني أو كلمة المرور غير صحيحة');
        return;
      }

      // 2. تحقق إن الجهاز لسه مفعّل
      final device = await Supabase.instance.client
          .from('sensor_devices')
          .select('*')
          .eq('serial_number', profile['serial_number'])
          .maybeSingle();

      if (device == null || device['is_assigned'] != true) {
        setState(() => _error = 'الجهاز المرتبط بحسابك غير مفعّل، تواصل مع الدعم');
        return;
      }

      // 3. ✅ تسجيل دخول ناجح
      if (!mounted) return;
      Navigator.pushReplacement(context, PageRouteBuilder(
        pageBuilder: (_, __, ___) => MainLayout(
          userDevice: device,
          userName:   profile['full_name'] as String?,
          userEmail:  profile['email'] as String,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ));

    } on PostgrestException catch (e) {
      setState(() => _error = 'خطأ في قاعدة البيانات: ${e.message}');
    } catch (e) {
      setState(() => _error = 'خطأ في الاتصال، حاول مرة أخرى');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              // 🎯 اللون الأساسي
              // حطه فوق في الكلاس عندك:
              // const primaryColor = Color(0xFF1565C0);

              // ── Top Header ──────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 40, 20, 40),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(40),
                    bottomRight: Radius.circular(40),
                  ),
                ),
                child: Column(
                  children: [

                    // 🔥 Logo (دائري زي ما كان)
                    ScaleTransition(
                      scale: Tween<double>(begin: 0.8, end: 1).animate(
                        CurvedAnimation(
                          parent: _animCtrl,
                          curve: Curves.easeOutBack,
                        ),
                      ),
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFFFFF), Color(0xFFE3F2FD)],
                            ),
                          ),
                          child: ClipOval(
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Image.asset(
                                'assets/images/applogo.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    FadeTransition(
                      opacity: _fadeAnim,
                      child: const Text(
                        'HealthCare System',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(height: 6),

                    FadeTransition(
                      opacity: _fadeAnim,
                      child: Text(
                        'نظام رعاية صحية ذكي',
                        style: TextStyle(
                          color: Color(0xFFBBDEFB),
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Form ────────────────────────────
              SlideTransition(
                position: _slideAnim,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
                    child: Column(
                      children: [

                        Text(
                          'تسجيل الدخول',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1565C0),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Email (زي ما هو)
                        _inputField(
                          ctrl: _emailCtrl,
                          label: 'البريد الإلكتروني',
                          icon: Icons.email_outlined,
                          type: TextInputType.emailAddress,
                        ),

                        const SizedBox(height: 14),

                        // 🔐 Password بعد التعديل
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              )
                            ],
                          ),
                          child: TextField(
                            controller: _passwordCtrl,
                            obscureText: _obscure,
                            decoration: InputDecoration(
                              labelText: 'كلمة المرور',
                              labelStyle: TextStyle(color: Colors.grey[600]),

                              prefixIcon: const Icon(
                                Icons.lock_outline,
                                color: Color(0xFF1565C0),
                              ),

                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: Colors.grey[500],
                                ),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),

                              filled: true,
                              fillColor: Colors.grey[50],

                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),

                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                BorderSide(color: Colors.grey[300]!),
                              ),

                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFF1565C0),
                                  width: 2,
                                ),
                              ),

                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 18),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // 🔥 زرار Login بعد التعديل
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1565C0),
                              disabledBackgroundColor:
                              const Color(0xFF1565C0).withOpacity(0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 3,
                            ),
                            child: _loading
                                ? const CircularProgressIndicator(
                                color: Colors.white)
                                : const Text(
                              'تسجيل الدخول',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Register
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('ليس لديك حساب؟ ',
                                style: TextStyle(color: Colors.grey[600])),
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const RegisterScreen()),
                              ),
                              child: const Text(
                                'إنشاء حساب جديد',
                                style: TextStyle(
                                  color: Color(0xFF1565C0),
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inputField({required TextEditingController ctrl, required String label,
    required IconData icon, TextInputType type = TextInputType.text}) =>
      Container(
        decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1),
                blurRadius: 8, offset: const Offset(0, 3))]),
        child: TextField(
          controller: ctrl, keyboardType: type,
          decoration: InputDecoration(
            labelText: label, labelStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            prefixIcon: Icon(icon, color: Colors.blue[600], size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.blue[100]!)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.blue[600]!, width: 2)),
            filled: true, fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
          ),
          onChanged: (_) { if (_error != null) setState(() => _error = null); },
        ),
      );
}