import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:local_auth/local_auth.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

const String kBackendUrl = 'https://script.google.com/macros/s/AKfycby6jmx9r5SYs1b4NdwCHSHmB9ctqkLh5AgQjv5DIJlJugj05D92maiRpIsoRN3dr_5yRw/exec';
const String kOfflineQueueKey = 'ebhar_pending_offline_txns';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EbharApp());
}

class EbharApp extends StatelessWidget {
  const EbharApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'إبحار',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF4F6F9),
        primaryColor: const Color(0xFF0F4C81),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF0F4C81),
          secondary: Color(0xFF007A78),
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F4C81),
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        fontFamily: 'sans-serif',
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ar', 'SA')],
      locale: const Locale('ar', 'SA'),
      home: const AuthGatekeeper(),
    );
  }
}

// -------------------------------------------------------------
// إدارة طابور الحركات غير المرسلة
// -------------------------------------------------------------
class OfflineManager {
  static Future<List<Map<String, dynamic>>> getQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(kOfflineQueueKey) ?? [];
    return list.map((item) => json.decode(item) as Map<String, dynamic>).toList();
  }

  static Future<void> enqueue(Map<String, dynamic> txn) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(kOfflineQueueKey) ?? [];
    list.add(json.encode(txn));
    await prefs.setStringList(kOfflineQueueKey, list);
  }

  static Future<void> removeAt(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(kOfflineQueueKey) ?? [];
    if (index >= 0 && index < list.length) {
      list.removeAt(index);
      await prefs.setStringList(kOfflineQueueKey, list);
    }
  }
}

// -------------------------------------------------------------
// محرك حوكمة وتحليل الرسائل البنكية الذكي (Smart Bank SMS Parser)
// -------------------------------------------------------------
class ParsedBankResult {
  final double? amount;
  final String description;
  final String movementType;
  final String paymentMethod;
  final String? cardLast4;

  ParsedBankResult({
    this.amount,
    required this.description,
    required this.movementType,
    required this.paymentMethod,
    this.cardLast4,
  });
}

class BankSmsGovernanceParser {
  static ParsedBankResult parse(String sms) {
    final text = sms.trim();
    double? amount;
    String desc = '';
    String mType = 'مصروف';
    String pMethod = 'بطاقة مدى';
    String? last4;

    // 1. استخراج المبلغ بمرونة عالية لجميع صيغ البنوك
    final amtRegexes = [
      RegExp(r'(?:بـ|ب|بقيمة|مبلغ|بمبلغ)\s*([0-9]+(?:\.[0-9]+)?)\s*(?:SAR|ر\.س)?', caseSensitive: false),
      RegExp(r'([0-9]+(?:\.[0-9]+)?)\s*(?:SAR|ر\.س)', caseSensitive: false),
    ];
    for (var reg in amtRegexes) {
      final match = reg.firstMatch(text);
      if (match != null) {
        amount = double.tryParse(match.group(1) ?? '');
        if (amount != null && amount > 0) break;
      }
    }

    // 2. تحديد نوع الحركة وطريقة الدفع
    if (text.contains('حوالة واردة') || text.contains('إيداع') || text.contains('ايداع')) {
      mType = 'دخل';
      pMethod = 'حوالة بنكية';
    } else if (text.contains('حوالة صادرة') || text.contains('تحويل')) {
      mType = 'مصروف';
      pMethod = 'حوالة بنكية';
    } else if (text.contains('إئتمانية') || text.contains('ائتمانية')) {
      mType = 'مصروف';
      pMethod = 'بطاقة ائتمانية';
    } else if (text.contains('مدى') || text.contains('شراء-POS') || text.contains('نقطة بيع')) {
      mType = 'مصروف';
      pMethod = 'بطاقة مدى';
    }

    // 3. استخراج اسم المتجر أو الطرف الثاني بدقة
    final lines = text.split(RegExp(r'[\r\n]+'));
    for (var line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.startsWith('من ') || trimmedLine.startsWith('من\t')) {
        desc = trimmedLine.replaceFirst(RegExp(r'^من\s*'), '').trim();
        break;
      } else if (trimmedLine.startsWith('لـ') || trimmedLine.startsWith('ل ')) {
        desc = trimmedLine.replaceFirst(RegExp(r'^(?:لـ|ل)\s*'), '').trim();
        break;
      } else if (trimmedLine.startsWith('لدى ')) {
        desc = trimmedLine.replaceFirst(RegExp(r'^لدى\s*'), '').trim();
        break;
      }
    }

    if (desc.isEmpty) {
      final descMatch = RegExp(r'(?:لدى|من|لـ|ل)\s*([^\n\r\*]+)').firstMatch(text);
      if (descMatch != null) {
        desc = descMatch.group(1)?.trim() ?? '';
      }
    }

