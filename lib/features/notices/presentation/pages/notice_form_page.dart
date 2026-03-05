// lib/features/notices/presentation/pages/notice_form_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../providers/notice_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class NoticeFormPage extends ConsumerStatefulWidget {
  final Map<String, dynamic>? notice;
  const NoticeFormPage({super.key, this.notice});

  @override
  ConsumerState<NoticeFormPage> createState() => _NoticeFormPageState();
}

class _NoticeFormPageState extends ConsumerState<NoticeFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String? _hostelId;
  List<Map<String, dynamic>> _hostels = [];
  bool _loading = false;
  bool get _isEdit => notice != null;
  Map<String, dynamic>? get notice => widget.notice;

  @override
  void initState() {
    super.initState();
    _loadHostels();
    if (_isEdit) {
      _titleCtrl.text = notice!['title'] ?? '';
      _descCtrl.text = notice!['description'] ?? '';
      _hostelId = notice!['hostel_id'];
    }
  }

  Future<void> _loadHostels() async {
    final session = ref.read(sessionProvider).valueOrNull;
    if (session == null) return;
    final snap = await FirestoreService.instance.hostels.where('college_id', isEqualTo: session.collegeId).get();
    final rows = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    setState(() => _hostels = rows.cast<Map<String, dynamic>>());
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      if (_isEdit) {
        await ref.read(noticeListProvider.notifier).updateNotice(
          notice!['id'],
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          hostelId: _hostelId,
        );
      } else {
        await ref.read(noticeListProvider.notifier).createNotice(
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          hostelId: _hostelId,
        );
      }
      if (mounted) { AppSnackbar.success(context, _isEdit ? 'Notice updated' : 'Notice published'); context.pop(); }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, e.toString());
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(title: Text(_isEdit ? 'Edit Notice' : 'New Notice')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(children: [
            AppTextField(controller: _titleCtrl, label: 'Title', icon: Icons.title, validator: (v) => Validators.required(v, field: 'Title')),
            const SizedBox(height: 12),
            AppTextField(controller: _descCtrl, label: 'Description', icon: Icons.description_outlined, maxLines: 5, validator: (v) => Validators.required(v, field: 'Description')),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              value: _hostelId,
              decoration: InputDecoration(
                labelText: 'Target Hostel (leave blank for all)',
                filled: true,
                fillColor: AppTheme.bgSurface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              dropdownColor: AppTheme.bgCard,
              style: const TextStyle(color: AppTheme.textPrimary),
              items: [
                const DropdownMenuItem(value: null, child: Text('All Students')),
                ..._hostels.map((h) => DropdownMenuItem<String>(value: h['id'], child: Text(h['name']))),
              ],
              onChanged: (v) => setState(() => _hostelId = v),
            ),
            const SizedBox(height: 24),
            AppButton(label: _isEdit ? 'Update Notice' : 'Publish Notice', isLoading: _loading, gradient: const [AppTheme.info, Color(0xFF2563EB)], onPressed: _save),
          ]),
        ),
      ),
    );
  }
}
