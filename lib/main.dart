import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:local_auth/local_auth.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String kBackendUrl = 'https://script.google.com/macros/s/AKfycby6jmx9r5SYs1b4NdwCHSHmB9ctqkLh5AgQjv5DIJlJugj05D92maiRpIsoRN3dr_5yRw/exec';

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
// بوابة الفحص: تحديد مسار الدخول (بصمة دائمة أو تسجيل يدوي)
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
// شاشة تسجيل الدخول الأولى
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

      final res = await http.get(uri);
      final data = json.decode(res.body);

      if (data['ok'] == true) {
        final prefs = await SharedPreferences.getInstance();
        if (_enableBiometrics) {
          await prefs.setBool('bio_enabled', true);
          await prefs.setString('saved_user', username);
          await prefs.setString('saved_pass', password);
        } else {
          await prefs.clear();
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
      setState(() => _errorMsg = 'تعذر التحقق من الحساب: \$e');
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
                // الشعار المعتمد الجديد
                Image.asset(
                  'assets/logo.png',
                  height: 110,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 8),
                const Text(
                  'منظومة الإدارة والمحاسبة الذكية',
                  style: TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w500),
                ),
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
                // سطر توثيق المالك في أسفل شاشة الدخول
                const Text(
                  'المالك/ فضل بن عباس القديحي',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F4C81),
                    letterSpacing: 0.2,
                  ),
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
// شاشة الدخول السريع بالبصمة
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
      final didAuth = await _auth.authenticate(
        localizedReason: 'المس مستشعر البصمة للمتابعة لحساب \${widget.username}',
        options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
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

      final res = await http.get(uri);
      final data = json.decode(res.body);

      if (data['ok'] == true && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => MainDashboard(currentUser: data['data'] ?? {'username': widget.username}),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? 'تم تعطيل الحساب أو تغيير كلمة المرور')),
        );
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
    await prefs.clear();
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/logo.png',
                  height: 90,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 14),
                Text('مرحباً \${widget.username}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F4C81))),
                const SizedBox(height: 6),
                const Text('الدخول السريع عبر البصمة', style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 32),

                InkWell(
                  onTap: _authenticate,
                  borderRadius: BorderRadius.circular(60),
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF0F4C81), width: 2),
                      color: const Color(0xFF0F4C81).withOpacity(0.06),
                    ),
                    child: _isVerifying
                        ? const CircularProgressIndicator(color: Color(0xFF0F4C81))
                        : const Icon(Icons.fingerprint, size: 70, color: Color(0xFF0F4C81)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('المس المستشعر لإعادة المحاولة', style: TextStyle(fontSize: 13, color: Colors.black54)),
                const SizedBox(height: 28),

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
// الشاشة الرئيسية المشتركة (Dashboard)
// -------------------------------------------------------------
class MainDashboard extends StatefulWidget {
  final Map<String