    // تنظيف اسم المتجر/المستفيد من الأرقام والرموز
    desc = desc.replaceAll(RegExp(r'(\d{4}\*|\*\d{4}|\*|SAR|ر\.س|في|بتاريخ|الساعة|إئتمانية|مدى).*', caseSensitive: false), '').trim();

    // 4. استخراج آخر 4 أرقام من البطاقة أو الحساب
    final cardMatch1 = RegExp(r'(?:\*|\*{2})([0-9]{4})').firstMatch(text);
    final cardMatch2 = RegExp(r'([0-9]{4})\*').firstMatch(text);

    if (cardMatch1 != null) {
      last4 = cardMatch1.group(1);
    } else if (cardMatch2 != null) {
      last4 = cardMatch2.group(1);
    }

    return ParsedBankResult(
      amount: amount,
      description: desc,
      movementType: mType,
      paymentMethod: pMethod,
      cardLast4: last4,
    );
  }
}

// -------------------------------------------------------------
// بوابة الدخول وفحص البصمة
// -------------------------------------------------------------
class AuthGatekeeper extends StatefulWidget {
  const AuthGatekeeper({super.key});

  @override
  State<AuthGatekeeper> createState() => _AuthGatekeeperState();
}

class _AuthGatekeeperState extends State<AuthGatekeeper> {
  @override
  void initState() {
    super.initState();
    _routeUser();
  }

  Future<void> _routeUser() async {
    final prefs = await SharedPreferences.getInstance();
    final bool bioEnabled = prefs.getBool('bio_enabled') ?? false;
    final String? savedUser = prefs.getString('saved_user');
    final String? savedPass = prefs.getString('saved_pass');

    if (!mounted) return;

    if (bioEnabled && savedUser != null && savedPass != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => BiometricPromptScreen(
            username: savedUser,
            password: savedPass,
          ),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const FullLoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(color: Color(0xFF0F4C81)),
      ),
    );
  }
}

// -------------------------------------------------------------
// 1. شاشة تسجيل الدخول الأولى
// -------------------------------------------------------------
class FullLoginScreen extends StatefulWidget {
  const FullLoginScreen({super.key});

  @override
  State<FullLoginScreen> createState() => _FullLoginScreenState();
}

class _FullLoginScreenState extends State<FullLoginScreen> {
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _enableBiometrics = true;
  bool _isLoading = false;
  String _errorMsg = '';

  Future<void> _performLogin() async {
    final username = _userController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMsg = 'يرجى إدخال اسم المستخدم وكلمة المرور');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMsg = '';
    });

    try {
      final uri = Uri.parse(kBackendUrl).replace(queryParameters: {
        'action': 'login',
        'username': username,
        'password': password,
      });

      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      final data = json.decode(res.body);

      if (data['ok'] == true) {
        final prefs = await SharedPreferences.getInstance();
        if (_enableBiometrics) {
          await prefs.setBool('bio_enabled', true);
          await prefs.setString('saved_user', username);
          await prefs.setString('saved_pass', password);
        } else {
          await prefs.remove('bio_enabled');
          await prefs.remove('saved_user');
          await prefs.remove('saved_pass');
        }

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => MainDashboard(currentUser: data['data'] ?? {'username': username}),
          ),
        );
      } else {
        setState(() => _errorMsg = data['error'] ?? 'بيانات الدخول غير صحيحة');
      }
    } catch (e) {
      setState(() => _errorMsg = 'تعذر الاتصال بالخادم. تحقق من الإنترنت.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset('assets/app_icon.png', height: 80, width: 80, fit: BoxFit.cover),
                ),
                const SizedBox(height: 10),
                const Text(
                  'إبحار',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF0F4C81)),
                ),
                const SizedBox(height: 4),
                const Text('منظومة الإدارة والمحاسبة الذكية', style: TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w500)),
                const SizedBox(height: 28),

                if (_errorMsg.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Text(_errorMsg, style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: 14),
                ],

                TextField(
                  controller: _userController,
                  style: const TextStyle(color: Colors.black87),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.person, color: Color(0xFF0F4C81)),
                    labelText: 'اسم المستخدم',
                    filled: true,
                    fillColor: const Color(0xFFF4F6F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.black87),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.lock, color: Color(0xFF0F4C81)),
                    labelText: 'كلمة المرور',
                    filled: true,
                    fillColor: const Color(0xFFF4F6F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),

                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _enableBiometrics,
                  activeColor: const Color(0xFF0F4C81),
                  title: const Text('تفعيل الدخول السريع بالبصمة لاحقاً', style: TextStyle(fontSize: 13, color: Colors.black87)),
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (val) => setState(() => _enableBiometrics = val ?? true),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F4C81),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _isLoading ? null : _performLogin,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('تسجيل الدخول والتحقق', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 35),
                const Text(
                  'المالك/ فضل بن عباس القديحي',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F4C81), letterSpacing: 0.2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// 2. شاشة الدخول بالبصمة
