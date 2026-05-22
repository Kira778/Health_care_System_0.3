import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'dart:math';

class HomeScreen extends StatefulWidget {
  final String? userName;
  final Map<String, dynamic>? userDevice;
  final String userEmail;

  const HomeScreen({
    super.key,
    this.userName,
    this.userDevice,
    required this.userEmail,
  });
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  bool _loading = true;
  bool _usingRealData = false;
  bool _hasRealHeartRateData = false;
  bool _hasRealTempData = false; // ⭐ جديد

  double _heartRate = 72.0;
  List<double> _heartRateHistory = [];

  double _bloodPressure = 120.0;
  double _oxygenLevel = 98.0;
  double _temperature = 36.8;
  List<double> _bloodPressureHistory = [];
  List<double> _oxygenHistory = [];
  List<double> _temperatureHistory = [];

  int? _deviceSerialNumber;
  late Timer _updateTimer;

  @override
  void initState() {
    super.initState();
    _initializeStaticHistoryData();
    _startDataLoading();
  }

  void _initializeEmptyHeartRate() {
    setState(() {
      _heartRateHistory = [];
      _heartRate = 0;
      _usingRealData = true;
      _hasRealHeartRateData = false;
    });
  }

  void _initializeEmptyTemp() {
    setState(() {
      _temperatureHistory = [];
      _temperature = 0;
      _hasRealTempData = false;
    });
  }

  @override
  void dispose() {
    _updateTimer.cancel();
    super.dispose();
  }

  void _startDataLoading() async {
    await _tryToFetchRealData();
    _startPeriodicUpdates();
    setState(() => _loading = false);
  }

  Future<void> _tryToFetchRealData() async {
    try {
      final String emailToFetch = widget.userEmail;
      print('🔍 البحث عن بيانات المستخدم: $emailToFetch');

      final profileResponse = await supabase
          .from('profiles')
          .select('serial_number, full_name')
          .eq('email', emailToFetch)
          .maybeSingle();

      if (profileResponse != null && profileResponse['serial_number'] != null) {
        _deviceSerialNumber = profileResponse['serial_number'] as int;
        print('✅ تم العثور على رقم الجهاز: $_deviceSerialNumber');

        await _fetchRealSensorData();

        if (_hasRealHeartRateData) {
          print('✅ جلب ${_heartRateHistory.length} قراءة نبض من Supabase');
        } else {
          print('⚠️ لا توجد قراءات نبض في قاعدة البيانات');
        }
      } else {
        print('⚠️ لم يتم العثور على مستخدم بهذا البريد: $emailToFetch');
        print('⚠️ سيتم استخدام المحاكاة');
        _initializeSimulatedData();
      }
    } catch (e) {
      print('❌ خطأ في جلب البيانات الحقيقية: $e');
      _initializeSimulatedData();
    }
  }

  Future<void> _fetchRealSensorData() async {
    if (_deviceSerialNumber == null) return;

    try {
      print('🔍 جاري البحث عن بيانات النبض والحرارة من Supabase...');

      final response = await supabase
          .from('device_readings')
          .select('reading_value, temp_degree, reading_time') // ⭐ أضفنا temp_degree
          .eq('device_serial', _deviceSerialNumber!)
          .order('reading_time', ascending: false)
          .limit(15);

      if (response.isNotEmpty) {
        print('✅ تم العثور على ${response.length} قراءة في Supabase');

        final List<double> newHeartHistory = [];
        final List<double> newTempHistory = []; // ⭐ جديد

        for (var reading in response.reversed.toList()) {
          // نبض القلب
          final heartValue = reading['reading_value'];
          if (heartValue != null) {
            newHeartHistory.add((heartValue as num).toDouble());
          }

          // درجة الحرارة ⭐
          final tempValue = reading['temp_degree'];
          if (tempValue != null) {
            newTempHistory.add((tempValue as num).toDouble());
          }
        }

        setState(() {
          // نبض القلب
          if (newHeartHistory.isNotEmpty) {
            _heartRateHistory = newHeartHistory;
            _heartRate = newHeartHistory.last;
            _hasRealHeartRateData = true;
          } else {
            _initializeEmptyHeartRate();
          }

          // درجة الحرارة ⭐
          if (newTempHistory.isNotEmpty) {
            _temperatureHistory = newTempHistory;
            _temperature = newTempHistory.last;
            _hasRealTempData = true;
          } else {
            _initializeEmptyTemp();
          }

          _usingRealData = true;
        });

        print('📊 نبض: ${newHeartHistory.length} قراءة | حرارة: ${newTempHistory.length} قراءة');
      } else {
        print('⚠️ لا توجد قراءات نهائياً في Supabase');
        _initializeEmptyHeartRate();
        _initializeEmptyTemp();
        setState(() => _usingRealData = true);
      }
    } catch (e) {
      print('❌ خطأ في جلب بيانات المستشعرات: $e');
      setState(() {
        _usingRealData = false;
        _hasRealHeartRateData = false;
        _hasRealTempData = false;
      });
      _initializeSimulatedData();
    }
  }

