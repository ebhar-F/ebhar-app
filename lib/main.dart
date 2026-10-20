import 'package:flutter/material.dart';
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
        scaffoldBackgroundColor: const Color(0xFF0F1E2E),
        primaryColor: const Color(0xFF00ADB5),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00ADB5),
          secondary: Color(0xFF393E46),
          surface: Color(0xFF1B2A47),
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
// 1. شاشة الدخول مع خيار البصمة وحقول كلمة المرور
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

  @override
  void initState() {
    super.initState();
    // تفعيل فحص البصمة السريع فور فتح الشاشة
    Future.delayed(const Duration(milliseconds: 600), () {
      _authenticateWithBiometrics();
    });
  }

  Future<void> _authenticateWithBiometrics() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();

      if (!canAuthenticate) return;

      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'المس مستشعر البصمة للدخول السريع لتطبيق إبحار',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (didAuthenticate && mounted) {
        _navigateToDashboard();
      }
    } catch (_) {
      // في حال الإلغاء أو عدم التعرف
    }
  }

  void _navigateToDashboard() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const MainDashboard()),
    );
  }

  void _manualLogin() {
    if (_userController.text.isNotEmpty && _passwordController.text.isNotEmpty) {
      _navigateToDashboard();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى كتابة اسم المستخدم وكلمة المرور')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.08),
                  ),
                  child: const Icon(Icons.sailing, size: 70, color: Color(0xFF00ADB5)),
                ),
                const SizedBox(height: 18),
                const Text(
                  'إبحار',
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 6),
                const Text(
                  'منظومة الإدارة والمحاسبة الذكية',
                  style: TextStyle(fontSize: 15, color: Colors.white70),
                ),
                const SizedBox(height: 36),

                // زر البصمة للدخول السريع
                InkWell(
                  onTap: _authenticateWithBiometrics,
                  borderRadius: BorderRadius.circular(50),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF00ADB5), width: 2),
                      color: const Color(0xFF00ADB5).withOpacity(0.12),
                    ),
                    child: const Icon(Icons.fingerprint, size: 68, color: Color(0xFF00ADB5)),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'المس مستشعر البصمة للمتابعة الفورية',
                  style: TextStyle(fontSize: 14, color: Colors.white60),
                ),
                const SizedBox(height: 24),

                // زر إظهار حقول تسجيل الدخول التقليدية
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
                    _showPasswordFields ? 'إخفاء تسجيل الدخول اليدوي' : 'الدخول باسم المستخدم وكلمة المرور',
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
                      fillColor: const Color(0xFF1B2A47),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                      fillColor: const Color(0xFF1B2A47),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        activeColor: const Color(0xFF00ADB5),
                        onChanged: (val) {
                          setState(() {
                            _rememberMe = val ?? true;
                          });
                        },
                      ),
                      const Text('تذكر بيانات الدخول', style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00ADB5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _manualLogin,
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
// 2. الواجهة الرئيسية (التنقل بين تسجيل حركة والتحويل البنكي)
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
        title: Text(_currentIndex == 0 ? 'تسجيل حركة مالية' : 'تحويل بين الحسابات'),
        centerTitle: true,
        backgroundColor: const Color(0xFF1B2A47),
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
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: const Color(0xFF1B2A47),
        selectedItemColor: const Color(0xFF00ADB5),
        unselectedItemColor: Colors.white54,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'تسجيل حركة',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.swap_horiz),
            label: 'تحويل بنكي',
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// 3. شاشة تسجيل حركة مالية (مصروف / إيراد)
// -------------------------------------------------------------
class TransactionEntryScreen extends StatefulWidget {
  const TransactionEntryScreen({super.key});

  @override
  State<TransactionEntryScreen> createState() => _TransactionEntryScreenState();
}

class _TransactionEntryScreenState extends State<TransactionEntryScreen> {
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  String _transactionType = 'مصروف';
  String _selectedAccount = 'مصرف الراجحي';
  String _selectedCategory = 'مشتريات وبضائع';
  DateTime _selectedDate = DateTime.now();

  final List<String> _accounts = ['مصرف الراجحي', 'البنك الأهلي', 'الخزينة النقدية'];
  final List<String> _categories = [
    'مشتريات وبضائع',
    'رواتب وعمالة',
    'فواتير وكهرباء',
    'إيجارات ومقر',
    'نثريات ومصروفات عامة',
    'مبيعات وإيرادات',
  ];