// -------------------------------------------------------------
class BiometricPromptScreen extends StatefulWidget {
  final String username;
  final String password;

  const BiometricPromptScreen({super.key, required this.username, required this.password});

  @override
  State<BiometricPromptScreen> createState() => _BiometricPromptScreenState();
}

class _BiometricPromptScreenState extends State<BiometricPromptScreen> {
  final LocalAuthentication _auth = LocalAuthentication();
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 300), _authenticate);
  }

  Future<void> _authenticate() async {
    try {
      final bool canCheck = await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
      if (!canCheck) {
        _resetToManualLogin();
        return;
      }

      final didAuth = await _auth.authenticate(
        localizedReason: 'المس مستشعر البصمة للمتابعة لحساب ${widget.username}',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      if (didAuth && mounted) {
        _loginToServer();
      }
    } catch (_) {}
  }

  Future<void> _loginToServer() async {
    setState(() => _isVerifying = true);
    try {
      final uri = Uri.parse(kBackendUrl).replace(queryParameters: {
        'action': 'login',
        'username': widget.username,
        'password': widget.password,
      });

      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      final data = json.decode(res.body);

      if (data['ok'] == true && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => MainDashboard(currentUser: data['data'] ?? {'username': widget.username}),
          ),
        );
      } else {
        if (!mounted) return;
        _resetToManualLogin();
      }
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => MainDashboard(currentUser: {'username': widget.username, 'display_name': widget.username}),
        ),
      );
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _resetToManualLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('bio_enabled');
    await prefs.remove('saved_user');
    await prefs.remove('saved_pass');
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const FullLoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26),
            child: Column(
              mainAxisAlignment: Center(child: null) == null ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset('assets/app_icon.png', height: 70, width: 70, fit: BoxFit.cover),
                ),
                const SizedBox(height: 8),
                const Text('إبحار', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF0F4C81))),
                const SizedBox(height: 8),
                Text('مرحباً ${widget.username}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 4),
                const Text('الدخول السريع عبر البصمة', style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 28),

                InkWell(
                  onTap: _authenticate,
                  borderRadius: BorderRadius.circular(60),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF0F4C81), width: 2),
                      color: const Color(0xFF0F4C81).withOpacity(0.06),
                    ),
                    child: _isVerifying
                        ? const CircularProgressIndicator(color: Color(0xFF0F4C81))
                        : const Icon(Icons.fingerprint, size: 65, color: Color(0xFF0F4C81)),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('المس المستشعر لإعادة المحاولة', style: TextStyle(fontSize: 13, color: Colors.black54)),
                const SizedBox(height: 24),

                TextButton.icon(
                  onPressed: _resetToManualLogin,
                  icon: const Icon(Icons.swap_horiz, color: Color(0xFF0F4C81)),
                  label: const Text('تسجيل الدخول باسم مستخدم آخر', style: TextStyle(color: Color(0xFF0F4C81))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// 3. الشاشة الرئيسية المشتركة مع المزامنة التلقائية اللحظية
// -------------------------------------------------------------
class MainDashboard extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  const MainDashboard({super.key, required this.currentUser});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _currentIndex = 0;
  bool _isLoading = true;
  int _pendingCount = 0;
  bool _isSyncing = false;
  StreamSubscription<ConnectivityResult>? _connSub;
  Timer? _autoSyncTimer;

  List<Map<String, String>> _accountsList = [];
  List<Map<String, dynamic>> _cardsList = [];
  List<Map<String, String>> _categoriesList = [];
  List<Map<String, String>> _tempMapsList = [];
  List<Map<String, dynamic>> _tempSubCategoriesList = [];

  @override
  void initState() {
    super.initState();
    _fetchSystemData();
    _updatePendingCount();
    _setupAutoSync();
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _autoSyncTimer?.cancel();
    super.dispose();
  }

  void _setupAutoSync() {
    _connSub = Connectivity().onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        _syncAllPending();
      }
    });

    _autoSyncTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      final queue = await OfflineManager.getQueue();
      if (queue.isNotEmpty && !_isSyncing) {
        _syncAllPending();
      }
    });
  }

  Future<void> _updatePendingCount() async {
    final queue = await OfflineManager.getQueue();
    if (mounted) {
      setState(() => _pendingCount = queue.length);
    }
  }

  // -----------------------------------------------------------
  // دالة المزامنة المحدثة: إرسال كل الحركات دفعة واحدة لتوليد تقرير مجمع
  // -----------------------------------------------------------
  Future<void> _syncAllPending() async {
    if (_isSyncing) return;
    final queue = await OfflineManager.getQueue();
    if (queue.isEmpty) return;

    setState(() => _isSyncing = true);

    try {
      final uri = Uri.parse(kBackendUrl).replace(queryParameters: {
        'action': 'saveBatchTransactions',
        'payload': json.encode(queue),
      });

      final res = await http.get(uri).timeout(const Duration(seconds: 15));
      final data = json.decode(res.body);

      if (data['ok'] == true) {
        final count = queue.length;
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(kOfflineQueueKey);

        if (mounted) {
          setState(() {
            _pendingCount = 0;
            _isSyncing = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.teal,
              content: Text('تمت مزامنة $count حركات معاً وتوليد التقرير المجمّع بنجاح! 🎉'),
            ),
          );
          _fetchSystemData();
        }
      } else {
        throw Exception(data['error']);
      }
    } catch (_) {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _showPendingQueueSheet() async {
    final queue = await OfflineManager.getQueue();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'الحركات المعلقة للرفع (${queue.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F4C81)),
                      ),
                      if (queue.isNotEmpty)
                        TextButton.icon(
                          icon: _isSyncing
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.cloud_upload, size: 18),
                          label: const Text('إرسال الكل الآن'),
                          onPressed: _isSyncing
                              ? null
                              : () async {
                                  Navigator.pop(ctx);
                                  await _syncAllPending();
                                },
                        ),
                    ],
                  ),
                  const Divider(),
                  if (queue.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: Text('لا توجد حركات معلقة. جميع العمليات متزامنة ✓', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: queue.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, idx) {
                          final item = queue[idx];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: Colors.orange.shade100,
                              child: const Icon(Icons.wifi_off, color: Colors.orange, size: 20),
                            ),
                            title: Text(item['description']?.toString().isNotEmpty == true ? item['description'] : 'بدون بيان', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${item['date']} | ${item['payment_method']}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${item['amount']} ر.س', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                  onPressed: () async {
                                    await OfflineManager.removeAt(idx);
                                    final updated = await OfflineManager.getQueue();
                                    setSheetState(() {
                                      queue.clear();
                                      queue.addAll(updated);
                                    });
                                    _updatePendingCount();
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _extractName(dynamic obj) {
    if (obj is! Map) return obj.toString();
    return (obj['name'] ?? obj['bank_name'] ?? obj['card_name'] ?? obj['account_name'] ?? obj['الاسم'] ?? obj['اسم الحساب'] ?? '').toString();
  }

  String _extractId(dynamic obj, int fallbackIndex) {
    if (obj is! Map) return 'id_$fallbackIndex';
    final id = obj['id'] ?? obj['account_id'] ?? obj['card_id'] ?? obj['category_id'];
    return (id != null && id.toString().isNotEmpty) ? id.toString() : 'id_$fallbackIndex';
  }

  Future<void> _fetchSystemData() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();

    try {
      final res = await http.get(Uri.parse('$kBackendUrl?action=getInitialData')).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['ok'] == true && data['data'] != null) {
          await prefs.setString('cached_initial_data', res.body);
          _parseAndPopulateData(data['data']);
          return;
        }
      }
    } catch (_) {
      final cachedStr = prefs.getString('cached_initial_data');
      if (cachedStr != null) {
        final data = json.decode(cachedStr);
        _parseAndPopulateData(data['data']);
        return;
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _parseAndPopulateData(Map<String, dynamic> raw) {
    final rawAccounts = (raw['accounts'] as List?) ?? [];
    final rawCards = (raw['cards'] as List?) ?? [];
    final rawCategories = (raw['categories'] as List?) ?? [];
    final rawTempMaps = (raw['tempMaps'] as List?) ?? [];
    final rawTempSub = (raw['tempSubCategories'] as List?) ?? [];

    final parsedAccounts = <Map<String, String>>[];
    for (int i = 0; i < rawAccounts.length; i++) {
      final name = _extractName(rawAccounts[i]);
      if (name.isNotEmpty) parsedAccounts.add({'id': _extractId(rawAccounts[i], i), 'name': name});
    }

    final parsedCards = <Map<String, dynamic>>[];
    for (int i = 0; i < rawCards.length; i++) {
      final name = _extractName(rawCards[i]);
      final last4 = (rawCards[i]['last4'] ?? '').toString();
      final displayName = last4.isNotEmpty ? '$name (...$last4)' : name;
      final accId = (rawCards[i]['account_id'] ?? '').toString();
      if (name.isNotEmpty) parsedCards.add({'id': _extractId(rawCards[i], i), 'name': displayName, 'account_id': accId, 'last4': last4});
    }

    final parsedCategories = <Map<String, String>>[];
    for (int i = 0; i < rawCategories.length; i++) {
      final name = _extractName(rawCategories[i]);
      if (name.isNotEmpty) parsedCategories.add({'id': _extractId(rawCategories[i], i), 'name': name});
    }

    final parsedTempMaps = <Map<String, String>>[];
    for (int i = 0; i < rawTempMaps.length; i++) {
      final name = _extractName(rawTempMaps[i]);
      if (name.isNotEmpty) parsedTempMaps.add({'id': _extractId(rawTempMaps[i], i), 'name': name});
    }

    final parsedTempSub = <Map<String, dynamic>>[];
    for (int i = 0; i < rawTempSub.length; i++) {
      final name = _extractName(rawTempSub[i]);
      final mapId = (rawTempSub[i]['map_id'] ?? rawTempSub[i]['temp_map_id'] ?? '').toString();
      if (name.isNotEmpty) parsedTempSub.add({'id': _extractId(rawTempSub[i], i), 'name': name, 'map_id': mapId});
    }

    setState(() {
      _accountsList = parsedAccounts;
      _cardsList = parsedCards;
      _categoriesList = parsedCategories;
      _tempMapsList = parsedTempMaps;
      _tempSubCategoriesList = parsedTempSub;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final userName = widget.currentUser['display_name'] ?? widget.currentUser['username'] ?? 'المستخدم';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset('assets/app_icon.png', height: 26, width: 26, fit: BoxFit.cover),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('إبحار', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(_currentIndex == 0 ? 'تسجيل حركة' : 'تحويل بنكي', style: const TextStyle(fontSize: 10, color: Colors.white70)),
              ],
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: Icon(
                  _pendingCount > 0 ? Icons.cloud_queue : Icons.cloud_done,
                  color: _pendingCount > 0 ? Colors.amberAccent : Colors.white70,
                ),
                tooltip: 'المهام المعلقة',
                onPressed: _showPendingQueueSheet,
              ),
              if (_pendingCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '$_pendingCount',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث البيانات',
            onPressed: () {
              _fetchSystemData();
              _updatePendingCount();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'تسجيل الخروج',
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('bio_enabled');
              await prefs.remove('saved_user');
              await prefs.remove('saved_pass');
              if (!mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const FullLoginScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF0F4C81)),
                  SizedBox(height: 14),
                  Text('جاري تحميل البيانات...', style: TextStyle(color: Colors.black54)),
                ],
              ),
            )
          : Column(
              children: [
                if (_pendingCount > 0)
                  InkWell(
                    onTap: _showPendingQueueSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      color: Colors.amber.shade100,
                      child: Row(
                        children: [
                          const Icon(Icons.wifi_off, size: 16, color: Colors.orange),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'لديك $_pendingCount حركة معلقة بانتظار الإرسال للسيرفر',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.brown),
                            ),
                          ),
                          const Text('عرض وإرسال', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F4C81))),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: [
                      TransactionEntryScreen(
                        currentUser: userName,
                        accounts: _accountsList,
                        cards: _cardsList,
                        categories: _categoriesList,
                        tempMaps: _tempMapsList,
                        tempSubCategories: _tempSubCategoriesList,
                        onSuccess: () {
                          _fetchSystemData();
                          _updatePendingCount();
                        },
                        onOfflineSaved: _updatePendingCount,
                      ),
                      BankTransferScreen(
                        currentUser: userName,
                        accounts: _accountsList,
                        onSuccess: _fetchSystemData,
                      ),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF0F4C81),
        unselectedItemColor: Colors.black45,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'تسجيل حركة'),
          BottomNavigationBarItem(icon: Icon(Icons.swap_horiz), label: 'تحويل بنكي'),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// 4. شاشة تسجيل حركة مع ميزة اللصق الذكي وحوكمة الحقول
// -------------------------------------------------------------
class TransactionEntryScreen extends StatefulWidget {
  final String currentUser;
  final List<Map<String, String>> accounts;
  final List<Map<String, dynamic>> cards;
  final List<Map<String, String>> categories;
  final List<Map<String, String>> tempMaps;
  final List<Map<String, dynamic>> tempSubCategories;
  final VoidCallback onSuccess;
  final VoidCallback onOfflineSaved;

  const TransactionEntryScreen({
    super.key,
    required this.currentUser,
    required this.accounts,
    required this.cards,
    required this.categories,
    required this.tempMaps,
    required this.tempSubCategories,
    required this.onSuccess,
    required this.onOfflineSaved,
  });

  @override
  State<TransactionEntryScreen> createState() => _TransactionEntryScreenState();
}

class _TransactionEntryScreenState extends State<TransactionEntryScreen> {
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  String _movementType = 'مصروف';
  String _paymentMethod = 'بطاقة مدى';
  String? _selectedTempMapId;
  String? _selectedCategoryId;
  String? _selectedAccountId;
  String? _selectedCardId;

  final List<String> _movementTypes = ['مصروف', 'دخل'];
  final List<String> _paymentMethods = ['بطاقة مدى', 'بطاقة ائتمانية', 'حوالة بنكية', 'نقدي (كاش)'];

  InputDecoration _fieldStyle(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF0F4C81), fontWeight: FontWeight.bold),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
    );
  }

  List<Map<String, String>> _getFilteredCategories() {
    if (_selectedTempMapId != null && _selectedTempMapId!.isNotEmpty) {
      final filteredSub = widget.tempSubCategories
          .where((sub) => sub['map_id'].toString() == _selectedTempMapId)
          .map((sub) => {'id': sub['id'].toString(), 'name': sub['name'].toString()})
          .toList();

      if (filteredSub.isNotEmpty) return filteredSub;
    }
    return widget.categories;
  }

  void _applyPastedSms(String text) {
    if (text.trim().isEmpty) return;

    final result = BankSmsGovernanceParser.parse(text);

    String? matchedCategory;
    if (result.description.isNotEmpty && widget.categories.isNotEmpty) {
      final descUpper = result.description.toUpperCase();
      for (var cat in widget.categories) {
        final catName = (cat['name'] ?? '').toUpperCase();
        if ((descUpper.contains('GRO') || descUpper.contains('أسواق') || descUpper.contains('تموينات') || descUpper.contains('بنده')) &&
            (catName.contains('معيشة') || catName.contains('تموينات') || catName.contains('فضل'))) {
          matchedCategory = cat['id'];
          break;
        } else if ((descUpper.contains('GAS') || descUpper.contains('محطة') || descUpper.contains('وقود')) &&
            (catName.contains('سيارة') || catName.contains('وقود'))) {
          matchedCategory = cat['id'];
          break;
        } else if ((text.contains('ايمان') || text.contains('بنات')) &&
            (catName.contains('أولاد') || catName.contains('اولاد') || catName.contains('بنات'))) {
          matchedCategory = cat['id'];
          break;
        }
      }
    }

    setState(() {
      if (result.amount != null) {
        _amountController.text = result.amount.toString();
      }
      if (result.description.isNotEmpty) {
        _notesController.text = result.description;
      }
      _movementType = result.movementType;
      _paymentMethod = result.paymentMethod;

      if (result.cardLast4 != null && widget.cards.isNotEmpty) {
        final foundCard = widget.cards.firstWhere(
          (c) => c['last4'].toString().trim() == result.cardLast4!.trim() ||
                 c['name'].toString().contains(result.cardLast4!),
          orElse: () => {},
        );

        if (foundCard.isNotEmpty) {
          _selectedCardId = foundCard['id'].toString();
          if (foundCard['account_id'] != null && foundCard['account_id'].toString().isNotEmpty) {
            _selectedAccountId = foundCard['account_id'].toString();
          }
        }
      }

      if (_selectedAccountId == null && widget.accounts.isNotEmpty) {
        _selectedAccountId = widget.accounts.first['id'];
      }

      if (matchedCategory != null) {
        _selectedCategoryId = matchedCategory;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.teal,
        content: Text(
          result.amount != null
              ? 'تم استخراج البيانات: ${result.amount} ر.س | ${result.description}'
              : 'تم استخراج وتعبئة الخانات المكتشفة بنجاح.',
        ),
      ),
    );
  }

  Future<void> _submitData() async {
    final amt = double.tryParse(_amountController.text);
    if (amt == null || amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى تحديد المبلغ أولاً')));
      return;
    }

    setState(() => _isSaving = true);

    final payload = {
      "date": DateFormat('yyyy-MM-dd').format(_selectedDate),
      "amount": amt,
      "type": _movementType,
      "payment_method": _paymentMethod,
      "account_id": _selectedAccountId ?? (widget.accounts.isNotEmpty ? widget.accounts.first['id'] : ""),
      "card_id": _selectedCardId ?? "",
      "description": _notesController.text.trim(),
      "category_id": _selectedTempMapId == null ? (_selectedCategoryId ?? "") : "",
      "temp_map_id": _selectedTempMapId ?? "",
      "temp_subcat_id": _selectedTempMapId != null ? (_selectedCategoryId ?? "") : "",
      "user": "${widget.currentUser} (تطبيق)"
    };

    try {
      final uri = Uri.parse(kBackendUrl).replace(queryParameters: {
        'action': 'saveTransaction',
        'payload': json.encode(payload),
      });

      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      final data = json.decode(res.body);

      if (data['ok'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: Colors.teal, content: Text('تم تسجيل الحركة وإرسال الإشعار البريدي بنجاح!')),
        );
        _amountController.clear();
        _notesController.clear();
        widget.onSuccess();
      } else {
        throw Exception(data['error']);
      }
    } on SocketException catch (_) {
      await OfflineManager.enqueue(payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          content: Text('لا يوجد اتصال بالإنترنت. تم حفظ الحركة محلياً وستُرسل تلقائياً فور توفر الشبكة 💾'),
        ),
      );
      _amountController.clear();
      _notesController.clear();
      widget.onOfflineSaved();
    } catch (e) {
      await OfflineManager.enqueue(payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          content: Text('تعذر الوصول للسيرفر حالياً. تم حفظ الحركة في قائمة الانتظار للمزامنة 💾'),
        ),
      );
      _amountController.clear();
      _notesController.clear();
      widget.onOfflineSaved();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentCategories = _getFilteredCategories();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
              side: const BorderSide(color: Color(0xFF0F4C81), width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.paste, color: Color(0xFF0F4C81), size: 18),
            label: const Text('📋 لصق وقراءة الرسالة البنكية تلقائياً', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F4C81), fontSize: 13)),
            onPressed: () async {
              final data = await Clipboard.getData(Clipboard.kTextPlain);
              if (data != null && data.text != null) {
                _applyPastedSms(data.text!);
              } else {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('الحافظة فارغة، انسخ نص رسالة البنك أولاً')),
                );
              }
            },
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                flex: 5,
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) setState(() => _selectedDate = picked);
                  },
                  child: InputDecorator(
                    decoration: _fieldStyle('التاريخ'),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(Icons.calendar_month, size: 20, color: Color(0xFF0F4C81)),
                        Text(DateFormat('yyyy/MM/dd').format(_selectedDate), style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 5,
                child: TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                  decoration: _fieldStyle('المبلغ (ر.س)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _movementType,
                  dropdownColor: Colors.white,
                  style: const TextStyle(color: Colors.black87, fontSize: 13),
                  decoration: _fieldStyle('نوع الحركة'),
                  items: _movementTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (val) => setState(() => _movementType = val!),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _paymentMethod,
                  dropdownColor: Colors.white,
                  style: const TextStyle(color: Colors.black87, fontSize: 12),
                  decoration: _fieldStyle('طريقة الدفع'),
                  items: _paymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (val) => setState(() => _paymentMethod = val!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          DropdownButtonFormField<String?>(
            value: _selectedTempMapId,
            dropdownColor: Colors.white,
            style: const TextStyle(color: Colors.black87, fontSize: 13),
            decoration: _fieldStyle('جهة الصرف / الخريطة المؤقتة'),
            hint: const Text('(خريطة الصرف العامة)', style: TextStyle(color: Colors.black54, fontSize: 13)),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('بدون جهة خاصة (خريطة الصرف العامة)', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
              ),
              ...widget.tempMaps.map((map) {
                return DropdownMenuItem<String?>(
                  value: map['id'],
                  child: Text(map['name'] ?? '', style: const TextStyle(color: Colors.black87)),
                );
              }),
            ],
            onChanged: (val) {
              setState(() {
                _selectedTempMapId = val;
                _selectedCategoryId = null;
              });
            },
          ),
          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            value: _selectedCategoryId,
            dropdownColor: Colors.white,
            style: const TextStyle(color: Colors.black87, fontSize: 13),
            decoration: _fieldStyle(_selectedTempMapId != null ? 'البند التابع للخطة المؤقتة' : 'البند الرئيسي'),
            hint: Text(_selectedTempMapId != null ? 'اختر البند التابع للخطة...' : 'اختر البند الرئيسي...', style: const TextStyle(color: Colors.black54, fontSize: 12)),
            items: currentCategories.map((cat) {
              return DropdownMenuItem<String>(
                value: cat['id'],
                child: Text(cat['name'] ?? '', style: const TextStyle(color: Colors.black87)),
              );
            }).toList(),
            onChanged: (val) => setState(() => _selectedCategoryId = val),
          ),
          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            value: _selectedAccountId,
            dropdownColor: Colors.white,
            style: const TextStyle(color: Colors.black87, fontSize: 13),
            decoration: _fieldStyle('الحساب البنكي'),
            hint: const Text('اختر الحساب المصدر...', style: TextStyle(color: Colors.black54, fontSize: 12)),
            items: widget.accounts.map((acc) {
              return DropdownMenuItem<String>(
                value: acc['id'],
                child: Text(acc['name'] ?? '', style: const TextStyle(color: Colors.black87)),
              );
            }).toList(),
            onChanged: (val) => setState(() => _selectedAccountId = val),
          ),
          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            value: _selectedCardId,
            dropdownColor: Colors.white,
            style: const TextStyle(color: Colors.black87, fontSize: 13),
            decoration: _fieldStyle('البطاقة المستخدمة'),
            hint: const Text('بدون بطاقة...', style: TextStyle(color: Colors.black54, fontSize: 12)),
            items: [
              const DropdownMenuItem<String>(
                value: '',
                child: Text('بدون بطاقة', style: TextStyle(color: Colors.black54)),
              ),
              ...widget.cards.map((card) {
                return DropdownMenuItem<String>(
                  value: card['id'].toString(),
                  child: Text(
                    card['name'] ?? '',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                  ),
                );
              }),
            ],
            onChanged: (val) => setState(() => _selectedCardId = val),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _notesController,
            style: const TextStyle(color: Colors.black87),
            decoration: _fieldStyle('البيان / سبب الشراء').copyWith(
              hintText: 'مثال: وقود، تموينات...',
              hintStyle: const TextStyle(fontSize: 12, color: Colors.black38),
            ),
          ),
          const SizedBox(height: 20),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F4C81),
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: _isSaving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check, color: Colors.white),
            label: Text(
              _isSaving ? 'جاري الحفظ...' : 'حفظ الحركة المالية',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            onPressed: _isSaving ? null : _submitData,
          ),

          const SizedBox(height: 24),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/logo.png', height: 60, fit: BoxFit.contain),
                const SizedBox(height: 4),
                const Text(
                  'المالك/ فضل بن عباس القديحي',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F4C81), letterSpacing: 0.2),
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// 5. شاشة التحويل بين الحسابات
// -------------------------------------------------------------
class BankTransferScreen extends StatefulWidget {
  final String currentUser;
  final List<Map<String, String>> accounts;
  final VoidCallback onSuccess;

