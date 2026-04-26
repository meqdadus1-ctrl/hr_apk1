import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

class SalaryScreen extends StatefulWidget {
  const SalaryScreen({super.key});

  @override
  State<SalaryScreen> createState() => _SalaryScreenState();
}

class _SalaryScreenState extends State<SalaryScreen> {
  List<dynamic> _salaries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiService.get('/salary');
      if (res['success'] == true) {
        if (mounted) setState(() => _salaries = res['data']);
      }
    } catch (e) {
      // handle error
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_salaries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.payments_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('لا توجد رواتب بعد',
                style: GoogleFonts.cairo(color: Colors.grey)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _salaries.length,
        itemBuilder: (context, i) {
          final s = _salaries[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.payments, color: Colors.blue),
              ),
              title: Text(
                s['fiscal_period'] ?? '',
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${s['week_start']} — ${s['week_end']}',
                style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${s['net_salary']} ₪',
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'صافي الراتب',
                    style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SalaryDetailScreen(salary: s),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class SalaryDetailScreen extends StatefulWidget {
  final Map<String, dynamic> salary;
  const SalaryDetailScreen({super.key, required this.salary});

  @override
  State<SalaryDetailScreen> createState() => _SalaryDetailScreenState();
}

class _SalaryDetailScreenState extends State<SalaryDetailScreen> {
  Map<String, dynamic>? _details;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiService.get('/salary/${widget.salary['id']}');
      if (res['success'] == true) {
        setState(() => _details = res['data']);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.cairo(color: Colors.grey[700])),
          Text(
            value,
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.bold,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey[300])),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              title,
              style: GoogleFonts.cairo(
                color: Colors.grey,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey[300])),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.salary['fiscal_period'] ?? 'تفاصيل الراتب',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Net Salary Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1e3a5f), Color(0xFF2d5a8e)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Text('صافي الراتب',
                            style: GoogleFonts.cairo(
                                color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: 8),
                        Text(
                          '${_details?['net_salary']} ₪',
                          style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_details?['week_start']} — ${_details?['week_end']}',
                          style: GoogleFonts.cairo(
                              color: Colors.white60, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Details Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildDivider('المستحقات'),
                          _buildRow('ساعات العمل',
                              '${_details?['details']?['hours_worked']} ساعة'),
                          _buildRow('أجر الساعة',
                              '${_details?['details']?['hourly_rate']} ₪'),
                          _buildRow('راتب الساعات',
                              '${_details?['details']?['salary_from_hours']} ₪',
                              color: Colors.green),
                          if ((_details?['details']?['overtime_hours'] ?? 0) > 0)
                            _buildRow('أوفرتايم',
                                '${_details?['details']?['salary_from_overtime']} ₪',
                                color: Colors.green),
                          if ((_details?['details']?['manual_additions'] ?? 0) > 0)
                            _buildRow('إضافات يدوية',
                                '${_details?['details']?['manual_additions']} ₪',
                                color: Colors.green),

                          _buildDivider('الخصومات'),
                          if ((_details?['details']?['late_deduction'] ?? 0) > 0)
                            _buildRow(
                                'خصم التأخير (${_details?['details']?['late_minutes']} دقيقة)',
                                '- ${_details?['details']?['late_deduction']} ₪',
                                color: Colors.red),
                          if ((_details?['details']?['absence_deduction'] ?? 0) > 0)
                            _buildRow('خصم الغياب',
                                '- ${_details?['details']?['absence_deduction']} ₪',
                                color: Colors.red),
                          if ((_details?['details']?['loan_deduction'] ?? 0) > 0)
                            _buildRow('قسط السلفة',
                                '- ${_details?['details']?['loan_deduction']} ₪',
                                color: Colors.red),
                          if ((_details?['details']?['manual_deductions'] ?? 0) > 0)
                            _buildRow('خصومات يدوية',
                                '- ${_details?['details']?['manual_deductions']} ₪',
                                color: Colors.red),

                          _buildDivider('الرصيد'),
                          _buildRow('الرصيد قبل',
                              '${_details?['details']?['balance_before']} ₪'),
                          _buildRow('الرصيد بعد',
                              '${_details?['details']?['balance_after']} ₪',
                              color: Colors.blue),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}