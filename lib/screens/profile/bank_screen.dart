import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';


class BankScreen extends StatefulWidget {
  final Map<String, dynamic>? bankData;
  const BankScreen({super.key, this.bankData});

  @override
  State<BankScreen> createState() => _BankScreenState();
}

class _BankScreenState extends State<BankScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedBankType;
  final _accountNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  bool _isLoading = false;

  final List<Map<String, String>> _bankTypes = [
    {'value': 'bank_of_palestine', 'label': '🏦 بنك فلسطين'},
    {'value': 'pal_pay', 'label': '💳 Pal Pay'},
    {'value': 'jawwal_pay', 'label': '📱 جوال باي'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.bankData != null) {
      _selectedBankType    = widget.bankData!['bank_type'];
      _accountNameController.text   = widget.bankData!['account_name'] ?? '';
      _accountNumberController.text = widget.bankData!['bank_account'] ?? '';
    }
  }

  @override
  void dispose() {
    _accountNameController.dispose();
    _accountNumberController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBankType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('اختر نوع البنك', style: GoogleFonts.cairo()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final res = await ApiService.put('/profile/bank', {
        'bank_type': _selectedBankType,
        'account_name': _accountNameController.text.trim(),
        'bank_account': _accountNumberController.text.trim(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? '', style: GoogleFonts.cairo()),
          backgroundColor: res['success'] == true ? Colors.green : Colors.red,
        ),
      );
      if (res['success'] == true) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ', style: GoogleFonts.cairo()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLocked = widget.bankData?['is_locked'] == true;

    return Scaffold(
      appBar: AppBar(
        title: Text('بيانات البنك',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: isLocked
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    const Icon(Icons.lock, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      'بيانات البنك مقفولة',
                      style: GoogleFonts.cairo(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'تواصل مع الإدارة لتعديل بيانات حسابك البنكي',
                      style: GoogleFonts.cairo(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    // عرض البيانات الحالية
                    if (widget.bankData?['account_name'] != null)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _infoRow('اسم صاحب الحساب',
                                  widget.bankData!['account_name']),
                              const Divider(),
                              _infoRow('رقم الحساب',
                                  widget.bankData!['bank_account'] ?? '—'),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              )
            : Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // تنبيه
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'سيتم إرسال طلب التعديل للإدارة للمراجعة والاعتماد.',
                              style: GoogleFonts.cairo(
                                  fontSize: 13, color: Colors.blue[700]),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // نوع البنك
                    Text('نوع البنك',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedBankType,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        hintText: 'اختر البنك',
                      ),
                      items: _bankTypes
                          .map((b) => DropdownMenuItem(
                                value: b['value'],
                                child: Text(b['label']!,
                                    style: GoogleFonts.cairo()),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedBankType = v),
                    ),
                    const SizedBox(height: 16),

                    // اسم صاحب الحساب
                    Text('اسم صاحب الحساب',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _accountNameController,
                      decoration: InputDecoration(
                        hintText: 'الاسم كما هو في البطاقة',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) =>
                          v!.isEmpty ? 'أدخل اسم صاحب الحساب' : null,
                    ),
                    const SizedBox(height: 16),

                    // رقم الحساب
                    Text('رقم الحساب',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _accountNumberController,
                      textDirection: TextDirection.ltr,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'أدخل رقم الحساب',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) =>
                          v!.isEmpty ? 'أدخل رقم الحساب' : null,
                    ),
                    const SizedBox(height: 24),

                    // زر الإرسال
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : Text('إرسال طلب التعديل',
                                style: GoogleFonts.cairo(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.cairo(color: Colors.grey, fontSize: 13)),
          Text(value,
              style:
                  GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}