  const BankTransferScreen({
    super.key,
    required this.currentUser,
    required this.accounts,
    required this.onSuccess,
  });

  @override
  State<BankTransferScreen> createState() => _BankTransferScreenState();
}

class _BankTransferScreenState extends State<BankTransferScreen> {
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  String? _fromAccountId;
  String? _toAccountId;
  bool _isTransferring = false;

  Future<void> _submitTransfer() async {
    final amt = double.tryParse(_amountController.text);
    if (amt == null || amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى تحديد مبلغ التحويل')));
      return;
    }

    if (_fromAccountId == null || _toAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى اختيار الحساب المحول منه وإليه')));
      return;
    }

    if (_fromAccountId == _toAccountId) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يمكن التحويل لنفس الحساب')));
      return;
    }

    setState(() => _isTransferring = true);

    try {
      final uri = Uri.parse(kBackendUrl).replace(queryParameters: {
        'action': 'transfer',
        'fromAccId': _fromAccountId,
        'toAccId': _toAccountId,
        'amount': amt.toString(),
        'notes': _notesController.text.trim(),
        'user': widget.currentUser,
      });

      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      final data = json.decode(res.body);

      if (data['ok'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: Colors.teal, content: Text('تم التحويل وتحديث الأرصدة بنجاح!')),
        );
        _amountController.clear();
        _notesController.clear();
        widget.onSuccess();
      } else {
        throw Exception(data['error'] ?? 'تعذر التحويل');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.redAccent, content: Text('خطأ أثناء التحويل: $e')),
      );
    } finally {
      if (mounted) setState(() => _isTransferring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            value: _fromAccountId,
            dropdownColor: Colors.white,
            style: const TextStyle(color: Colors.black87),
            decoration: const InputDecoration(
              labelText: 'من حساب',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(),
            ),
            hint: const Text('اختر حساب المصدر...', style: TextStyle(color: Colors.black54)),
            items: widget.accounts.map((acc) {
              return DropdownMenuItem<String>(
                value: acc['id'],
                child: Text(acc['name'] ?? ''),
              );
            }).toList(),
            onChanged: (val) => setState(() => _fromAccountId = val),
          ),
          const SizedBox(height: 12),
          const Center(child: Icon(Icons.arrow_downward, color: Color(0xFF0F4C81))),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _toAccountId,
            dropdownColor: Colors.white,
            style: const TextStyle(color: Colors.black87),
            decoration: const InputDecoration(
              labelText: 'إلى حساب',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(),
            ),
            hint: const Text('اختر الحساب المحول إليه...', style: TextStyle(color: Colors.black54)),
            items: widget.accounts.map((acc) {
              return DropdownMenuItem<String>(
                value: acc['id'],
                child: Text(acc['name'] ?? ''),
              );
            }).toList(),
            onChanged: (val) => setState(() => _toAccountId = val),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              labelText: 'المبلغ المحوّل (ر.س)',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _notesController,
            style: const TextStyle(color: Colors.black87),
            decoration: const InputDecoration(
              labelText: 'البيان / سبب التحويل',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F4C81),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: _isTransferring
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check, color: Colors.white),
              label: Text(
                _isTransferring ? 'جاري التحويل...' : 'تأكيد التحويل البنكي',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              onPressed: _isTransferring ? null : _submitTransfer,
            ),
          ),
        ],
      ),
    );
  }
}
