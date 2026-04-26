import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';

// ─────────────────────────────────────────
//  Model
// ─────────────────────────────────────────
class ChatMessage {
  final int id;
  final String senderType;
  final String? message;
  final String? attachmentUrl;
  final String? attachmentType;
  final String? attachmentName;
  final bool isRead;
  final String createdAt;
  final String timeAgo;

  const ChatMessage({
    required this.id,
    required this.senderType,
    this.message,
    this.attachmentUrl,
    this.attachmentType,
    this.attachmentName,
    required this.isRead,
    required this.createdAt,
    required this.timeAgo,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id:             j['id'],
        senderType:     j['sender_type'] ?? 'employee',
        message:        j['message'],
        attachmentUrl:  j['attachment_url'],
        attachmentType: j['attachment_type'],
        attachmentName: j['attachment_name'],
        isRead:         j['is_read'] == true,
        createdAt:      j['created_at'] ?? '',
        timeAgo:        j['time_ago'] ?? j['ago'] ?? '',
      );

  bool get isMe       => senderType == 'employee';
  bool get hasImage   => attachmentType == 'image'    && attachmentUrl != null;
  bool get hasDoc     => attachmentType == 'document' && attachmentUrl != null;
}

// ─────────────────────────────────────────
//  Colors
// ─────────────────────────────────────────
const _kPrimary   = Color(0xFF1A3A5C);
const _kPrimaryLt = Color(0xFF2563A8);
const _kBg        = Color(0xFFF0F4F8);
const _kMyBubble  = Color(0xFF1A3A5C);
const _kTheirBubble = Colors.white;

// ─────────────────────────────────────────
//  Screen
// ─────────────────────────────────────────
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  // bool _isSending = false; // removed — use _sending instead
  final List<ChatMessage>   _messages   = [];
  final TextEditingController _textCtrl = TextEditingController();
  // reverse: true — أحدث رسالة في الأسفل تلقائياً
  final ScrollController    _scroll     = ScrollController();
  final ImagePicker         _picker     = ImagePicker();
  final FocusNode           _focusNode  = FocusNode();

  bool   _loading  = true;
  bool   _sending  = false;
  bool   _hasText  = false;
  Timer? _poll;

  // للـ preview المرفق
  File?   _attachFile;
  String? _attachName;
  bool    _isImage = false;

