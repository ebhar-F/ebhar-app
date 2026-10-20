import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:local_auth/local_auth.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

// الرابط البرمجي لمنظومة إبحار
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
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D1B2A),
        primaryColor: const Color(0xFF00ADB5),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00ADB5),
          secondary: Color(0xFF1B2A47),
          surface: Color(0xFF14243B),
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
      home: const LoginScreen(),
    );
  }
}

// -------------------------------------------------------------
// شاشة تسجيل الدخول
// -------------------------------------------------------------
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final LocalAuthentication _auth = LocalAuthentication();
  final TextEditingController _userController = TextEditingController(text: 'admin');
  final TextEditingController _passwordController = TextEditingController();
  bool _rememberMe = true;
  bool _showPasswordFields = false;
  String _authStatus = '';

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 600), () {
      _authenticate();
    });
  }

  Future<void> _authenticate() async {
    try {
      final bool canCheck = await _auth.canCheckBiometrics;
      final bool isSupported = await _auth.isDeviceSupported();

      if (!canCheck && !isSupported) {
        setState(() {
          _authStatus = 'مستشعر البصمة غير متوفر، استخدم اسم المستخدم';
          _showPasswordFields = true;
        });
        return;
      }

      final bool didAuth = await _auth.authenticate(
        localizedReason: 'المس مستشعر البصمة للمتابعة لتطبيق إبحار',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      if (didAuth && mounted) {
        _goToDashboard();
      }
    } catch (e) {
      setState(() {
        _authStatus = 'يرجى تسجيل الدخول يدوياً';
        _showPasswordFields = true;
      });
    }
  }

  void _goToDashboard() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const MainDashboard()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.06),
                  ),
                  child: const Icon(Icons.sailing, size: 70, color: Color(0xFF00ADB5)),
                ),
                const SizedBox(height: 16),
                const Text(
                  'إبحار',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 4),
                const Text(
                  'منظومة الإدارة والمحاسبة الذكية',
                  style: TextStyle(fontSize: 14, color: Colors.white60),
                ),
                const SizedBox(height: 32),

                InkWell(
                  onTap: _authenticate,
                  borderRadius: BorderRadius.circular(50),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF00ADB5), width: 2),
                      color: const Color(0xFF00ADB5).withOpacity(0.12),
                    ),
                    child: const Icon(Icons.fingerprint, size: 65, color: Color(0xFF00ADB5)),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'المس مستشعر البصمة للمتابعة الفورية',
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                ),

                if (_authStatus.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(_authStatus, style: const TextStyle(fontSize: 12, color: Colors.amberAccent)),
                ],

                const SizedBox(height: 20),
                TextButton.icon(
                  onPressed: () => setState(() => _showPasswordFields = !_showPasswordFields),
                  icon: Icon(_showPasswordFields ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: const Color(0xFF00ADB5)),
                  label: Text(
                    _showPasswordFields ? 'إخفاء الدخول اليدوي' : 'الدخول باسم المستخدم وكلمة المرور',
                    style: const TextStyle(color: Color(0xFF00ADB5)),
                  ),
                ),

                if (_showPasswordFields) ...[
                  const SizedBox(height: 14),
                  TextField(
                    controller: _userController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.person, color: Color(0xFF00ADB5)),
                      labelText: 'اسم المستخدم',
                      filled: true,
                      fillColor: const Color(0xFF14243B),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock, color: Color(0xFF00ADB5)),
                      labelText: 'كلمة المرور',
                      filled: true,
                      fillColor: const Color(0xFF14243B),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        activeColor: const Color(0xFF00ADB5),
                        onChanged: (val) => setState(() => _rememberMe = val ?? true),
                      ),
                      const Text('تذكر بيانات الدخول', style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00ADB5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _goToDashboard,
                      child: const Text('تسجيل الدخول', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// الشاشة الرئيسية المشتركة وإدارة البيانات
// -------------------------------------------------------------
class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _currentIndex = 0;
  bool _isLoading = true;

  List<dynamic> _accounts = [];
  List<dynamic> _cards = [];
  List<dynamic> _categories = [];
  List<dynamic> _tempMaps = [];

  @override
  void initState() {
    super.initState();
    _fetchSystemData();
  }

  Future<void> _fetchSystemData() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(Uri.parse('$kBackendUrl?action=getInitialData'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['ok'] == true && data['data'] != null) {
          setState(() {
            _accounts = data['data']['accounts'] ?? [];
            _cards = data['data']['cards'] ?? [];
            _categories = data['data']['categories'] ?? [];
            _tempMaps = data['data']['tempMaps'] ?? [];
            _isLoading = false;
          });
          return;
        }
      }
    } catch (_) {}

    // خطة احتياطية في حال تعذر الاتصال
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentIndex == 0 ? 'تسجيل حركة مالية جديدة' : 'تحويل بين الحسابات'),
        centerTitle: true,
        backgroundColor: const Color(0xFF101F33),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث البيانات من الشيت',
            onPressed: _fetchSystemData,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'خروج',
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
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
                  CircularProgressIndicator(color: Color(0xFF00ADB5)),
                  SizedBox(height: 16),
                  Text('جاري جلب البنود والحسابات من إبحار...', style: TextStyle(color: Colors.white70)),
                ],
              ),
            )
          : IndexedStack(
              index: _currentIndex,
              children: [
                TransactionEntryScreen(
                  accounts: _accounts,
                  cards: _cards,
                  categories: _categories,
                  tempMaps: _tempMaps,
                  onSuccess: _fetchSystemData,
                ),
                BankTransferScreen(
                  accounts: _accounts,
                  onSuccess: _fetchSystemData,
                ),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: const Color(0xFF101F33),
        selectedItemColor: const Color(0xFF00ADB5),
        unselectedItemColor: Colors.white54,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'تسجيل حركة'),
          BottomNavigationBarItem(icon: Icon(Icons.swap_horiz), label: 'تحويل بنكي'),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// شاشة تسجيل حركة مالية جديدة (متصلة بالشيت بالكامل)
// -------------------------------------------------------------
class TransactionEntryScreen extends StatefulWidget {
  final List<dynamic> accounts;
  final List<dynamic> cards;
  final List<dynamic> categories;
  final List<dynamic> tempMaps;
  final VoidCallback onSuccess;

  const TransactionEntryScreen({
    super.key,
    required this.accounts,
    required this.cards,
    required this.categories,
    required this.tempMaps,
    required this.onSuccess,
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
  final List<String> _paymentMethods = ['بطاقة مدى', 'حوالة بنكية', 'نقدي (كاش)', 'بطاقة ائتمانية'];

  InputDecoration _fieldStyle(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 13, color: Colors.white70),
      filled: true,
      fillColor: const Color(0xFF14243B),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24)),
    );
  }

  Future<void> _submitData() async {
    final amt = double.tryParse(_amountController.text);
    if (amt == null || amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال مبلغ صحيح')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final payload = {
      "date": DateFormat('yyyy-MM-dd').format(_selectedDate),
      "amount": amt,
      "type": _movementType,
      "payment_method": _paymentMethod,
      "account_id": _selectedAccountId ?? "",
      "card_id": _selectedCardId ?? "",
      "description": _notesController.text.trim(),
      "category_id": _selectedCategoryId ?? "",
      "temp_map_id": _selectedTempMapId ?? "",
      "user": "admin"
    };

    try {
      final res = await http.post(
        Uri.parse(kBackendUrl),
        body: json.encode({"action": "saveTransaction", "payload": payload}),
      );

      final data = json.decode(res.body);
      if (data['ok'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.teal,
            content: Text('تم حفظ الحركة وتحديث الرصيد في إبحار بنجاح!'),
          ),
        );
        _amountController.clear();
        _notesController.clear();
        widget.onSuccess();
      } else {
        throw Exception(data['error'] ?? 'خطأ أثناء الحفظ');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.redAccent, content: Text('فشل الحفظ: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. التاريخ والمبلغ
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
                        const Icon(Icons.calendar_month, size: 18, color: Colors.white70),
                        Text(DateFormat('yyyy/MM/dd').format(_selectedDate), style: const TextStyle(fontSize: 13)),
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
                  decoration: _fieldStyle('المبلغ (ر.س)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2. نوع الحركة وطريقة الدفع
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _movementType,
                  decoration: _fieldStyle('نوع الحركة'),
                  items: _movementTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (val) => setState(() => _movementType = val!),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _paymentMethod,
                  decoration: _fieldStyle('طريقة الدفع'),
                  items: _paymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (val) => setState(() => _paymentMethod = val!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3. جهة الصرف (ديناميكية من TempMaps أو ثوابت)
          DropdownButtonFormField<String>(
            value: _selectedTempMapId,
            decoration: _fieldStyle('جهة الصرف / الخريطة'),
            hint: const Text('خريطة الصرف الرئيسية', style: TextStyle(fontSize: 13, color: Colors.white54)),
            items: widget.tempMaps.map((map) {
              return DropdownMenuItem<String>(
                value: map['id']?.toString(),
                child: Text(map['name']?.toString() ?? '', style: const TextStyle(fontSize: 13)),
              );
            }).toList(),
            onChanged: (val) => setState(() => _selectedTempMapId = val),
          ),
          const SizedBox(height: 12),

          // 4. البند الرئيسي (ديناميكي من Categories)
          DropdownButtonFormField<String>(
            value: _selectedCategoryId,
            decoration: _fieldStyle('البند الرئيسي'),
            hint: const Text('اختر البند...', style: TextStyle(fontSize: 13, color: Colors.white54)),
            items: widget.categories.map((cat) {
              return DropdownMenuItem<String>(
                value: cat['id']?.toString(),
                child: Text(cat['name']?.toString() ?? '', style: const TextStyle(fontSize: 13)),
              );
            }).toList(),
            onChanged: (val) => setState(() => _selectedCategoryId = val),
          ),
          const SizedBox(height: 12),

          // 5. الحساب البنكي والبطاقة المستخدمة (ديناميكية من Accounts و Cards)
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedAccountId,
                  decoration: _fieldStyle('الحساب البنكي'),
                  hint: const Text('اختر الحساب...', style: TextStyle(fontSize: 12, color: Colors.white54)),
                  items: widget.accounts.map((acc) {
                    return DropdownMenuItem<String>(
                      value: acc['id']?.toString(),
                      child: Text(acc['name']?.toString() ?? '', style: const TextStyle(fontSize: 12)),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedAccountId = val),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedCardId,
                  decoration: _fieldStyle('البطاقة المستخدمة'),
                  hint: const Text('بدون بطاقة...', style: TextStyle(fontSize: 11, color: Colors.white54)),
                  items: [
                    const DropdownMenuItem<String>(value: '', child: Text('بدون بطاقة', style: TextStyle(fontSize: 11))),
                    ...widget.cards.map((card) {
                      return DropdownMenuItem<String>(
                        value: card['id']?.toString(),
                        child: Text(card['name']?.toString() ?? '', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                      );
                    }),
                  ],
                  onChanged: (val) => setState(() => _selectedCardId = val),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 6. البيان / سبب الشراء
          TextField(
            controller: _notesController,
            decoration: _fieldStyle('البيان / سبب الشراء').copyWith(
              hintText: 'مثال: وقود، تموينات...',
              hintStyle: const TextStyle(fontSize: 12, color: Colors.white38),
            ),
          ),
          const SizedBox(height: 20),

          // 7. زر الحفظ
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F3057),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: _isSaving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check, color: Colors.white),
            label: Text(
              _isSaving ? 'جاري الحفظ في الشيت...' : 'حفظ الحركة المالية',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            onPressed: _isSaving ? null : _submitData,
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// شاشة التحويل بين الحسابات البنكية (متصلة بالشيت)
// -------------------------------------------------------------
class BankTransferScreen extends StatefulWidget {
  final List<dynamic> accounts;
  final VoidCallback onSuccess;

  const BankTransferScreen({
    super.key,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تحديد مبلغ تحويل صحيح')),
      );
      return;
    }

    if (_fromAccountId == null || _toAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار الحساب المصدر والحساب الهدف')),
      );
      return;
    }

    if (_fromAccountId == _toAccountId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن التحويل لنفس الحساب')),
      );
      return;
    }

    setState(() => _isTransferring = true);

    try {
      final res = await http.post(
        Uri.parse(kBackendUrl),
        body: json.encode({
          "action": "transfer",
          "fromAccId": _fromAccountId,
          "toAccId": _toAccountId,
          "amount": amt,
          "notes": _notesController.text.trim(),
          "user": "admin"
        }),
      );

      final data = json.decode(res.body);
      if (data['ok'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.teal,
            content: Text('تم تنفيذ التحويل البنكي وتحديث الأرصدة بنجاح!'),
          ),
        );
        _amountController.clear();
        _notesController.clear();
        widget.onSuccess();
      } else {
        throw Exception(data['error'] ?? 'خطأ أثناء التحويل');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.redAccent, content: Text('فشل التحويل: $e')),
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
            decoration: const InputDecoration(labelText: 'من حساب', filled: true, fillColor: Color(0xFF14243B)),
            hint: const Text('اختر حساب المصدر...'),
            items: widget.accounts.map((acc) {
              return DropdownMenuItem<String>(
                value: acc['id']?.toString(),
                child: Text(acc['name']?.toString() ?? ''),
              );
            }).toList(),
            onChanged: (val) => setState(() => _fromAccountId = val),
          ),
          const SizedBox(height: 12),
          const Center(child: Icon(Icons.arrow_downward, color: Color(0xFF00ADB5))),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _toAccountId,
            decoration: const InputDecoration(labelText: 'إلى حساب', filled: true, fillColor: Color(0xFF14243B)),
            hint: const Text('اختر الحساب المحول إليه...'),
            items: widget.accounts.map((acc) {
              return DropdownMenuItem<String>(
                value: acc['id']?.toString(),
                child: Text(acc['name']?.toString() ?? ''),
              );
            }).toList(),
            onChanged: (val) => setState(() => _toAccountId = val),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'المبلغ المحوّل (ر.س)', filled: true, fillColor: Color(0xFF14243B)),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(labelText: 'البيان / سبب التحويل', filled: true, fillColor: Color(0xFF14243B)),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F3057),
              padding: const EdgeInsets.symmetric(vertical: 14),
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
        ],
      ),
    );
  }
}
