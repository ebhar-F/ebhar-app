import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:local_auth/local_auth.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

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
      home: const SecureLoginScreen(),
    );
  }
}

// -------------------------------------------------------------
// شاشة تسجيل الدخول والتحقق من حساب المستخدم من الشيت
// -------------------------------------------------------------
class SecureLoginScreen extends StatefulWidget {
  const SecureLoginScreen({super.key});

  @override
  State<SecureLoginScreen> createState() => _SecureLoginScreenState();
}

class _SecureLoginScreenState extends State<SecureLoginScreen> {
  final LocalAuthentication _auth = LocalAuthentication();
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String _errorMsg = '';
  static String? _cachedUsername;
  static String? _cachedPassword;

  Future<void> _handleLogin() async {
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
        _cachedUsername = username;
        _cachedPassword = password;
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
      setState(() => _errorMsg = 'تعذر الاتصال بالنظام: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleBiometricLogin() async {
    if (_cachedUsername == null || _cachedPassword == null) {
      setState(() => _errorMsg = 'يجب تسجيل الدخول بكلمة المرور لأول مرة');
      return;
    }

    try {
      final didAuth = await _auth.authenticate(
        localizedReason: 'المس مستشعر البصمة للمتابعة لحساب $_cachedUsername',
        options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
      );

      if (didAuth && mounted) {
        _userController.text = _cachedUsername!;
        _passwordController.text = _cachedPassword!;
        _handleLogin();
      }
    } catch (_) {
      setState(() => _errorMsg = 'تعذر التحقق من البصمة');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 26),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF0F4C81).withOpacity(0.08),
                  ),
                  child: const Icon(Icons.sailing, size: 70, color: Color(0xFF0F4C81)),
                ),
                const SizedBox(height: 14),
                const Text(
                  'إبحار',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF0F4C81)),
                ),
                const SizedBox(height: 4),
                const Text(
                  'منظومة الإدارة والمحاسبة الذكية',
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 28),

                if (_cachedUsername != null) ...[
                  InkWell(
                    onTap: _handleBiometricLogin,
                    borderRadius: BorderRadius.circular(50),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF0F4C81), width: 2),
                        color: const Color(0xFF0F4C81).withOpacity(0.06),
                      ),
                      child: const Icon(Icons.fingerprint, size: 55, color: Color(0xFF0F4C81)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('دخول سريع للمستخدم: $_cachedUsername', style: const TextStyle(fontSize: 12, color: Color(0xFF0F4C81), fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                ],

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
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F4C81),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _isLoading ? null : _handleLogin,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('تسجيل الدخول والتحقق', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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
// الشاشة الرئيسية المشتركة
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

  List<Map<String, String>> _accountsList = [];
  List<Map<String, dynamic>> _cardsList = [];
  List<Map<String, String>> _categoriesList = [];
  List<Map<String, String>> _tempMapsList = [];
  List<Map<String, dynamic>> _tempSubCategoriesList = [];

  @override
  void initState() {
    super.initState();
    _fetchSystemData();
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
    try {
      final res = await http.get(Uri.parse('$kBackendUrl?action=getInitialData'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['ok'] == true && data['data'] != null) {
          final rawAccounts = (data['data']['accounts'] as List?) ?? [];
          final rawCards = (data['data']['cards'] as List?) ?? [];
          final rawCategories = (data['data']['categories'] as List?) ?? [];
          final rawTempMaps = (data['data']['tempMaps'] as List?) ?? [];
          final rawTempSub = (data['data']['tempSubCategories'] as List?) ?? [];

          final parsedAccounts = <Map<String, String>>[];
          for (int i = 0; i < rawAccounts.length; i++) {
            final name = _extractName(rawAccounts[i]);
            if (name.isNotEmpty) {
              parsedAccounts.add({'id': _extractId(rawAccounts[i], i), 'name': name});
            }
          }

          final parsedCards = <Map<String, dynamic>>[];
          for (int i = 0; i < rawCards.length; i++) {
            final name = _extractName(rawCards[i]);
            final last4 = (rawCards[i]['last4'] ?? '').toString();
            final displayName = last4.isNotEmpty ? '$name (...$last4)' : name;
            final accId = (rawCards[i]['account_id'] ?? '').toString();
            if (name.isNotEmpty) {
              parsedCards.add({'id': _extractId(rawCards[i], i), 'name': displayName, 'account_id': accId});
            }
          }

          final parsedCategories = <Map<String, String>>[];
          for (int i = 0; i < rawCategories.length; i++) {
            final name = _extractName(rawCategories[i]);
            if (name.isNotEmpty) {
              parsedCategories.add({'id': _extractId(rawCategories[i], i), 'name': name});
            }
          }

          final parsedTempMaps = <Map<String, String>>[];
          for (int i = 0; i < rawTempMaps.length; i++) {
            final name = _extractName(rawTempMaps[i]);
            if (name.isNotEmpty) {
              parsedTempMaps.add({'id': _extractId(rawTempMaps[i], i), 'name': name});
            }
          }

          final parsedTempSub = <Map<String, dynamic>>[];
          for (int i = 0; i < rawTempSub.length; i++) {
            final name = _extractName(rawTempSub[i]);
            final mapId = (rawTempSub[i]['map_id'] ?? rawTempSub[i]['temp_map_id'] ?? '').toString();
            if (name.isNotEmpty) {
              parsedTempSub.add({'id': _extractId(rawTempSub[i], i), 'name': name, 'map_id': mapId});
            }
          }

          setState(() {
            _accountsList = parsedAccounts;
            _cardsList = parsedCards;
            _categoriesList = parsedCategories;
            _tempMapsList = parsedTempMaps;
            _tempSubCategoriesList = parsedTempSub;
            _isLoading = false;
          });
          return;
        }
      }
    } catch (_) {}

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final userName = widget.currentUser['display_name'] ?? widget.currentUser['username'] ?? 'المستخدم';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(_currentIndex == 0 ? 'تسجيل حركة مالية جديدة' : 'تحويل بين الحسابات', style: const TextStyle(fontSize: 17)),
            Text('المستخدم: $userName', style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث البيانات من الشيت',
            onPressed: _fetchSystemData,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'تسجيل خروج',
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const SecureLoginScreen()),
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
                  Text('جاري تحديث البيانات من شيت إبحار...', style: TextStyle(color: Colors.black54)),
                ],
              ),
            )
          : IndexedStack(
              index: _currentIndex,
              children: [
                TransactionEntryScreen(
                  currentUser: userName,
                  accounts: _accountsList,
                  cards: _cardsList,
                  categories: _categoriesList,
                  tempMaps: _tempMapsList,
                  tempSubCategories: _tempSubCategoriesList,
                  onSuccess: _fetchSystemData,
                ),
                BankTransferScreen(
                  currentUser: userName,
                  accounts: _accountsList,
                  onSuccess: _fetchSystemData,
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
// شاشة تسجيل حركة مالية (حفظ عبر GET لتفادي 302 ومساحات منفصلة)
// -------------------------------------------------------------
class TransactionEntryScreen extends StatefulWidget {
  final String currentUser;
  final List<Map<String, String>> accounts;
  final List<Map<String, dynamic>> cards;
  final List<Map<String, String>> categories;
  final List<Map<String, String>> tempMaps;
  final List<Map<String, dynamic>> tempSubCategories;
  final VoidCallback onSuccess;

  const TransactionEntryScreen({
    super.key,
    required this.currentUser,
    required this.accounts,
    required this.cards,
    required this.categories,
    required this.tempMaps,
    required this.tempSubCategories,
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

  Future<void> _submitData() async {
    final amt = double.tryParse(_amountController.text);
    if (amt == null || amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تحديد المبلغ أولاً')),
      );
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
      "user": widget.currentUser
    };

    try {
      final uri = Uri.parse(kBackendUrl).replace(queryParameters: {
        'action': 'saveTransaction',
        'payload': json.encode(payload),
      });

      final res = await http.get(uri);
      final data = json.decode(res.body);

      if (data['ok'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: Colors.teal, content: Text('تم تسجيل الحركة وتحديث الأرصدة بنجاح!')),
        );
        _amountController.clear();
        _notesController.clear();
        widget.onSuccess();
      } else {
        throw Exception(data['error'] ?? 'تعذر الحفظ في قاعدة البيانات');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.redAccent, content: Text('خطأ أثناء الحفظ: $e')),
      );
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

          // جهة الصرف / الخريطة المؤقتة
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

          // البند التابع
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

          // الحساب البنكي بسطر مستقل
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

          // البطاقة المستخدمة بسطر مستقل
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
// شاشة التحويل بين الحسابات
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تحديد مبلغ التحويل')),
      );
      return;
    }

    if (_fromAccountId == null || _toAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار الحساب المحول منه وإليه')),
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
      final uri = Uri.parse(kBackendUrl).replace(queryParameters: {
        'action': 'transfer',
        'fromAccId': _fromAccountId,
        'toAccId': _toAccountId,
        'amount': amt.toString(),
        'notes': _notesController.text.trim(),
        'user': widget.currentUser,
      });

      final res = await http.get(uri);
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
