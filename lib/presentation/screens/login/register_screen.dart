import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ════════════════════════════════════════════════════════════
/// RegisterScreen — 2-Step Flow
///
/// Step 1: إدخال السيريال + التحقق من الداتا بيز
/// Step 2: ملء البيانات الشخصية + إنشاء الحساب
///
/// Logic:
///   ✓ بدون Supabase Auth.signUp → لا email rate limit
///   ✓ INSERT مباشر في profiles بـ UUID محلي
///   ✓ UPDATE sensor_devices → is_assigned=true, assigned_to=profile.id
/// ════════════════════════════════════════════════════════════
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {

  // ── Controllers ──────────────────────────────────────────
  final _serialCtrl       = TextEditingController();
  final _fullNameCtrl     = TextEditingController();
  final _ageCtrl          = TextEditingController();
  final _emailCtrl        = TextEditingController();
  final _phoneCtrl        = TextEditingController();
  final _passwordCtrl     = TextEditingController();
  final _confirmPassCtrl  = TextEditingController();

  // ── State ────────────────────────────────────────────────
  int     _step           = 1;
  bool    _loadingSerial  = false;
  bool    _loadingReg     = false;
  bool    _obscurePass    = true;
  bool    _obscureConfirm = true;
  String? _serialError;
  String? _formError;
  String? _genderValue;
  Map<String, dynamic>? _device; // بيانات الجهاز بعد التحقق

  final _genderOptions = ['ذكر', 'أنثى', 'أخرى'];

  // ── Animation ────────────────────────────────────────────
  late final AnimationController _fadeCtrl;
  late final AnimationController _slideCtrl;
  late final Animation<double>   _fadeAnim;
  late final Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _fadeAnim  = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose(); _slideCtrl.dispose();
    _serialCtrl.dispose(); _fullNameCtrl.dispose(); _ageCtrl.dispose();
    _emailCtrl.dispose();  _phoneCtrl.dispose();
    _passwordCtrl.dispose(); _confirmPassCtrl.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════
  // STEP 1 — التحقق من السيريال
  // ════════════════════════════════════════════════════════
  Future<void> _checkSerial() async {
    final raw = _serialCtrl.text.trim();
    if (raw.isEmpty) {
      setState(() => _serialError = 'الرجاء إدخال الرقم التسلسلي');
      return;
    }
    final serial = int.tryParse(raw);
    if (serial == null) {
      setState(() => _serialError = 'الرقم التسلسلي أرقام فقط');
      return;
    }

    setState(() { _loadingSerial = true; _serialError = null; });

    try {
      final device = await Supabase.instance.client
          .from('sensor_devices')
          .select('id, serial_number, is_assigned, assigned_to, device_name, device_type')
          .eq('serial_number', serial)
          .maybeSingle();

      if (device == null) {
        setState(() => _serialError = 'الرقم التسلسلي غير موجود في النظام');
        return;
      }
      if (device['is_assigned'] == true || device['assigned_to'] != null) {
        setState(() => _serialError = 'هذا الجهاز مفعّل بالفعل على حساب آخر');
        return;
      }

      // ✅ سيريال صحيح ومتاح
      _device = device;
      _fadeCtrl.reset();
      setState(() => _step = 2);
      _slideCtrl.forward(from: 0);
      _fadeCtrl.forward();

    } catch (e) {
      setState(() => _serialError = 'خطأ في الاتصال، حاول مرة أخرى');
    } finally {
      setState(() => _loadingSerial = false);
    }
  }

  // ════════════════════════════════════════════════════════
  // Helper: توليد UUID صحيح 100%
  // ════════════════════════════════════════════════════════
  String _generateValidUUID() {
    final random = Random();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));

    // تعديل الإصدار (version 4)
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    // تعديل المتغير (variant)
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    return '${_toHex(bytes[0])}${_toHex(bytes[1])}${_toHex(bytes[2])}${_toHex(bytes[3])}-'
        '${_toHex(bytes[4])}${_toHex(bytes[5])}-'
        '${_toHex(bytes[6])}${_toHex(bytes[7])}-'
        '${_toHex(bytes[8])}${_toHex(bytes[9])}-'
        '${_toHex(bytes[10])}${_toHex(bytes[11])}${_toHex(bytes[12])}${_toHex(bytes[13])}${_toHex(bytes[14])}${_toHex(bytes[15])}';
  }

  String _toHex(int value) {
    return value.toRadixString(16).padLeft(2, '0');
  }

  // ════════════════════════════════════════════════════════
  // STEP 2 — إنشاء الحساب (بدون Supabase Auth)
  // ════════════════════════════════════════════════════════
  Future<void> _register() async {
    setState(() => _formError = null);

    final fullName = _fullNameCtrl.text.trim();
    final email    = _emailCtrl.text.trim().toLowerCase();
    final phone    = _phoneCtrl.text.trim();
    final password = _passwordCtrl.text;
    final confirm  = _confirmPassCtrl.text;
    final age      = int.tryParse(_ageCtrl.text.trim());

    // Validations
    if (fullName.isEmpty)                      { _showErr('الرجاء إدخال الاسم الكامل'); return; }
    if (age == null || age < 1 || age > 120)   { _showErr('الرجاء إدخال سن صحيح (1–120)'); return; }
    if (email.isEmpty || !email.contains('@')) { _showErr('بريد إلكتروني غير صحيح'); return; }
    if (password.length < 6)                   { _showErr('كلمة المرور 6 أحرف على الأقل'); return; }
    if (password != confirm)                   { _showErr('كلمات المرور غير متطابقة'); return; }

    setState(() => _loadingReg = true);

    try {
      final serial   = int.parse(_serialCtrl.text.trim());
      final deviceId = _device!['id'] as String;

      // 1. تأكد إن الإيميل مش مكرر
      final emailExists = await Supabase.instance.client
          .from('profiles').select('id').eq('email', email).maybeSingle();
      if (emailExists != null) { _showErr('هذا البريد الإلكتروني مسجل بالفعل'); return; }

      // 2. تأكد إن الجهاز لسه متاح (race condition protection)
      final freshDevice = await Supabase.instance.client
          .from('sensor_devices')
          .select('is_assigned, assigned_to')
          .eq('id', deviceId).single();
      if (freshDevice['is_assigned'] == true || freshDevice['assigned_to'] != null) {
        _showErr('تم تفعيل هذا الجهاز للتو، الرجاء استخدام سيريال آخر');
        return;
      }

      // 3. توليد UUID صحيح للـ profile
      String newId;
      try {
        // محاولة استخدام RPC من قاعدة البيانات
        final res = await Supabase.instance.client.rpc('gen_random_uuid');
        newId = res.toString();
        // التأكد أن الـ UUID صحيح
        if (newId.isEmpty || !_isValidUUID(newId)) {
          throw Exception('Invalid UUID from RPC');
        }
      } catch (_) {
        // Fallback آمن: استخدام دالة توليد UUID صحيحة
        newId = _generateValidUUID();
      }

      // 4. INSERT في profiles
      await Supabase.instance.client.from('profiles').insert({
        'id'           : newId,
        'full_name'    : fullName,
        'email'        : email,
        'passwords'    : password,
        'phone'        : phone.isNotEmpty ? phone : null,
        'age'          : age,
        'gender'       : _genderValue,
        'serial_number': serial,
        'device_id'    : deviceId,
        'created_at'   : DateTime.now().toIso8601String(),
      });

      // 5. UPDATE sensor_devices — ربط الجهاز
      await Supabase.instance.client
          .from('sensor_devices')
          .update({
        'is_assigned': true,
        'assigned_to': newId,
        'assigned_at': DateTime.now().toIso8601String(),
      })
          .eq('id', deviceId);

      if (mounted) _showSuccess();

    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        _showErr('البريد الإلكتروني أو الرقم التسلسلي مستخدم بالفعل');
      } else {
        _showErr('خطأ في قاعدة البيانات: ${e.message}');
      }
    } catch (e) {
      _showErr('خطأ: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _loadingReg = false);
    }
  }

  // دالة للتحقق من صحة UUID
  bool _isValidUUID(String uuid) {
    final regex = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        caseSensitive: false);
    return regex.hasMatch(uuid);
  }

  void _showErr(String msg) {
    setState(() => _formError = msg);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: Colors.red[700],
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(12),
    ));
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.green[50], shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle, color: Colors.green[600], size: 56),
          ),
          const SizedBox(height: 16),
          const Text('تم بنجاح!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(
            'تم إنشاء الحساب وتفعيل الجهاز\nبرقم تسلسلي: ${_serialCtrl.text.trim()}',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], height: 1.5),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // رجوع للـ login
              },
              child: const Text('تسجيل الدخول الآن',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 6),
        ]),
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  // BUILD (باقي الكود كما هو دون تغيير)
  // ════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: Column(children: [
        _buildHeader(),
        Expanded(child: FadeTransition(
          opacity: _fadeAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
            child: _step == 1 ? _buildStep1() : _buildStep2(),
          ),
        )),
      ]),
    );
  }

  // ── Header ────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue[800]!, Colors.blue[600]!],
        ),
        boxShadow: [BoxShadow(color: Colors.blue[900]!.withOpacity(0.3),
            blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 20, 20),
          child: Column(children: [
            Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                onPressed: () {
                  if (_step == 2) {
                    _fadeCtrl.reset();
                    setState(() { _step = 1; _device = null; _formError = null; });
                    _fadeCtrl.forward();
                  } else {
                    Navigator.pop(context);
                  }
                },
              ),
              const Spacer(),
              if (_step == 2)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.sensors, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text('SN: ${_serialCtrl.text.trim()}',
                        style: const TextStyle(color: Colors.white,
                            fontWeight: FontWeight.bold, fontSize: 13)),
                  ]),
                ),
            ]),
            const SizedBox(height: 4),
            // Progress Steps
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                _stepBubble(1, 'التحقق من الجهاز', Icons.sensors),
                Expanded(child: Container(height: 2,
                    color: _step == 2 ? Colors.white : Colors.blue[400])),
                _stepBubble(2, 'بيانات الحساب', Icons.person_add),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _stepBubble(int n, String label, IconData icon) {
    final active = _step >= n;
    final done   = _step > n;
    return Column(children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.blue[500],
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: active ? [BoxShadow(color: Colors.white.withOpacity(0.3),
              blurRadius: 8)] : [],
        ),
        child: Center(child: done
            ? Icon(Icons.check, color: Colors.blue[700], size: 22)
            : Icon(icon, color: active ? Colors.blue[700] : Colors.white54, size: 20)),
      ),
      const SizedBox(height: 6),
      Text(label, style: TextStyle(
        color: active ? Colors.white : Colors.blue[300],
        fontSize: 11, fontWeight: active ? FontWeight.bold : FontWeight.normal,
      )),
    ]);
  }

  // ════════════════════════════════════════════════════════
  // STEP 1 UI
  // ════════════════════════════════════════════════════════
  Widget _buildStep1() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

      const SizedBox(height: 8),
      // Card hero
      Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.blue[100]!.withOpacity(0.5),
              blurRadius: 20, offset: const Offset(0, 6))],
        ),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.blue[600]!, Colors.blue[800]!]),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.blue[300]!.withOpacity(0.5),
                  blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: const Icon(Icons.sensors, size: 44, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text('تحقق من جهازك',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                  color: Colors.blue[900])),
          const SizedBox(height: 8),
          Text(
            'أدخل الرقم التسلسلي المطبوع على الجهاز أو في علبته للتحقق من صحته',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 13, height: 1.6),
          ),
        ]),
      ),

      const SizedBox(height: 24),

      // Serial field
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1),
              blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: TextField(
          controller: _serialCtrl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold,
              letterSpacing: 8, color: Colors.blue[800]),
          decoration: InputDecoration(
            labelText: 'الرقم التسلسلي',
            labelStyle: TextStyle(color: Colors.blue[400], fontSize: 14),
            hintText: '• • • • • •',
            hintStyle: TextStyle(color: Colors.blue[200], fontSize: 22, letterSpacing: 8),
            prefixIcon: Icon(Icons.qr_code_scanner, color: Colors.blue[600], size: 26),
            errorText: _serialError,
            errorStyle: const TextStyle(fontSize: 13),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.blue[100]!)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.blue[600]!, width: 2)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.red, width: 1.5)),
            filled: true, fillColor: Colors.white,
          ),
          onChanged: (_) => setState(() => _serialError = null),
          onSubmitted: (_) => _checkSerial(),
        ),
      ),

      const SizedBox(height: 16),

      // Verify button
      SizedBox(
        height: 56,
        child: ElevatedButton(
          onPressed: _loadingSerial ? null : _checkSerial,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[700],
            disabledBackgroundColor: Colors.blue[300],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 4,
            shadowColor: Colors.blue[300],
          ),
          child: _loadingSerial
              ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
            SizedBox(width: 12),
            Text('جاري التحقق...', style: TextStyle(fontSize: 16, color: Colors.white)),
          ])
              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.verified_user_outlined, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            const Text('تحقق من الجهاز',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          ]),
        ),
      ),

      const SizedBox(height: 20),

      // Info box
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.amber[50],
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.amber[200]!),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.tips_and_updates_outlined, color: Colors.amber[700], size: 22),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('أين تجد الرقم التسلسلي؟',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber[900], fontSize: 14)),
            const SizedBox(height: 6),
            Text(
              '• مطبوع على ظهر الجهاز\n'
                  '• موجود داخل علبة المنتج\n'
                  '• يتكون من 6 أرقام (مثال:5****1)',
              style: TextStyle(color: Colors.amber[800], fontSize: 13, height: 1.6),
            ),
          ])),
        ]),
      ),

      const SizedBox(height: 20),
      Center(child: TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text('لديك حساب بالفعل؟ سجل دخول',
            style: TextStyle(color: Colors.blue[600], fontWeight: FontWeight.w600)),
      )),
    ]);
  }

  // ════════════════════════════════════════════════════════
  // STEP 2 UI
  // ════════════════════════════════════════════════════════
  Widget _buildStep2() {
    return SlideTransition(
      position: _slideAnim,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

        const SizedBox(height: 8),

        // Device confirmed card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.green[600]!, Colors.green[700]!]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.green[200]!.withOpacity(0.5),
                blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.check_circle, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('✓ الجهاز موثّق وجاهز للتفعيل',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 2),
              Text(
                '${_device?['device_name'] ?? 'HC-Monitor'}  •  SN: ${_serialCtrl.text.trim()}',
                style: TextStyle(color: Colors.green[100], fontSize: 12),
              ),
            ]),
          ]),
        ),

        const SizedBox(height: 22),
        _sectionTitle('المعلومات الشخصية', Icons.person_outline),
        const SizedBox(height: 12),

        _field(_fullNameCtrl, 'الاسم الكامل *', Icons.badge_outlined),
        const SizedBox(height: 12),

        Row(children: [
          Expanded(child: _field(_ageCtrl, 'السن *', Icons.cake_outlined,
              type: TextInputType.number)),
          const SizedBox(width: 12),
          Expanded(child: _genderDropdown()),
        ]),

        const SizedBox(height: 22),
        _sectionTitle('بيانات الحساب', Icons.lock_outline),
        const SizedBox(height: 12),

        _field(_emailCtrl, 'البريد الإلكتروني *', Icons.email_outlined,
            type: TextInputType.emailAddress),
        const SizedBox(height: 12),

        _field(_phoneCtrl, 'رقم الهاتف (اختياري)', Icons.phone_outlined,
            type: TextInputType.phone),
        const SizedBox(height: 12),

        _passField(_passwordCtrl, 'كلمة المرور *', Icons.lock_outline,
            _obscurePass, () => setState(() => _obscurePass = !_obscurePass)),
        const SizedBox(height: 12),

        _passField(_confirmPassCtrl, 'تأكيد كلمة المرور *', Icons.lock_person_outlined,
            _obscureConfirm, () => setState(() => _obscureConfirm = !_obscureConfirm)),

        const SizedBox(height: 24),

        if (_formError != null)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.red[50], borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red[200]!),
            ),
            child: Row(children: [
              Icon(Icons.error_outline, color: Colors.red[700], size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(_formError!,
                  style: TextStyle(color: Colors.red[700], fontSize: 13))),
            ]),
          ),

        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: _loadingReg ? null : _register,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              disabledBackgroundColor: Colors.blue[300],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              shadowColor: Colors.blue[300],
            ),
            child: _loadingReg
                ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
              SizedBox(width: 12),
              Text('جاري إنشاء الحساب...', style: TextStyle(fontSize: 15, color: Colors.white)),
            ])
                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.how_to_reg, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              const Text('إنشاء الحساب وتفعيل الجهاز',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ]),
          ),
        ),

        const SizedBox(height: 14),
        Center(child: TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('لديك حساب بالفعل؟ سجل دخول',
              style: TextStyle(color: Colors.blue[600], fontWeight: FontWeight.w600)),
        )),

        // Info panel
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.blue[100]!),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
              const SizedBox(width: 8),
              Text('معلومات مهمة', style: TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.blue[800], fontSize: 14)),
            ]),
            const SizedBox(height: 10),
            ...['يمكن ربط جهاز واحد فقط بكل حساب',
              'كلمة المرور يجب أن تكون 6 أحرف على الأقل',
              'السن مطلوب لتحسين التوصيات الصحية',
              'تأكد من البريد الإلكتروني لاستعادة الحساب'].map((t) =>
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.fiber_manual_record, size: 8, color: Colors.blue[400]),
                    const SizedBox(width: 8),
                    Expanded(child: Text(t, style: TextStyle(color: Colors.blue[700],
                        fontSize: 12.5, height: 1.4))),
                  ]),
                )),
          ]),
        ),
        const SizedBox(height: 10),
      ]),
    );
  }

  Widget _sectionTitle(String title, IconData icon) => Row(children: [
    Container(width: 4, height: 20,
        decoration: BoxDecoration(color: Colors.blue[700],
            borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 10),
    Icon(icon, color: Colors.blue[700], size: 18),
    const SizedBox(width: 6),
    Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
        color: Colors.blue[800])),
  ]);

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {TextInputType type = TextInputType.text}) => Container(
    decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08),
            blurRadius: 8, offset: const Offset(0, 3))]),
    child: TextField(
      controller: ctrl, keyboardType: type,
      decoration: InputDecoration(
        labelText: label, labelStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.blue[600], size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.blue[100]!)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.blue[600]!, width: 2)),
        filled: true, fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      ),
      onChanged: (_) { if (_formError != null) setState(() => _formError = null); },
    ),
  );

  Widget _passField(TextEditingController ctrl, String label, IconData icon,
      bool obscure, VoidCallback toggle) => Container(
    decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08),
            blurRadius: 8, offset: const Offset(0, 3))]),
    child: TextField(
      controller: ctrl, obscureText: obscure,
      decoration: InputDecoration(
        labelText: label, labelStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.blue[600], size: 20),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: Colors.grey[400], size: 20),
          onPressed: toggle,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.blue[100]!)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.blue[600]!, width: 2)),
        filled: true, fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      ),
      onChanged: (_) { if (_formError != null) setState(() => _formError = null); },
    ),
  );

  Widget _genderDropdown() => Container(
    decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08),
            blurRadius: 8, offset: const Offset(0, 3))]),
    child: DropdownButtonFormField<String>(
      value: _genderValue,
      decoration: InputDecoration(
        labelText: 'النوع',
        labelStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
        prefixIcon: Icon(Icons.wc, color: Colors.blue[600], size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.blue[100]!)),
        filled: true, fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      ),
      items: _genderOptions.map((g) =>
          DropdownMenuItem(value: g, child: Text(g))).toList(),
      onChanged: (v) => setState(() => _genderValue = v),
      hint: const Text('اختياري', style: TextStyle(fontSize: 13)),
    ),
  );
}