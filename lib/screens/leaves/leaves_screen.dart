import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';

class LeavesScreen extends StatefulWidget {
  const LeavesScreen({super.key});

  @override
  State<LeavesScreen> createState() => _LeavesScreenState();
}

class _LeavesScreenState extends State<LeavesScreen> {
  List<dynamic> _leaves = [];
  List<dynamic> _leaveTypes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiService.get('/leaves');
      if (res['success'] == true) {
        setState(() {
          _leaves = res['data'];
          _leaveTypes = res['leave_types'] ?? [];
        });
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved': return Colors.green;
      case 'pending': return Colors.orange;
      case 'rejected': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'approved': return 'موافق عليها';
      case 'pending': return 'قيد المراجعة';
      case 'rejected': return 'مرفوضة';
      default: return status;
    }
  }

  void _showRequestDialog() {
    int? selectedTypeId;
    DateTime? startDate;
    DateTime? endDate;
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16, right: 16, top: 24,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('طلب إجازة جديدة',
                    style: GoogleFonts.cairo(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                // نوع الإجازة
                DropdownButtonFormField<int>(
                  value: selectedTypeId,
                  decoration: InputDecoration(
                    labelText: 'نوع الإجازة',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _leaveTypes.map<DropdownMenuItem<int>>((t) {
                    return DropdownMenuItem<int>(
                      value: t['id'],
                      child: Text(t['name'], style: GoogleFonts.cairo()),
                    );
                  }).toList(),
                  onChanged: (v) => setModalState(() => selectedTypeId = v),
                  validator: (v) => v == null ? 'اختر نوع الإجازة' : null,
                ),
                const SizedBox(height: 12),

                // تاريخ البداية
                InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null) setModalState(() => startDate = d);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          startDate == null
                              ? 'تاريخ البداية'
                              : '${startDate!.year}-${startDate!.month.toString().padLeft(2, '0')}-${startDate!.day.toString().padLeft(2, '0')}',
                          style: GoogleFonts.cairo(
                              color: startDate == null
                                  ? Colors.grey
                                  : Colors.black),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // تاريخ النهاية
                InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: startDate ?? DateTime.now(),
                      firstDate: startDate ?? DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null) setModalState(() => endDate = d);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          endDate == null
                              ? 'تاريخ النهاية'
                              : '${endDate!.year}-${endDate!.month.toString().padLeft(2, '0')}-${endDate!.day.toString().padLeft(2, '0')}',
                          style: GoogleFonts.cairo(
                              color: endDate == null
                                  ? Colors.grey
                                  : Colors.black),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: reasonController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'سبب الإجازة (اختياري)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      if (startDate == null || endDate == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('اختر تاريخ البداية والنهاية',
                                style: GoogleFonts.cairo()),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      Navigator.pop(ctx);
                      try {
                        final res = await ApiService.post('/leaves', {
                          'leave_type_id': selectedTypeId,
                          'start_date':
                              '${startDate!.year}-${startDate!.month.toString().padLeft(2, '0')}-${startDate!.day.toString().padLeft(2, '0')}',
                          'end_date':
                              '${endDate!.year}-${endDate!.month.toString().padLeft(2, '0')}-${endDate!.day.toString().padLeft(2, '0')}',
                          'reason': reasonController.text,
                        });
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(res['message'] ?? '',
                              style: GoogleFonts.cairo()),
                          backgroundColor: res['success'] == true
                              ? Colors.green
                              : Colors.red,
                        ));
                        if (res['success'] == true) _load();
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content:
                              Text('حدث خطأ', style: GoogleFonts.cairo()),
                          backgroundColor: Colors.red,
                        ));
                      }
                    },
                    child: Text('إرسال الطلب', style: GoogleFonts.cairo()),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showRequestDialog,
        icon: const Icon(Icons.add),
        label: Text('طلب إجازة', style: GoogleFonts.cairo()),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _leaves.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.beach_access_outlined,
                          size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text('لا توجد إجازات',
                          style: GoogleFonts.cairo(color: Colors.grey)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _leaves.length,
                    itemBuilder: (context, i) {
                      final l = _leaves[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    l['leave_type'] ?? 'إجازة',
                                    style: GoogleFonts.cairo(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _statusColor(l['status'])
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      _statusLabel(l['status']),
                                      style: GoogleFonts.cairo(
                                        color: _statusColor(l['status']),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today,
                                      size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${l['start_date']} — ${l['end_date']}',
                                    style: GoogleFonts.cairo(
                                        fontSize: 13, color: Colors.grey),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${l['total_days']} يوم',
                                    style: GoogleFonts.cairo(
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF1e3a5f)),
                                  ),
                                ],
                              ),
                              if (l['rejection_reason'] != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.red[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.info_outline,
                                          color: Colors.red, size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          l['rejection_reason'],
                                          style: GoogleFonts.cairo(
                                              color: Colors.red, fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}