  Future<void> _fetchLatestSensorData() async {
    if (_deviceSerialNumber == null || !_usingRealData) return;

    try {
      final response = await supabase
          .from('device_readings')
          .select('reading_value, temp_degree, reading_time') // ⭐
          .eq('device_serial', _deviceSerialNumber!)
          .order('reading_time', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        setState(() {
          // نبض القلب
          final heartValue = response['reading_value'];
          if (heartValue != null) {
            _heartRate = (heartValue as num).toDouble();
            _hasRealHeartRateData = true;
            if (_heartRateHistory.length >= 15) _heartRateHistory.removeAt(0);
            _heartRateHistory.add(_heartRate);
            print('🔄 نبض جديد: $_heartRate');
          }

          // درجة الحرارة ⭐
          final tempValue = response['temp_degree'];
          if (tempValue != null) {
            _temperature = (tempValue as num).toDouble();
            _hasRealTempData = true;
            if (_temperatureHistory.length >= 15) _temperatureHistory.removeAt(0);
            _temperatureHistory.add(_temperature);
            print('🌡️ حرارة جديدة: $_temperature');
          }
        });
      } else {
        print('⚠️ لا توجد قراءات جديدة من الجهاز');
      }
    } catch (e) {
      print('❌ خطأ في جلب آخر قراءة: $e');
    }
  }

