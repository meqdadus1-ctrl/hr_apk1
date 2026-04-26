import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';

// ─────────────────────────────────────────
//  Model
// ─────────────────────────────────────────
class AttendanceDay {
  final String date;
  final String dayName;
  final String? checkIn;
  final String? checkOut;
  final double hoursWorked;
  final String status; // present | late | absent | holiday | off
  final int lateMinutes;

  const AttendanceDay({
    required this.date,
    required this.dayName,
    this.checkIn,
    this.checkOut,
    required this.hoursWorked,
    required this.status,
    required this.lateMinutes,
  });

  factory AttendanceDay.fromJson(Map<String, dynamic> j) => AttendanceDay(
        date:         j['date'] ?? '',
        dayName:      j['day_name'] ?? '',
        checkIn:      j['check_in'],
        checkOut:     j['check_out'],
        hoursWorked:  (j['hours_worked'] ?? 0).toDouble(),
        status:       j['status'] ?? 'absent',
        lateMinutes:  j['late_minutes'] ?? 0,
      );
}

// ─────────────────────────────────────────
//  Screen
// ─────────────────────────────────────────
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  List<AttendanceDay> _days = [];
  Map<String, dynamic> _summary = {};
  bool _isLoading = true;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    // تحديث تلقائي كل 30 ثانية
    _poll = Timer.periodic(const Duration(seconds: 30), (_) => _loadSilent());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _isLoading = true);
    await _fetch();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadSilent() async {
    await _fetch();
  }

  Future<void> _fetch() async {
    try {
      final res = await ApiService.get('/attendance');
      if (!mounted) return;
      if (res['success'] == true) {
        setState(() {
          _days = (res['data'] as List)
              .map((d) => AttendanceDay.fromJson(d))
              .toList();
          _summary = res['summary'] ?? {};
        });
      }
    } catch (_) {}
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'present': return Colors.green;
      case 'late':    return Colors.orange;
      case 'absent':  return Colors.red;
      case 'holiday': return Colors.purple;
      case 'off':     return Colors.grey;
      default:        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'present': return 'حاضر';
      case 'late':    return 'متأخر';
      case 'absent':  return 'غائب';
      case 'holiday': return 'إجازة';
      case 'off':     return 'يوم راحة';
      default:        return status;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'present': return Icons.check_circle_rounded;
      case 'late':    return Icons.watch_later_rounded;
      case 'absent':  return Icons.cancel_rounded;
      case 'holiday': return Icons.beach_access_rounded;
      case 'off':     return Icons.weekend_rounded;
      default:        return Icons.help_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_days.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fingerprint, size: 72, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('لا توجد بيانات حضور بعد',
                style: GoogleFonts.cairo(color: Colors.grey, fontSize: 15)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryCard(),
            const SizedBox(height: 20),
            Row(
              children: [
                Text('سجل هذا الأسبوع',
                    style: GoogleFonts.cairo(
                        fontSize: 17, fontWeight: FontWeight.bold)),
                const Spacer(),
                Icon(Icons.sync_rounded, size: 14, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text('يتحدث تلقائياً',
                    style: GoogleFonts.cairo(
                        fontSize: 11, color: Colors.grey[400])),
              ],
            ),
            const SizedBox(height: 10),
            ...(_days.map((day) => _buildDayCard(day))),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final present = _summary['present_days'] ?? 0;
    final absent  = _summary['absent_days']  ?? 0;
    final late    = _summary['late_days']    ?? 0;
    final hours   = (_summary['total_hours'] ?? 0.0).toDouble();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1e3a5f), Color(0xFF2d5a8e)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month_rounded,
                  color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              Text('ملخص هذا الأسبوع',
                  style: GoogleFonts.cairo(
                      color: Colors.white70, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _summaryItem('$present', 'حاضر', Colors.greenAccent),
              _vDivider(),
              _summaryItem('$absent', 'غائب', Colors.redAccent),
              _vDivider(),
              _summaryItem('$late', 'متأخر', Colors.orangeAccent),
              _vDivider(),
              _summaryItem(
                  '${hours.toStringAsFixed(1)}h', 'ساعات', Colors.blueAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String value, String label, Color color) => Column(
        children: [
          Text(value,
              style: GoogleFonts.cairo(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label,
              style: GoogleFonts.cairo(color: Colors.white60, fontSize: 12)),
        ],
      );

  Widget _vDivider() => Container(
      width: 1, height: 36, color: Colors.white.withOpacity(0.15));

  Widget _buildDayCard(AttendanceDay day) {
    final color = _statusColor(day.status);
    final isWorkday = day.status != 'holiday' && day.status != 'off';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border(
          right: BorderSide(color: color, width: 4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(day.dayName,
                        style: GoogleFonts.cairo(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(day.date,
                        style: GoogleFonts.cairo(
                            color: Colors.grey, fontSize: 12)),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon(day.status), color: color, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        _statusLabel(day.status),
                        style: GoogleFonts.cairo(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isWorkday) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  _timeChip(
                    icon: Icons.login_rounded,
                    label: 'دخول',
                    time: day.checkIn ?? '--:--',
                    color: day.checkIn != null
                        ? Colors.green
                        : Colors.grey[300]!,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: _hoursBar(day)),
                  const SizedBox(width: 8),
                  _timeChip(
                    icon: Icons.logout_rounded,
                    label: 'خروج',
                    time: day.checkOut ?? '--:--',
                    color: day.checkOut != null
                        ? Colors.red[400]!
                        : Colors.grey[300]!,
                  ),
                ],
              ),
              if (day.lateMinutes > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer_off_rounded,
                          size: 14, color: Colors.orange[700]),
                      const SizedBox(width: 4),
                      Text('تأخير ${day.lateMinutes} دقيقة',
                          style: GoogleFonts.cairo(
                              fontSize: 12, color: Colors.orange[700])),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _timeChip({
    required IconData icon,
    required String label,
    required String time,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 2),
        Text(time,
            style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold, fontSize: 13)),
        Text(label,
            style: GoogleFonts.cairo(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _hoursBar(AttendanceDay day) {
    const fullDay = 9.0;
    final progress = (day.hoursWorked / fullDay).clamp(0.0, 1.0);

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation(
              day.status == 'late' ? Colors.orange : Colors.green,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text('${day.hoursWorked.toStringAsFixed(1)} ساعة',
            style: GoogleFonts.cairo(
                fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }
}
