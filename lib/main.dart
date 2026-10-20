import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:local_auth/local_auth.dart';
import 'package:intl/intl.dart';

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
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _rememberMe = true;
  bool _showPasswordFields = false;
  String _authStatus = '';

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 500), () {
      _authenticate();
    });
  }

  Future<void> _authenticate() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();

      if (!canAuthenticate) {
        setState(() {
          _authStatus = 'البصمة غير متوفرة أو غير مفعلة على هذا الهاتف';
          _showPasswordFields = true;
        });
        return;
      }

      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'يرجى لمس مستشعر البصمة للمتابعة لتطبيق إبحار',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      if (didAuthenticate && mounted) {
        _goToHome();
      }
    } on PlatformException catch (e) {
      setState(() {
        _authStatus = 'خطأ البصمة: ${e.message ?? e.code}';
        _showPasswordFields = true;
      });
    } catch (e) {
      setState(() {
        _authStatus = 'تعذر تشغيل مستشعر البصمة';
        _showPasswordFields = true;
      });
    }
  }

  void _goToHome() {
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
                  'المس مستشعر البصمة للمتابعة السريعة',
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                ),

                if (_authStatus.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    _authStatus,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Colors.amberAccent),
                  ),
                ],

                const SizedBox(height: 20),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _showPasswordFields = !_showPasswordFields;
                    });
                  },
                  icon: Icon(
                    _showPasswordFields ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: const Color(0xFF00ADB5),
                  ),
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
                      onPressed: _goToHome,
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
// الشاشة الرئيسية
// -------------------------------------------------------------
class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    TransactionEntryScreen(),
    BankTransferScreen(),
  ];

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
      body: _screens[_currentIndex],
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
// شاشة تسجيل حركة مالية جديدة (مطابقة تماماً للصورة)
// -------------------------------------------------------------
class TransactionEntryScreen extends StatefulWidget {
  const TransactionEntryScreen({super.key});

  @override
  State<TransactionEntryScreen> createState() => _TransactionEntryScreenState();
}

class _TransactionEntryScreenState extends State<TransactionEntryScreen> {
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  String _movementType = 'مصروف';
  String _paymentMethod = 'بطاقة مدى';
  String _spendingSide = 'خريطة الصرف الرئيسية';
  String _mainItem = 'فضل';
  String _bankAccount = 'مصرف الراجحي';
  String _cardUsed = 'بدون بطاقة (أو حوالة مباشرة)...';

  final List<String> _movementTypes = ['مصروف', 'إيراد'];
  final List<String> _paymentMethods = ['بطاقة مدى', 'تحويل بنكي', 'نقدي (كاش)', 'فيزا / ماستركارد'];
  final List<String> _spendingSides = ['خريطة الصرف الرئيسية', 'مصروفات تشغيلية', 'مصروفات رأسمالية', 'إدارية وعمومية'];
  final List<String> _mainItems = ['فضل', 'بضائع ومخزون', 'رواتب وأجور', 'إيجارات ومقر', 'نثريات وفواتير'];
  final List<String> _bankAccounts = ['اختر الحساب...', 'مصرف الراجحي', 'البنك الأهلي', 'الإنماء', 'الخزينة النقدية'];
  final List<String> _cardsUsed = [
    'بدون بطاقة (أو حوالة مباشرة)...',
    'بطاقة مدى - الراجحي (...4120)',
    'بطاقة مدى - الأهلي (...9051)',
    'بطاقة ائتمانية (...3310)'
  ];

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

  void _submitData() {
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال المبلغ أولاً')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.teal,
        content: Text('تم تسجيل ${_movementType} بمبلغ ${_amountController.text} ر.س بنجاح'),
      ),
    );

    _amountController.clear();
    _notesController.clear();
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

          // 3. جهة الصرف
          DropdownButtonFormField<String>(
            value: _spendingSide,
            decoration: _fieldStyle('جهة الصرف'),
            items: _spendingSides.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: (val) => setState(() => _spendingSide = val!),
          ),
          const SizedBox(height: 12),

          // 4. البند الرئيسي
          DropdownButtonFormField<String>(
            value: _mainItem,
            decoration: _fieldStyle('البند الرئيسي'),
            items: _mainItems.map((b) => DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: (val) => setState(() => _mainItem = val!),
          ),
          const SizedBox(height: 12),

          // 5. الحساب البنكي والبطاقة المستخدمة
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _bankAccount,
                  decoration: _fieldStyle('الحساب البنكي'),
                  items: _bankAccounts.map((a) => DropdownMenuItem(value: a, child: Text(a, style: const TextStyle(fontSize: 12)))).toList(),
                  onChanged: (val) => setState(() => _bankAccount = val!),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _cardUsed,
                  decoration: _fieldStyle('البطاقة المستخدمة'),
                  items: _cardsUsed.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)))).toList(),
                  onChanged: (val) => setState(() => _cardUsed = val!),
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

          // 7. زر حفظ الحركة المالية
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F3057),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.check, color: Colors.white),
            label: const Text(
              'حفظ الحركة المالية',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            onPressed: _submitData,
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// شاشة التحويل بين الحسابات
// -------------------------------------------------------------
class BankTransferScreen extends StatefulWidget {
  const BankTransferScreen({super.key});

  @override
  State<BankTransferScreen> createState() => _BankTransferScreenState();
}

class _BankTransferScreenState extends State<BankTransferScreen> {
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  String _fromAccount = 'مصرف الراجحي';
  String _toAccount = 'البنك الأهلي';

  final List<String> _accounts = ['مصرف الراجحي', 'البنك الأهلي', 'الإنماء', 'الخزينة النقدية'];

  void _submitTransfer() {
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تحديد المبلغ')),
      );
      return;
    }

    if (_fromAccount == _toAccount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن التحويل لنفس الحساب')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.teal,
        content: Text('تم تحويل ${_amountController.text} ر.س من $_fromAccount إلى $_toAccount'),
      ),
    );

    _amountController.clear();
    _notesController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            value: _fromAccount,
            decoration: const InputDecoration(labelText: 'من حساب', filled: true, fillColor: Color(0xFF14243B)),
            items: _accounts.map((acc) => DropdownMenuItem(value: acc, child: Text(acc))).toList(),
            onChanged: (val) => setState(() => _fromAccount = val!),
          ),
          const SizedBox(height: 12),
          const Center(child: Icon(Icons.arrow_downward, color: Color(0xFF00ADB5))),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _toAccount,
            decoration: const InputDecoration(labelText: 'إلى حساب', filled: true, fillColor: Color(0xFF14243B)),
            items: _accounts.map((acc) => DropdownMenuItem(value: acc, child: Text(acc))).toList(),
            onChanged: (val) => setState(() => _toAccount = val!),
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
            decoration: const InputDecoration(labelText: 'البيان / ملاحظات التحويل', filled: true, fillColor: Color(0xFF14243B)),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F3057),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.check, color: Colors.white),
            label: const Text('تأكيد التحويل البنكي', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            onPressed: _submitTransfer,
          ),
        ],
      ),
    );
  }
}