  void _startPeriodicUpdates() {
    _updateTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (mounted) {
        if (_usingRealData) {
          await _fetchLatestSensorData();
        } else {
          _updateSimulatedHeartRate();
        }
        _updateOtherSensorData();
      }
    });
  }

  void _initializeSimulatedData() {
    final random = Random();
    final List<double> initialHeartHistory = [];
    final List<double> initialTempHistory = [];

    for (int i = 0; i < 10; i++) {
      initialHeartHistory.add(70 + random.nextDouble() * 20);
      initialTempHistory.add(36.2 + random.nextDouble() * 1.5); // ⭐
    }

    setState(() {
      _heartRateHistory = initialHeartHistory;
      _heartRate = initialHeartHistory.last;
      _temperatureHistory = initialTempHistory; // ⭐
      _temperature = initialTempHistory.last;   // ⭐
      _usingRealData = false;
      _hasRealHeartRateData = false;
      _hasRealTempData = false; // ⭐
    });
  }

  void _updateSimulatedHeartRate() {
    if (_hasRealHeartRateData) return;
    final random = Random();
    final newHeartRate = 70 + random.nextDouble() * 20;
    setState(() {
      _heartRate = newHeartRate;
      if (_heartRateHistory.length >= 20) _heartRateHistory.removeAt(0);
      _heartRateHistory.add(_heartRate);
    });
  }

  void _updateOtherSensorData() {
    final random = Random();
    setState(() {
      _bloodPressure = 110 + random.nextDouble() * 30;
      _oxygenLevel = 94 + random.nextDouble() * 6;

      // ⭐ حرارة random فقط إذا مش بيانات حقيقية
      if (!_hasRealTempData) {
        _temperature = 36.2 + random.nextDouble() * 1.5;
      }

      _updateStaticHistoryData();
    });
  }

  void _initializeStaticHistoryData() {
    final random = Random();

    _bloodPressureHistory.clear();
    _oxygenHistory.clear();
    _temperatureHistory.clear();
    _heartRateHistory.clear();

    for (int i = 0; i < 10; i++) {
      _heartRateHistory.add(70 + random.nextDouble() * 20);
      _bloodPressureHistory.add(115 + random.nextDouble() * 20);
      _oxygenHistory.add(95 + random.nextDouble() * 3);
      _temperatureHistory.add(36.5 + random.nextDouble() * 1.0);
    }

    if (_heartRateHistory.isNotEmpty) _heartRate = _heartRateHistory.last;
    if (_bloodPressureHistory.isNotEmpty) _bloodPressure = _bloodPressureHistory.last;
    if (_oxygenHistory.isNotEmpty) _oxygenLevel = _oxygenHistory.last;
    if (_temperatureHistory.isNotEmpty) _temperature = _temperatureHistory.last;
  }

  void _updateStaticHistoryData() {
    _addToHistory(_bloodPressureHistory, _bloodPressure, 10);
    _addToHistory(_oxygenHistory, _oxygenLevel, 10);
    // ⭐ حرارة تتحدث random فقط إذا مش real data
    if (!_hasRealTempData) {
      _addToHistory(_temperatureHistory, _temperature, 10);
    }
  }

  void _addToHistory(List<double> history, double newValue, int maxLength) {
    if (history.length >= maxLength) history.removeAt(0);
    history.add(newValue);
  }

  Future<void> _forceRefreshData() async {
    setState(() => _loading = true);
    try {
      await _tryToFetchRealData();
      print('🔄 تم تحديث البيانات بنجاح');
    } catch (e) {
      print('❌ خطأ في تحديث البيانات: $e');
    }
    setState(() => _loading = false);
  }

  Future<void> _addTestDataToSupabase() async {
    if (_deviceSerialNumber == null) {
      print('❌ لا يوجد رقم جهاز لإضافة بيانات تجريبية');
      return;
    }

    try {
      for (int i = 0; i < 5; i++) {
        final randomHeart = 70 + Random().nextDouble() * 20;
        final randomTemp = 36.2 + Random().nextDouble() * 1.5; // ⭐

        await supabase.from('device_readings').insert({
          'device_serial': _deviceSerialNumber,
          'reading_value': randomHeart,
          'temp_degree': randomTemp, // ⭐
          'reading_time': DateTime.now()
              .subtract(Duration(minutes: i * 5))
              .toIso8601String(),
        });
      }

      print('✅ تم إضافة بيانات تجريبية (نبض + حرارة) إلى Supabase');
      await _forceRefreshData();
    } catch (e) {
      print('❌ خطأ في إضافة بيانات تجريبية: $e');
    }
  }

  Widget _buildHealthCardWithGraph(
    String title,
    double value,
    String unit,
    IconData icon,
    Color color,
    List<double> history,
    bool isRealData, // ⭐ هل هذه البطاقة تعتمد على بيانات حقيقية
    bool hasRealData, // ⭐ هل وصلت البيانات فعلاً
  ) {
    final bool isEmpty = isRealData && !hasRealData && _usingRealData;
    final bool isSimulated = !_usingRealData;

    return Card(
      elevation: 3,
      color: isEmpty ? Colors.grey[100] : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: isEmpty ? Colors.grey : (isSimulated ? Colors.orange : color),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isEmpty ? Colors.grey[600] : Colors.black,
                        ),
                      ),
                      if (isRealData)
                        Text(
                          isEmpty
                              ? 'لا توجد بيانات'
                              : (isSimulated ? '(محاكاة)' : '(بيانات حقيقية)'),
                          style: TextStyle(
                            fontSize: 10,
                            color: isEmpty
                                ? Colors.grey
                                : (isSimulated ? Colors.orange : Colors.green),
                          ),
                        ),
                    ],
                  ),
                ),
                if (isEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'فارغة',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        'آخر إرسال: غير متاح',
                        style: TextStyle(fontSize: 9, color: Colors.grey),
                      ),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        value.toStringAsFixed(title == 'درجة الحرارة' ? 1 : 0),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isSimulated ? Colors.orange : color,
                        ),
                      ),
                      Text(
                        unit,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      if (isRealData && _usingRealData)
                        Text(
                          'آخر إرسال: ${_getLastUpdateTime()}',
                          style: TextStyle(fontSize: 9, color: Colors.green),
                        ),
                    ],
                  ),
              ],
            ),

            const SizedBox(height: 8),

            Container(
              height: 40,
              child: isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.sync_disabled, size: 16, color: Colors.grey),
                          Text(
                            'بانتظار البيانات',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : _buildMiniGraph(history, isSimulated ? Colors.orange : color),
            ),

            const SizedBox(height: 4),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (isEmpty)
                  Row(
                    children: [
                      Icon(Icons.wifi_off, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('غير متصل بالجهاز',
                          style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  )
                else if (isSimulated)
                  Row(
                    children: [
                      Icon(Icons.sim_card, size: 12, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text('بيانات محاكاة',
                          style: TextStyle(fontSize: 10, color: Colors.orange)),
                    ],
                  )
                else
                  Row(
                    children: [
                      Icon(Icons.cloud_done, size: 12, color: Colors.green),
                      const SizedBox(width: 4),
                      Text('بيانات حقيقية',
                          style: TextStyle(fontSize: 10, color: Colors.green)),
                    ],
                  ),

                if (!isEmpty && history.length >= 2)
                  Row(
                    children: [
                      Icon(_getTrendIcon(history), size: 12, color: _getTrendColor(history)),
                      const SizedBox(width: 2),
                      Text(
                        _getTrendText(history),
                        style: TextStyle(
                          fontSize: 10,
                          color: _getTrendColor(history),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniGraph(List<double> data, Color color) {
    if (data.isEmpty) return const SizedBox();
    return CustomPaint(
      size: const Size(double.infinity, 40),
      painter: _MiniGraphPainter(data, color),
    );
  }

  String _getLastUpdateTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  String _getTrendText(List<double> data) {
    if (data.length < 2) return 'ثابت';
    final trend = _calculateTrend(data);
    if (trend > 1) return 'مرتفع';
    if (trend < -1) return 'منخفض';
    return 'مستقر';
  }

  Color _getTrendColor(List<double> data) {
    if (data.length < 2) return Colors.grey;
    final trend = _calculateTrend(data);
    if (trend > 1) return Colors.red;
    if (trend < -1) return Colors.green;
    return Colors.grey;
  }

  IconData _getTrendIcon(List<double> data) {
    if (data.length < 2) return Icons.trending_flat;
    final trend = _calculateTrend(data);
    if (trend > 1) return Icons.trending_up;
    if (trend < -1) return Icons.trending_down;
    return Icons.trending_flat;
  }

  double _calculateTrend(List<double> data) {
    if (data.length < 2) return 0;
    return data.last - data[data.length - 2];
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              const Text('جاري تحميل البيانات...'),
              const SizedBox(height: 10),
              Text(
                _deviceSerialNumber != null
                    ? 'رقم الجهاز: $_deviceSerialNumber'
                    : 'جاري البحث عن الجهاز...',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Helth Care'),
        actions: [
          if (!_usingRealData && _deviceSerialNumber != null)
            IconButton(
              icon: const Icon(Icons.add_chart),
              onPressed: _addTestDataToSupabase,
              tooltip: 'إضافة بيانات تجريبية إلى Supabase',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _forceRefreshData,
            tooltip: 'تحديث البيانات من Supabase',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 معلومات النظام
            Card(
              color: _usingRealData ? Colors.green.shade50 : Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          _usingRealData ? Icons.cloud_done : Icons.sim_card,
                          color: _usingRealData ? Colors.green : Colors.orange,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _usingRealData ? ' Conected Supabase' : '⚠️  Virtual Mode',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _usingRealData
                                      ? Colors.green.shade800
                                      : Colors.orange.shade800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _usingRealData
                                    ? 'البيانات تُجلب من قاعدة البيانات'
                                    : 'بيانات محاكاة (لا توجد بيانات في device_readings)',
                                style: const TextStyle(fontSize: 12, color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_deviceSerialNumber != null)
                      Row(
                        children: [
                          Icon(Icons.device_hub, size: 16, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(
                            'رقم الجهاز: $_deviceSerialNumber',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          if (!_usingRealData)
                            ElevatedButton(
                              onPressed: _addTestDataToSupabase,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade100,
                                foregroundColor: Colors.blue.shade800,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              ),
                              child: const Text('إضافة بيانات تجريبية'),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            // 🔹 بطاقة الترحيب
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: Colors.blue.shade100,
                      child: Icon(Icons.person, size: 25, color: Colors.blue.shade700),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'مرحباً ${widget.userName ?? 'مستخدم'} 👋',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'نظام مراقبة الصحة الذكي',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                _usingRealData ? Icons.cloud_done : Icons.cloud_off,
                                size: 12,
                                color: _usingRealData ? Colors.green : Colors.orange,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _usingRealData ? 'متصل بـ Supabase' : 'بيانات محاكاة',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _usingRealData ? Colors.green : Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.refresh, color: Colors.blue, size: 20),
                      onPressed: _forceRefreshData,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 🔹 شريط الحالة
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    Icon(
                      _usingRealData ? Icons.cloud_done : Icons.cloud_off,
                      color: _usingRealData ? Colors.green : Colors.orange,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _usingRealData ? 'متصل بـ Supabase' : 'غير متصل',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _usingRealData ? Colors.green : Colors.orange,
                            ),
                          ),
                          if (_usingRealData && _heartRateHistory.isNotEmpty)
                            Text(
                              'آخر قراءة: ${_heartRate.toStringAsFixed(0)} نبضة/دقيقة | ${_temperature.toStringAsFixed(1)} °C',
                              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                            )
                          else if (_usingRealData)
                            Text(
                              'جاري انتظار البيانات...',
                              style: TextStyle(fontSize: 11, color: Colors.orange[600]),
                            ),
                        ],
                      ),
                    ),
                    if (_deviceSerialNumber != null)
                      Chip(
                        label: Text('جهاز $_deviceSerialNumber',
                            style: TextStyle(fontSize: 10)),
                        backgroundColor: Colors.blue[50],
                      ),
                  ],
                ),
              ),
            ),

            // 🔹 رسالة إذا كانت البيانات فارغة
            if (_usingRealData && !_hasRealHeartRateData)
              Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.orange),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'لا توجد بيانات في Supabase. الجهاز متصل ولكن لم يرسل بيانات بعد.',
                          style: TextStyle(color: Colors.orange.shade800),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _addTestDataToSupabase,
                        child: Text('إضافة بيانات تجريبية'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade100,
                          foregroundColor: Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // 🔹 بطاقات القياس
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                _buildHealthCardWithGraph(
                  'معدل ضربات القلب',
                  _heartRateHistory.isEmpty ? 0 : _heartRate,
                  'نبضة/دقيقة',
                  Icons.favorite,
                  _getHeartRateCardColor(),
                  _heartRateHistory,
                  true,
                  _hasRealHeartRateData, // ⭐
                ),
                _buildHealthCardWithGraph(
                  'ضغط الدم',
                  _bloodPressure,
                  'ملم زئبق',
                  Icons.speed,
                  _getBloodPressureColor(_bloodPressure),
                  _bloodPressureHistory,
                  false,
                  false,
                ),
                _buildHealthCardWithGraph(
                  'مستوى الأكسجين',
                  _oxygenLevel,
                  '%',
                  Icons.water_drop,
                  _getOxygenColor(_oxygenLevel),
                  _oxygenHistory,
                  false,
                  false,
                ),
                _buildHealthCardWithGraph(
                  'درجة الحرارة',
                  _temperatureHistory.isEmpty ? 0 : _temperature, // ⭐
                  '°C',
                  Icons.thermostat,
                  _getTempCardColor(), // ⭐
                  _temperatureHistory,
                  true,  // ⭐ بيانات حقيقية من Supabase
                  _hasRealTempData, // ⭐
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 🔹 جراف معدل ضربات القلب
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.favorite,
                            color: _usingRealData ? Colors.green : Colors.red),
                        const SizedBox(width: 8),
                        const Text('معدل ضربات القلب',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const Spacer(),
                        Text('آخر ${_heartRateHistory.length} قراءة',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 120,
                      child: _heartRateHistory.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.heart_broken, size: 40, color: Colors.grey),
                                  const SizedBox(height: 8),
                                  Text('لا توجد بيانات نبض',
                                      style: TextStyle(fontSize: 14, color: Colors.grey)),
                                  if (_usingRealData)
                                    Text('جاري انتظار بيانات من الجهاز',
                                        style: TextStyle(fontSize: 12, color: Colors.orange)),
                                ],
                              ),
                            )
                          : _buildMainGraph(
                              _heartRateHistory,
                              _usingRealData ? Colors.green : Colors.red,
                              'نبضة/دقيقة',
                            ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatItem('الأدنى', _getMinValue(_heartRateHistory)),
                        _buildStatItem('الأعلى', _getMaxValue(_heartRateHistory)),
                        _buildStatItem('المتوسط', _getAverageValue(_heartRateHistory)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 🔹 جراف درجة الحرارة ⭐ جديد بالكامل
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.thermostat,
                            color: _hasRealTempData ? Colors.purple : Colors.orange),
                        const SizedBox(width: 8),
                        const Text('درجة الحرارة',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const Spacer(),
                        Text('آخر ${_temperatureHistory.length} قراءة',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 120,
                      child: _temperatureHistory.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.device_thermostat, size: 40, color: Colors.grey),
                                  const SizedBox(height: 8),
                                  Text('لا توجد بيانات حرارة',
                                      style: TextStyle(fontSize: 14, color: Colors.grey)),
                                  if (_usingRealData)
                                    Text('جاري انتظار بيانات من الجهاز',
                                        style: TextStyle(fontSize: 12, color: Colors.orange)),
                                ],
                              ),
                            )
                          : _buildMainGraph(
                              _temperatureHistory,
                              _hasRealTempData ? Colors.purple : Colors.orange,
                              '°C',
                            ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatItem('الأدنى', _getMinValue(_temperatureHistory, decimals: 1)),
                        _buildStatItem('الأعلى', _getMaxValue(_temperatureHistory, decimals: 1)),
                        _buildStatItem('المتوسط', _getAverageValue(_temperatureHistory, decimals: 1)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 🔹 معلومات التقنية
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('📊 معلومات التقنية',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    _buildTechInfoItem('مصدر بيانات النبض',
                        _usingRealData ? 'Supabase (reading_value)' : 'محاكاة'),
                    _buildTechInfoItem('مصدر بيانات الحرارة', // ⭐
                        _hasRealTempData ? 'Supabase (temp_degree)' : 'محاكاة'),
                    _buildTechInfoItem('رقم الجهاز', _deviceSerialNumber?.toString() ?? 'غير محدد'),
                    _buildTechInfoItem('قراءات النبض', '${_heartRateHistory.length}'),
                    _buildTechInfoItem('قراءات الحرارة', '${_temperatureHistory.length}'), // ⭐
                    _buildTechInfoItem('آخر تحديث', _getFormattedTime()),
                    _buildTechInfoItem('معدل التحديث', 'كل 5 ثواني'),
                    if (!_usingRealData)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '💡 ملاحظة: لإظهار بيانات حقيقية من Supabase:',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange.shade800,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '1. تأكد من وجود بيانات في جدول device_readings\n'
                              '2. تأكد أن device_serial يطابق $_deviceSerialNumber\n'
                              '3. تأكد من وجود عمود temp_degree في الجدول\n'
                              '4. اضغط زر "إضافة بيانات تجريبية"',
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
        ),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildTechInfoItem(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$title: ',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(value,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          ),
        ],
      ),
    );
  }

  String _getMinValue(List<double> data, {int decimals = 0}) {
    if (data.isEmpty) return '0';
    return data.reduce((a, b) => a < b ? a : b).toStringAsFixed(decimals);
  }

  String _getMaxValue(List<double> data, {int decimals = 0}) {
    if (data.isEmpty) return '0';
    return data.reduce((a, b) => a > b ? a : b).toStringAsFixed(decimals);
  }

  String _getAverageValue(List<double> data, {int decimals = 0}) {
    if (data.isEmpty) return '0';
    final sum = data.reduce((a, b) => a + b);
    return (sum / data.length).toStringAsFixed(decimals);
  }

  String _getFormattedTime() {
    final now = DateTime.now();
    return '${now.hour}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
  }

  Widget _buildMainGraph(List<double> data, Color color, String unit) {
    if (data.isEmpty) return const Center(child: Text('لا توجد بيانات'));

    final minY = data.reduce((a, b) => a < b ? a : b) - 5;
    final maxY = data.reduce((a, b) => a > b ? a : b) + 5;

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 35,
              interval: (maxY - minY) / 4,
              getTitlesWidget: (value, meta) {
                return Text(value.toStringAsFixed(unit == '°C' ? 1 : 0),
                    style: const TextStyle(fontSize: 10));
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: data.length > 1 ? (data.length - 1).toDouble() : 10,
        minY: minY,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: data
                .asMap()
                .entries
                .map((e) => FlSpot(e.key.toDouble(), e.value))
                .toList(),
            isCurved: true,
            color: color,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [color.withOpacity(0.3), color.withOpacity(0.1)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 300),
    );
  }

  Color _getHeartRateCardColor() {
    if (_usingRealData && !_hasRealHeartRateData) return Colors.grey;
    if (!_usingRealData) return Colors.orange;
    return _getHeartRateColor(_heartRate);
  }

  // ⭐ جديد
  Color _getTempCardColor() {
    if (_usingRealData && !_hasRealTempData) return Colors.grey;
    if (!_usingRealData) return Colors.orange;
    return _getTemperatureColor(_temperature);
  }

  Color _getHeartRateColor(double rate) {
    if (rate > 90) return Colors.red;
    if (rate < 60) return Colors.orange;
    return Colors.green;
  }

  Color _getBloodPressureColor(double pressure) {
    if (pressure > 140) return Colors.red;
    if (pressure < 110) return Colors.orange;
    return Colors.green;
  }

  Color _getOxygenColor(double oxygen) {
    if (oxygen < 95) return Colors.red;
    return Colors.blue;
  }

  Color _getTemperatureColor(double temp) {
    if (temp > 37.5) return Colors.red;
    return Colors.purple;
  }
}

class _MiniGraphPainter extends CustomPainter {
  final List<double> data;
  final Color color;

  _MiniGraphPainter(this.data, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final points = <Offset>[];
    final minValue = data.reduce((a, b) => a < b ? a : b);
    final maxValue = data.reduce((a, b) => a > b ? a : b);
    final range = maxValue - minValue;
    final xStep = size.width / (data.length - 1);
    final yScale = range > 0 ? size.height / range : size.height;

    for (int i = 0; i < data.length; i++) {
      final x = i * xStep;
      final y = size.height - ((data[i] - minValue) * yScale);
      points.add(Offset(x, y));
    }

    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }

    if (points.length > 1) {
      final fillPath = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        fillPath.lineTo(points[i].dx, points[i].dy);
      }
      fillPath.lineTo(points.last.dx, size.height);
      fillPath.lineTo(points.first.dx, size.height);
      fillPath.close();
      canvas.drawPath(fillPath, fillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
