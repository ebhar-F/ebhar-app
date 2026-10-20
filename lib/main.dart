import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:local_auth/local_auth.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

// رابط الـ Web App لمنظومة إبحار في Google Apps Script
const String webAppUrl = "https://script.google.com/macros/s/AKfycby6jmx9r5SYs1b4NdwCHSHmB9ctqkLh5AgQjv05DIJJugj05D92maiRplsoRN3dr_5yRw/exec";

void main() {
  runApp(const EbharApp());
}

class EbharApp extends StatelessWidget {
  const EbharApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'إبحار',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'SA'),
      supportedLocales: const [Locale('ar', 'SA')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        primaryColor: const Color(0xFF0F2C42),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F2C42),
          primary: const Color(0xFF0F2C42),
          secondary: const Color(0xFF088395),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F2C42),
          elevation: 0,
          centerTitle: true,
        ),
      ),
      home: const AuthScreen(),
    );
  }
}

// 1. شاشة الدخول ببصمة الإصبع
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    _authenticateWithBiometrics();
  }

  Future<void> _authenticateWithBiometrics() async {
    bool authenticated = false;
    try {
      setState(() => _isAuthenticating = true);
      bool canCheckBiometrics = await auth.canCheckBiometrics;
      bool isDeviceSupported = await auth.isDeviceSupported();

      if (canCheckBiometrics && isDeviceSupported) {
        authenticated = await auth.authenticate(
          localizedReason: 'يرجى تأكيد بصمة الإصبع للدخول إلى إبحار',
          options: const AuthenticationOptions(
            biometricOnly: true,
            stickyAuth: true,
          ),
        );
      }
    } on PlatformException catch (e) {
      debugPrint("خطأ في البصمة: $e");
    } finally {
      if (mounted) setState(() => _isAuthenticating = false);
    }

    if (authenticated && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainHomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F2C42), Color(0xFF0A4D68)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.sailing, size: 70, color: Colors.cyanAccent),
            ),
            const SizedBox(height: 20),
            const Text(
              'إبـحـار',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'منظومة الإدارة والمحاسبة الذكية',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 60),
            IconButton(
              iconSize: 75,
              icon: const Icon(Icons.fingerprint, color: Colors.cyanAccent),
              onPressed: _authenticateWithBiometrics,
            ),
            const SizedBox(height: 12),
            const Text(
              'المس مستشعر البصمة للمتابعة',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

// 2. الهيكل الرئيسي وشريط التنقل
class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const RecordTransactionScreen(),
    const TransferScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'إبـحـار',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.lock_outline, color: Colors.white),
            tooltip: 'قفل التطبيق',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const AuthScreen()),
              );
            },
          )
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: const Color(0xFF0F2C42),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.post_add),
            label: 'تسجيل حركة',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sync_alt),
            label: 'تحويل بنكي',
          ),
        ],
      ),
    );
  }
}

// 3. شاشة تسجيل حركة جديدة
class RecordTransactionScreen extends StatefulWidget {
  const RecordTransactionScreen({super.key});

  @override
  State<RecordTransactionScreen> createState() => _RecordTransactionScreenState();
}

class _RecordTransactionScreenState extends State<RecordTransactionScreen> {
  final _amountController = TextEditingController();
  final _descController = TextEditingController();

  String _type = 'مصروف';
  String _paymentMethod = 'بطاقة مدى';
  String _category = 'فضل';
  String _account = 'الراجحي';
  bool _loading = false;

  final List<String> categories = ['فضل', 'العزبة', 'صيانة', 'الاولاد', 'المركبات', 'احتياطي', 'مدام', 'الام', 'الكهرباء والماء', 'التبرعات'];
  final List<String> accounts = ['الراجحي', 'الأهلي'];
  final List<String> paymentMethods = ['بطاقة مدى', 'بطاقة ائتمانية', 'كاش', 'حوالة بنكية'];

  Future<void> _submitTransaction() async {
    final amt = double.tryParse(_amountController.text.trim());
    final desc = _descController.text.trim();

    if (amt == null || amt <= 0 || desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى كتابة المبلغ والبيان بصورة صحيحة')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final payload = {
        "action": "saveTransactionFast",
        "date": DateFormat('yyyy-MM-dd').format(DateTime.now()),
        "amount": amt,
        "type": _type,
        "payment_method": _paymentMethod,
        "description": desc,
        "category_name": _category,
        "account_name": _account,
        "user": "admin"
      };

      await http.post(
        Uri.parse(webAppUrl),
        body: jsonEncode(payload),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تسجيل الحركة بنجاح!')),
      );
      _amountController.clear();
      _descController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الاتصال: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('نوع الحركة:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ToggleButtons(
                    isSelected: [_type == 'مصروف', _type == 'دخل'],
                    onPressed: (index) {
                      setState(() => _type = index == 0 ? 'مصروف' : 'دخل');
                    },
                    borderRadius: BorderRadius.circular(8),
                    selectedColor: Colors.white,
                    fillColor: _type == 'مصروف' ? Colors.red : Colors.green,
                    children: const [
                      Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('مصروف')),
                      Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('دخل')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'المبلغ',
                  suffixText: 'ر.س',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descController,
                decoration: InputDecoration(
                  labelText: 'البيان (سبب الصرف)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: InputDecoration(
                  labelText: 'البند الرئيسي',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) => setState(() => _category = val!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _account,
                decoration: InputDecoration(
                  labelText: 'الحساب البنكي',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: accounts.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                onChanged: (val) => setState(() => _account = val!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _paymentMethod,
                decoration: InputDecoration(
                  labelText: 'طريقة الدفع',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: paymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (val) => setState(() => _paymentMethod = val!),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : _submitTransaction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F2C42),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('حفظ الحركة', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 4. شاشة التحويل بين الحسابات
class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  String _fromAccount = 'الراجحي';
  String _toAccount = 'الأهلي';
  bool _loading = false;

  final List<String> accounts = ['الراجحي', 'الأهلي'];

  Future<void> _executeTransfer() async {
    final amt = double.tryParse(_amountController.text.trim());
    if (amt == null || amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال مبلغ التحويل')),
      );
      return;
    }

    if (_fromAccount == _toAccount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن التحويل لنفس الحساب')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final payload = {
        "action": "executeTransfer",
        "from_account": _fromAccount,
        "to_account": _toAccount,
        "amount": amt,
        "notes": _notesController.text.trim(),
        "user": "admin"
      };

      await http.post(
        Uri.parse(webAppUrl),
        body: jsonEncode(payload),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تنفيذ التحويل بنجاح!')),
      );
      _amountController.clear();
      _notesController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء التحويل: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.sync_alt, color: Color(0xFF0F2C42)),
                  SizedBox(width: 8),
                  Text('تحويل مالي بين الحسابات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              const Divider(height: 24),
              DropdownButtonFormField<String>(
                value: _fromAccount,
                decoration: InputDecoration(
                  labelText: 'من الحساب (المُرسِل)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: accounts.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                onChanged: (val) => setState(() => _fromAccount = val!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _toAccount,
                decoration: InputDecoration(
                  labelText: 'إلى الحساب (المُستلِم)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: accounts.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                onChanged: (val) => setState(() => _toAccount = val!),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'المبلغ المحول',
                  suffixText: 'ر.س',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: 'ملاحظات التحويل (اختياري)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : _executeTransfer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF088395),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('تنفيذ التحويل المالي', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
