import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../salary/salary_screen.dart';
import '../loans/loans_screen.dart';
import '../leaves/leaves_screen.dart';
import '../profile/profile_screen.dart';
import '../notifications/notifications_screen.dart';
import '../chat/chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const _DashboardTab(),
    const SalaryScreen(),
    const LoansScreen(),
    const LeavesScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentIndex == 0 ? 'الرئيسية' :
          _currentIndex == 1 ? 'الرواتب' :
          _currentIndex == 2 ? 'السلف' :
          _currentIndex == 3 ? 'الإجازات' : 'الملف الشخصي',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        actions: [
          // زر المحادثة
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'محادثة الإدارة',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChatScreen()),
            ),
          ),
          // زر الإشعارات
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'الرئيسية'),
          NavigationDestination(
              icon: Icon(Icons.payments_outlined),
              selectedIcon: Icon(Icons.payments),
              label: 'الرواتب'),
          NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'السلف'),
          NavigationDestination(
              icon: Icon(Icons.beach_access_outlined),
              selectedIcon: Icon(Icons.beach_access),
              label: 'الإجازات'),
          NavigationDestination(
              icon: Icon(Icons.person_outlined),
              selectedIcon: Icon(Icons.person),
              label: 'حسابي'),
        ],
      ),
    );
  }
}

// =====================================================
//  Dashboard Tab — بيانات حقيقية من الـ API
// =====================================================
class _DashboardTab extends StatefulWidget {
  const _DashboardTab();

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  Map<String, dynamic>? _employee;
  Map<String, dynamic>? _lastSalary;
  Map<String, dynamic>? _activeLoan;
  int _unreadNotifications = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // تحميل البيانات بالتوازي
      final results = await Future.wait([
        ApiService.get('/profile'),
        ApiService.get('/salary'),
        ApiService.get('/loans'),
        ApiService.get('/notifications'),
      ]);

      if (!mounted) return;

      final profileRes  = results[0];
      final salaryRes   = results[1];
      final loanRes     = results[2];
      final notifRes    = results[3];

      setState(() {
        if (profileRes['success'] == true) {
          _employee = profileRes['employee'];
        }
        if (salaryRes['success'] == true &&
            (salaryRes['data'] as List).isNotEmpty) {
          _lastSalary = salaryRes['data'][0];
        }
        if (loanRes['success'] == true) {
          final loans = loanRes['data'] as List;
          try {
            _activeLoan = loans.firstWhere(
              (l) => l['status'] == 'active',
            );
          } catch (_) {}
        }
        if (notifRes['success'] == true) {
          _unreadNotifications = (notifRes['data'] as List)
              .where((n) => n['is_read'] == false)
              .length;
        }
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── بطاقة الترحيب
            _buildWelcomeCard(),
            const SizedBox(height: 16),

            // ── بطاقات الملخص
            _buildSummaryRow(),
            const SizedBox(height: 24),

            // ── الخدمات السريعة
            Text('الخدمات السريعة',
                style: GoogleFonts.cairo(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildQuickActions(),
            const SizedBox(height: 24),

            // ── آخر راتب
            if (_lastSalary != null) ...[
              Text('آخر راتب',
                  style: GoogleFonts.cairo(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildLastSalaryCard(),
              const SizedBox(height: 16),
            ],

            // ── السلفة النشطة
            if (_activeLoan != null) ...[
              Text('السلفة الحالية',
                  style: GoogleFonts.cairo(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildActiveLoanCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1e3a5f), Color(0xFF2d5a8e)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white24,
            backgroundImage: _employee?['photo_url'] != null
                ? NetworkImage(_employee!['photo_url'])
                : null,
            child: _employee?['photo_url'] == null
                ? const Icon(Icons.person, color: Colors.white, size: 30)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('مرحباً،',
                    style: GoogleFonts.cairo(
                        color: Colors.white70, fontSize: 13)),
                Text(
                  _employee?['name'] ?? '',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_employee?['job_title'] != null)
                  Text(
                    _employee!['job_title'],
                    style: GoogleFonts.cairo(
                        color: Colors.white60, fontSize: 12),
                  ),
              ],
            ),
          ),
          // زر التنبيهات
          if (_unreadNotifications > 0)
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications,
                      color: Colors.white, size: 28),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const NotificationsScreen()),
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$_unreadNotifications',
                      style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow() {
    final balance = _employee?['balance'] ?? 0;
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            title: 'الرصيد',
            value: '$balance ₪',
            icon: Icons.account_balance_wallet,
            color: balance >= 0 ? Colors.green : Colors.red,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            title: 'آخر راتب',
            value: _lastSalary != null
                ? '${_lastSalary!['net_salary']} ₪'
                : '—',
            icon: Icons.payments,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            title: 'سلفة',
            value: _activeLoan != null
                ? '${_activeLoan!['remaining_amount']} ₪'
                : 'لا يوجد',
            icon: Icons.credit_card,
            color: Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: [
        _QuickActionCard(
          icon: Icons.payments,
          title: 'الرواتب',
          color: Colors.blue,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SalaryScreen())),
        ),
        _QuickActionCard(
          icon: Icons.account_balance_wallet,
          title: 'السلف',
          color: Colors.orange,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const LoansScreen())),
        ),
        _QuickActionCard(
          icon: Icons.beach_access,
          title: 'الإجازات',
          color: Colors.green,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const LeavesScreen())),
        ),
        _QuickActionCard(
          icon: Icons.chat_bubble,
          title: 'تواصل مع الإدارة',
          color: const Color(0xFF1e3a5f),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ChatScreen())),
        ),
      ],
    );
  }

  Widget _buildLastSalaryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('الفترة',
                    style: GoogleFonts.cairo(color: Colors.grey, fontSize: 13)),
                Text(_lastSalary!['fiscal_period'] ?? '',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('صافي الراتب',
                    style: GoogleFonts.cairo(color: Colors.grey, fontSize: 13)),
                Text(
                  '${_lastSalary!['net_salary']} ₪',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveLoanCard() {
    final progress = (_activeLoan!['progress_percent'] ?? 0) / 100;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('المبلغ الكلي',
                    style: GoogleFonts.cairo(color: Colors.grey, fontSize: 13)),
                Text('${_activeLoan!['total_amount']} ₪',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress.toDouble(),
              backgroundColor: Colors.grey[200],
              color: Colors.orange,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('المدفوع: ${_activeLoan!['amount_paid']} ₪',
                    style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey)),
                Text('المتبقي: ${_activeLoan!['remaining_amount']} ₪',
                    style: GoogleFonts.cairo(fontSize: 12, color: Colors.orange)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── بطاقة ملخص صغيرة
class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(title,
              style: GoogleFonts.cairo(
                  color: Colors.grey, fontSize: 10)),
          const SizedBox(height: 2),
          Text(value,
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── زر الخدمة السريعة
class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold, color: color, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