  @override
  void initState() {
    super.initState();
    _textCtrl.addListener(() {
      final has = _textCtrl.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
    _loadAll();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _pollNew());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _textCtrl.dispose();
    _scroll.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── تحميل كل الرسائل
  Future<void> _loadAll() async {
    try {
      final res = await ApiService.get('/chat');
      if (!mounted) return;
      if (res['success'] == true) {
        setState(() {
          _messages
            ..clear()
            ..addAll((res['data'] as List).map((m) => ChatMessage.fromJson(m)));
          _loading = false;
        });
        _scrollEnd();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Polling — يجلب الرسائل الجديدة فقط
  Future<void> _pollNew() async {
    if (!mounted || _sending) return;
    try {
      final lastId = _messages.isEmpty ? 0 : _messages.last.id;
      final res = await ApiService.get('/chat?after=$lastId');
      if (!mounted) return;
      if (res['success'] == true) {
        final fresh = (res['data'] as List)
            .map((m) => ChatMessage.fromJson(m))
            .where((m) => !_messages.any((e) => e.id == m.id))
            .toList();
        if (fresh.isNotEmpty) {
          // هل المستخدم في الأسفل؟
          final atBottom = !_scroll.hasClients ||
              _scroll.position.pixels >=
                  _scroll.position.maxScrollExtent - 80;
          setState(() => _messages.addAll(fresh));
          if (atBottom) _scrollEnd();
        }
      }
    } catch (_) {}
  }

  // ── إرسال نص
  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if ((text.isEmpty && _attachFile == null) || _sending) return;

    setState(() => _sending = true);
    _textCtrl.clear();

    try {
      if (_attachFile != null) {
        await _uploadFile(_attachFile!, _attachName ?? 'file');
      } else {
        final res = await ApiService.post('/chat', {'message': text});
        if (res['success'] == true && mounted) {
          setState(() => _messages.add(ChatMessage.fromJson(res['data'])));
          _scrollEnd();
        }
      }
    } catch (_) {
      _snack('فشل إرسال الرسالة', error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ── رفع ملف
  Future<void> _uploadFile(File file, String name) async {
    try {
      final token = await ApiService.getToken();
      final req   = http.MultipartRequest(
        'POST', Uri.parse('${AppConstants.baseUrl}/chat'),
      )
        ..headers['Authorization'] = 'Bearer $token'
        ..headers['Accept']        = 'application/json'
        ..files.add(await http.MultipartFile.fromPath(
            'attachment', file.path, filename: name));

      // نص مرفق مع الملف؟
      final extra = _textCtrl.text.trim();
      if (extra.isNotEmpty) req.fields['message'] = extra;

      final streamed = await req.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamed);

      if (!mounted) return;
      if (response.statusCode == 201) {
        final decoded = ApiService.decodeResponse(response.bodyBytes);
        if (decoded['success'] == true) {
          setState(() {
            _messages.add(ChatMessage.fromJson(decoded['data']));
            _attachFile = null;
            _attachName = null;
          });
          _textCtrl.clear();
          _scrollEnd();
        }
      } else {
        _snack('فشل رفع الملف', error: true);
      }
    } catch (_) {
      _snack('حدث خطأ أثناء الرفع', error: true);
    }
  }

  // ── اختيار صورة
  Future<void> _pickImage(ImageSource src) async {
    Navigator.pop(context);
    final xf = await _picker.pickImage(
        source: src, imageQuality: 85, maxWidth: 1920);
    if (xf == null || !mounted) return;
    setState(() {
      _attachFile = File(xf.path);
      _attachName = xf.name;
      _isImage    = true;
    });
  }

  // ── اختيار مستند
  Future<void> _pickDoc() async {
    Navigator.pop(context);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt'],
    );
    if (result == null || !mounted) return;
    setState(() {
      _attachFile = File(result.files.first.path!);
      _attachName = result.files.first.name;
      _isImage    = false;
    });
  }

  void _clearAttach() => setState(() {
        _attachFile = null;
        _attachName = null;
      });

  // ── تحميل وفتح مستند
  Future<void> _openDoc(String url, String? name) async {
    _snack('جاري التحميل...');
    try {
      final res  = await http.get(Uri.parse(url))
          .timeout(const Duration(seconds: 30));
      final dir  = await getTemporaryDirectory();
      final path = '${dir.path}/${name ?? 'file_${DateTime.now().millisecondsSinceEpoch}'}';
      await File(path).writeAsBytes(res.bodyBytes);
      await OpenFile.open(path);
    } catch (_) {
      _snack('تعذر فتح الملف', error: true);
    }
  }

  // ── عرض صورة كاملة
  void _viewImage(String url) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _FullImageViewer(url: url),
        ),
      );

  // ── bottom sheet المرفقات
  void _showAttachSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            Text('إرفاق ملف',
                style: GoogleFonts.cairo(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _attachOption(Icons.camera_alt_rounded, 'كاميرا',
                    const Color(0xFFE3F2FD), Colors.blue,
                    () => _pickImage(ImageSource.camera)),
                _attachOption(Icons.photo_library_rounded, 'معرض',
                    const Color(0xFFE8F5E9), Colors.green,
                    () => _pickImage(ImageSource.gallery)),
                _attachOption(Icons.insert_drive_file_rounded, 'مستند',
                    const Color(0xFFFFF3E0), Colors.orange,
                    _pickDoc),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _attachOption(IconData icon, String label, Color bg, Color ic,
      VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, color: ic, size: 28),
          ),
          const SizedBox(height: 6),
          Text(label,
              style:
                  GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _scrollEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.cairo()),
      backgroundColor: error ? Colors.red[700] : _kPrimary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(12),
    ));
  }

  // ═══════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // ── قائمة الرسائل
          Expanded(child: _buildMessageList()),
          // ── preview المرفق
          if (_attachFile != null) _buildAttachPreview(),
          // ── شريط الإدخال
          _buildInputBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() => AppBar(
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.support_agent_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الإدارة',
                    style: GoogleFonts.cairo(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.white)),
                Text('استشارة خاصة',
                    style: GoogleFonts.cairo(
                        fontSize: 11, color: Colors.white60)),
              ],
            ),
          ],
        ),
      );

  // ── قائمة الرسائل مع فاصل التاريخ
  Widget _buildMessageList() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: _kPrimary));
    }
    if (_messages.isEmpty) {
      return _buildEmptyState();
    }

    // نبني قائمة تتضمن فواصل التاريخ
    final items = <dynamic>[];
    String? lastDate;
    for (final msg in _messages) {
      final dateStr = _friendlyDate(msg.createdAt);
      if (dateStr != lastDate) {
        items.add(dateStr); // فاصل
        lastDate = dateStr;
      }
      items.add(msg);
    }

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        if (item is String) return _buildDateSep(item);
        return _buildBubble(item as ChatMessage);
      },
    );
  }

  Widget _buildEmptyState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: _kPrimary.withOpacity(0.07),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded,
                  size: 60, color: _kPrimary),
            ),
            const SizedBox(height: 20),
            Text('لا توجد رسائل بعد',
                style: GoogleFonts.cairo(
                    fontSize: 17, fontWeight: FontWeight.bold,
                    color: _kPrimary)),
            const SizedBox(height: 8),
            Text('ابدأ محادثتك مع الإدارة',
                style: GoogleFonts.cairo(
                    fontSize: 13, color: Colors.grey[500])),
          ],
        ),
      );

  Widget _buildDateSep(String label) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Expanded(child: Divider(color: Colors.grey[300], height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4)
                ],
              ),
              child: Text(label,
                  style: GoogleFonts.cairo(
                      fontSize: 11, color: Colors.grey[500])),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey[300], height: 1)),
        ]),
      );

  // ── فقاعة رسالة
  Widget _buildBubble(ChatMessage msg) {
    final isMe = msg.isMe;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // أفاتار الإدارة
          if (!isMe) ...[
            _Avatar(label: 'إ', color: _kPrimary),
            const SizedBox(width: 6),
          ],

          // المحتوى
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3, right: 6),
                    child: Text('الإدارة',
                        style: GoogleFonts.cairo(
                            fontSize: 11,
                            color: _kPrimary,
                            fontWeight: FontWeight.bold)),
                  ),

                // الفقاعة
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72,
                  ),
                  decoration: BoxDecoration(
                    color: isMe ? _kMyBubble : _kTheirBubble,
                    borderRadius: BorderRadius.only(
                      topLeft:     const Radius.circular(18),
                      topRight:    const Radius.circular(18),
                      bottomLeft:  Radius.circular(isMe ? 18 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.07),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft:     const Radius.circular(18),
                      topRight:    const Radius.circular(18),
                      bottomLeft:  Radius.circular(isMe ? 18 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 18),
                    ),
                    child: _bubbleContent(msg, isMe),
                  ),
                ),

                // الوقت + علامة القراءة
                Padding(
                  padding: const EdgeInsets.only(top: 3, right: 4, left: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(msg.timeAgo,
                          style: GoogleFonts.cairo(
                              fontSize: 10, color: Colors.grey[500])),
                      if (isMe) ...[
                        const SizedBox(width: 3),
                        Icon(
                          Icons.done_all_rounded,
                          size: 14,
                          color: msg.isRead
                              ? Colors.blue[400]
                              : Colors.grey[400],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // أفاتار الموظف
          if (isMe) ...[
            const SizedBox(width: 6),
            _Avatar(label: 'أ', color: _kPrimaryLt),
          ],
        ],
      ),
    );
  }

  Widget _bubbleContent(ChatMessage msg, bool isMe) {
    final txtColor = isMe ? Colors.white : Colors.black87;

    if (msg.hasImage) {
      return GestureDetector(
        onTap: () => _viewImage(msg.attachmentUrl!),
        child: Stack(
          children: [
            Image.network(
              msg.attachmentUrl!,
              width: 220,
              height: 180,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, p) => p == null
                  ? child
                  : const SizedBox(
                      width: 220,
                      height: 180,
                      child: Center(
                          child: CircularProgressIndicator(
                              color: _kPrimary, strokeWidth: 2))),
              errorBuilder: (_, __, ___) => const SizedBox(
                width: 220, height: 100,
                child: Center(
                    child: Icon(Icons.broken_image,
                        color: Colors.grey, size: 40)),
              ),
            ),
            // طبقة تأثير للضغط
            Positioned.fill(
              child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                      onTap: () => _viewImage(msg.attachmentUrl!))),
            ),
          ],
        ),
      );
    }

    if (msg.hasDoc) {
      return InkWell(
        onTap: () => _openDoc(msg.attachmentUrl!, msg.attachmentName),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: isMe
                      ? Colors.white.withOpacity(0.15)
                      : Colors.orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.insert_drive_file_rounded,
                    color: isMe ? Colors.white : Colors.orange, size: 24),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      msg.attachmentName ?? 'مستند',
                      style: GoogleFonts.cairo(
                          color: txtColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 2),
                    Text('اضغط للفتح',
                        style: GoogleFonts.cairo(
                            color: isMe
                                ? Colors.white54
                                : Colors.grey[500],
                            fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Text(
        msg.message ?? '',
        style: GoogleFonts.cairo(
            color: txtColor, fontSize: 14, height: 1.45),
      ),
    );
  }

  // ── preview المرفق المختار
  Widget _buildAttachPreview() => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, -2))
          ],
        ),
        child: Row(
          children: [
            if (_isImage)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(_attachFile!,
                    width: 48, height: 48, fit: BoxFit.cover),
              )
            else
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.insert_drive_file_rounded,
                    color: Colors.orange, size: 26),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _attachName ?? '',
                style: GoogleFonts.cairo(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              onPressed: _clearAttach,
              icon: const Icon(Icons.close_rounded, color: Colors.red),
              iconSize: 20,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      );

  // ── شريط الإدخال
  Widget _buildInputBar() => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 8,
          top: 8,
          left: 10,
          right: 10,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // زر الإرفاق
            _CircleBtn(
              icon: Icons.attach_file_rounded,
              color: _kPrimary,
              onTap: _sending ? null : _showAttachSheet,
            ),
            const SizedBox(width: 8),

            // حقل النص
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4F8),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _textCtrl,
                  focusNode: _focusNode,
                  style: GoogleFonts.cairo(fontSize: 14),
                  maxLines: 5,
                  minLines: 1,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: 'اكتب رسالتك...',
                    hintStyle: GoogleFonts.cairo(
                        color: Colors.grey[400], fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // زر الإرسال
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _sending
                  ? const SizedBox(
                      width: 44, height: 44,
                      child: Center(
                        child: SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                              color: _kPrimary, strokeWidth: 2.5),
                        ),
                      ),
                    )
                  : _CircleBtn(
                      icon: Icons.send_rounded,
                      color: (_hasText || _attachFile != null)
                          ? _kPrimary
                          : Colors.grey[400]!,
                      onTap: (_hasText || _attachFile != null)
                          ? _send
                          : null,
                    ),
            ),
          ],
        ),
      );

  // ── تحويل ISO date إلى نص صديق
  String _friendlyDate(String iso) {
    try {
      final dt  = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final d     = DateTime(dt.year, dt.month, dt.day);
      if (d == today) return 'اليوم';
      if (d == today.subtract(const Duration(days: 1))) return 'أمس';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }
}

// ─────────────────────────────────────────
//  Widgets مساعدة
// ─────────────────────────────────────────
class _Avatar extends StatelessWidget {
  final String label;
  final Color  color;
  const _Avatar({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => CircleAvatar(
        radius: 15,
        backgroundColor: color,
        child: Text(label,
            style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold)),
      );
}

class _CircleBtn extends StatelessWidget {
  final IconData    icon;
  final Color       color;
  final VoidCallback? onTap;
  const _CircleBtn(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: onTap == null
                ? Colors.grey[200]
                : color.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: onTap == null ? Colors.grey : color,
              size: 22),
        ),
      );
}

// ─────────────────────────────────────────
//  Full Image Viewer
// ─────────────────────────────────────────
class _FullImageViewer extends StatelessWidget {
  final String url;
  const _FullImageViewer({required this.url});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Center(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.network(
              url,
              fit: BoxFit.contain,
              loadingBuilder: (_, child, p) => p == null
                  ? child
                  : const Center(
                      child: CircularProgressIndicator(color: Colors.white)),
              errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image, color: Colors.white, size: 64),
            ),
          ),
        ),
      );
}
