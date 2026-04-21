import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import 'bank_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiService.get('/profile');
      if (res['success'] == true) {
        setState(() => _profile = res['employee']);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF1e3a5f)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.cairo(
                        fontSize: 11, color: Colors.grey)),
                Text(value,
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تسجيل الخروج', style: GoogleFonts.cairo()),
        content: Text('هل أنت متأكد؟', style: GoogleFonts.cairo()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('خروج',
                style: GoogleFonts.cairo(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService.logout();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1e3a5f), Color(0xFF2d5a8e)],
                ),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 45,
                    backgroundColor: Colors.white24,
                    backgroundImage: _profile?['photo_url'] != null
                        ? NetworkImage(_profile!['photo_url'])
                        : null,
                    child: _profile?['photo_url'] == null
                        ? const Icon(Icons.person,
                            color: Colors.white, size: 45)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _profile?['name'] ?? '',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_profile?['job_title'] != null)
                    Text(
                      _profile!['job_title'],
                      style: GoogleFonts.cairo(color: Colors.white70),
                    ),
                  if (_profile?['department'] != null)
                    Text(
                      _profile!['department'],
                      style: GoogleFonts.cairo(color: Colors.white60),
                    ),
                ],
              ),
            ),

            // Balance Card
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('الرصيد الحالي',
                              style: GoogleFonts.cairo(
                                  color: Colors.grey, fontSize: 12)),
                          Text(
                            '${_profile?['balance'] ?? 0} ₪',
                            style: GoogleFonts.cairo(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1e3a5f),
                            ),
                          ),
                        ],
                      ),
                      Container(
                          width: 1, height: 40, color: Colors.grey[300]),
                      Column(
                        children: [
                          Text('تاريخ التعيين',
                              style: GoogleFonts.cairo(
                                  color: Colors.grey, fontSize: 12)),
                          Text(
                            _profile?['hire_date'] ?? '—',
                            style: GoogleFonts.cairo(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Info Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('المعلومات الشخصية',
                          style: GoogleFonts.cairo(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const Divider(),
                      _buildInfoRow(Icons.badge, 'الرقم الوطني',
                          _profile?['national_id'] ?? '—'),
                      _buildInfoRow(Icons.phone, 'الجوال',
                          _profile?['phone'] ?? '—'),
                      _buildInfoRow(Icons.email, 'البريد الإلكتروني',
                          _profile?['email'] ?? '—'),
                    ],
                  ),
                ),
              ),
            ),

            // Bank Card
            if (_profile?['bank'] != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('البيانات البنكية',
                            style: GoogleFonts.cairo(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const Divider(),
                        _buildInfoRow(Icons.account_balance, 'البنك',
                            _profile!['bank']['bank_name'] ?? '—'),
                        _buildInfoRow(Icons.person, 'اسم صاحب الحساب',
                            _profile!['bank']['account_name'] ?? '—'),
                        _buildInfoRow(Icons.credit_card, 'رقم الحساب',
                            _profile!['bank']['bank_account'] ?? '—'),
                      ],
                    ),
                  ),
                ),
              ),

              // في نهاية Bank Card بعد آخر _buildInfoRow
const Divider(),
SizedBox(
  width: double.infinity,
  child: TextButton.icon(
    onPressed: () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BankScreen(bankData: _profile!['bank']),
      ),
    ),
    icon: Icon(
      _profile!['bank']['is_locked'] == true
          ? Icons.lock
          : Icons.edit,
      color: _profile!['bank']['is_locked'] == true
          ? Colors.grey
          : const Color(0xFF1e3a5f),
    ),
    label: Text(
      _profile!['bank']['is_locked'] == true
          ? 'البنك مقفول'
          : 'تعديل بيانات البنك',
      style: GoogleFonts.cairo(
        color: _profile!['bank']['is_locked'] == true
            ? Colors.grey
            : const Color(0xFF1e3a5f),
      ),
    ),
  ),
),

            // Logout Button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: Text('تسجيل الخروج',
                      style: GoogleFonts.cairo(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