  void _submitTransaction() {
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تحديد المبلغ أولاً')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.teal,
        content: Text('تم حفظ ${_transactionType} بمبلغ ${_amountController.text} ر.س بنجاح'),
      ),
    );

    _amountController.clear();
    _notesController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'مصروف', label: Text('مصروف')),
              ButtonSegment(value: 'إيراد', label: Text('إيراد')),
            ],
            selected: {_transactionType},
            onSelectionChanged: (set) {
              setState(() {
                _transactionType = set.first;
              });
            },
          ),
          const SizedBox(height: 18),

          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'المبلغ (ر.س)',
              prefixIcon: const Icon(Icons.attach_money, color: Color(0xFF00ADB5)),
              filled: true,
              fillColor: const Color(0xFF1B2A47),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 14),

          DropdownButtonFormField<String>(
            value: _selectedAccount,
            decoration: InputDecoration(
              labelText: 'الحساب المالي',
              prefixIcon: const Icon(Icons.account_balance_wallet, color: Color(0xFF00ADB5)),
              filled: true,
              fillColor: const Color(0xFF1B2A47),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: _accounts.map((acc) => DropdownMenuItem(value: acc, child: Text(acc))).toList(),
            onChanged: (val) => setState(() => _selectedAccount = val!),
          ),
          const SizedBox(height: 14),

          DropdownButtonFormField<String>(
            value: _selectedCategory,
            decoration: InputDecoration(
              labelText: 'التصنيف / البند',
              prefixIcon: const Icon(Icons.category, color: Color(0xFF00ADB5)),
              filled: true,
              fillColor: const Color(0xFF1B2A47),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: _categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
            onChanged: (val) => setState(() => _selectedCategory = val!),
          ),
          const SizedBox(height: 14),

          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: const Color(0xFF1B2A47),
            leading: const Icon(Icons.calendar_today, color: Color(0xFF00ADB5)),
            title: Text('التاريخ: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}'),
            trailing: const Icon(Icons.edit, size: 20),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null) setState(() => _selectedDate = picked);
            },
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'البيان / ملاحظات إضافية',
              prefixIcon: const Icon(Icons.notes, color: Color(0xFF00ADB5)),
              filled: true,
              fillColor: const Color(0xFF1B2A47),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 22),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00ADB5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.save, color: Colors.white),
            label: const Text('حفظ الحركة المالية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            onPressed: _submitTransaction,
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// 4. شاشة التحويل بين الحسابات البنكية
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

  final List<String> _accounts = ['مصرف الراجحي', 'البنك الأهلي', 'الخزينة النقدية'];

  void _submitTransfer() {
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تحديد مبلغ التحويل')),
      );
      return;
    }

    if (_fromAccount == _toAccount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن التحويل لنفس الحساب المالي')),
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            value: _fromAccount,
            decoration: InputDecoration(
              labelText: 'من حساب',
              prefixIcon: const Icon(Icons.account_balance, color: Color(0xFF00ADB5)),
              filled: true,
              fillColor: const Color(0xFF1B2A47),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: _accounts.map((acc) => DropdownMenuItem(value: acc, child: Text(acc))).toList(),
            onChanged: (val) => setState(() => _fromAccount = val!),
          ),
          const SizedBox(height: 14),

          Center(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF1B2A47),
              ),
              child: const Icon(Icons.arrow_downward, color: Color(0xFF00ADB5)),
            ),
          ),
          const SizedBox(height: 14),

          DropdownButtonFormField<String>(
            value: _toAccount,
            decoration: InputDecoration(
              labelText: 'إلى حساب',
              prefixIcon: const Icon(Icons.account_balance, color: Color(0xFF00ADB5)),
              filled: true,
              fillColor: const Color(0xFF1B2A47),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: _accounts.map((acc) => DropdownMenuItem(value: acc, child: Text(acc))).toList(),
            onChanged: (val) => setState(() => _toAccount = val!),
          ),
          const SizedBox(height: 18),

          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'المبلغ المحوّل (ر.س)',
              prefixIcon: const Icon(Icons.attach_money, color: Color(0xFF00ADB5)),
              filled: true,
              fillColor: const Color(0xFF1B2A47),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'بيان التحويل / رقم الإيصال',
              prefixIcon: const Icon(Icons.description, color: Color(0xFF00ADB5)),
              filled: true,
              fillColor: const Color(0xFF1B2A47),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 22),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00ADB5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.check_circle_outline, color: Colors.white),
            label: const Text('تأكيد التحويل البنكي', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            onPressed: _submitTransfer,
          ),
        ],
      ),
    );
  }
}
