import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiService.get('/notifications');
      if (res['success'] == true) {
        setState(() => _notifications = res['data']);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAllRead() async {
    await ApiService.post('/notifications/read', {});
    _load();
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'loan_approved': return Icons.check_circle;
      case 'loan_rejected': return Icons.cancel;
      case 'leave_approved': return Icons.beach_access;
      case 'leave_rejected': return Icons.cancel;
      case 'bank_approved': return Icons.account_balance;
      case 'bank_rejected': return Icons.cancel;
      case 'statement_ready': return Icons.description;
      default: return Icons.notifications;
    }
  }

  Color _getColor(String type) {
    if (type.contains('approved') || type.contains('ready')) return Colors.green;
    if (type.contains('rejected')) return Colors.red;
    return Colors.blue;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('الإشعارات', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        actions: [
          if (_notifications.isNotEmpty)
            TextButton(
              onPressed: _markAllRead,
              child: Text('تحديد الكل كمقروء',
                  style: GoogleFonts.cairo(color: Colors.white, fontSize: 12)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.notifications_none,
                          size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text('لا توجد إشعارات',
                          style: GoogleFonts.cairo(color: Colors.grey)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    itemBuilder: (context, i) {
                      final n = _notifications[i];
                      final isRead = n['is_read'] == true;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        color: isRead ? Colors.white : Colors.blue[50],
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                _getColor(n['type']).withOpacity(0.1),
                            child: Icon(
                              _getIcon(n['type']),
                              color: _getColor(n['type']),
                              size: 20,
                            ),
                          ),
                          title: Text(
                            n['title'] ?? '',
                            style: GoogleFonts.cairo(
                              fontWeight: isRead
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(n['body'] ?? '',
                                  style: GoogleFonts.cairo(fontSize: 12)),
                              Text(
                                n['created_at'] ?? '',
                                style: GoogleFonts.cairo(
                                    fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}