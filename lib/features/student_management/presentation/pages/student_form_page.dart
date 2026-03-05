// lib/features/student_management/presentation/pages/student_form_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../providers/student_provider.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class StudentFormPage extends ConsumerStatefulWidget {
  final Map<String, dynamic>? student;
  const StudentFormPage({super.key, this.student});

  @override
  ConsumerState<StudentFormPage> createState() => _StudentFormPageState();
}

class _StudentFormPageState extends ConsumerState<StudentFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _regCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _deptCtrl = TextEditingController();
  final _blockCtrl = TextEditingController();
  final _roomCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String? _selectedHostelId;
  List<Map<String, dynamic>> _hostels = [];
  bool _loading = false;
  bool get _isEdit => widget.student != null;

  @override
  void initState() {
    super.initState();
    _loadHostels();
    if (_isEdit) _populate();
  }

  Future<void> _loadHostels() async {
    final session = ref.read(sessionProvider).valueOrNull;
    if (session == null) return;
    final rows = await SupabaseService.instance.hostels
        .select('id,name')
        .eq('college_id', session.collegeId) as List;
    setState(() => _hostels = rows.cast<Map<String, dynamic>>());
  }

  void _populate() {
    final s = widget.student!;
    _nameCtrl.text = s['name'] ?? '';
    _regCtrl.text = s['register_number'] ?? '';
    _phoneCtrl.text = s['phone'] ?? '';
    _emailCtrl.text = s['email'] ?? '';
    _yearCtrl.text = s['year']?.toString() ?? '';
    _deptCtrl.text = s['department'] ?? '';
    _blockCtrl.text = s['block'] ?? '';
    _roomCtrl.text = s['room_number'] ?? '';
    _selectedHostelId = s['hostel_id'];
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final data = {
        'name': _nameCtrl.text.trim(),
        'register_number': _regCtrl.text.trim().toUpperCase(),
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'year': int.tryParse(_yearCtrl.text),
        'department': _deptCtrl.text.trim(),
        'block': _blockCtrl.text.trim(),
        'room_number': _roomCtrl.text.trim(),
        'hostel_id': _selectedHostelId,
        'password': _passCtrl.text,
      };
      if (_isEdit) {
        await ref.read(studentListProvider.notifier).updateStudent(widget.student!['id'], data);
        if (mounted) AppSnackbar.success(context, 'Student updated');
      } else {
        await ref.read(studentListProvider.notifier).addStudent(data);
        if (mounted) AppSnackbar.success(context, 'Student added');
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) AppSnackbar.error(context, e.toString());
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(title: Text(_isEdit ? 'Edit Student' : 'Add Student')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              AppTextField(controller: _nameCtrl, label: 'Full Name', icon: Icons.person_outline, validator: (v) => Validators.required(v, field: 'Name')),
              const SizedBox(height: 12),
              AppTextField(controller: _regCtrl, label: 'Register Number', icon: Icons.numbers, validator: (v) => Validators.required(v, field: 'Register number'), textCapitalization: TextCapitalization.characters),
              const SizedBox(height: 12),
              AppTextField(controller: _phoneCtrl, label: 'Phone', icon: Icons.phone_outlined, keyboardType: TextInputType.phone, validator: Validators.phone),
              const SizedBox(height: 12),
              AppTextField(controller: _emailCtrl, label: 'Email', icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress, validator: Validators.email),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: AppTextField(controller: _yearCtrl, label: 'Year', icon: Icons.calendar_today_outlined, keyboardType: TextInputType.number, validator: (v) => Validators.required(v, field: 'Year'))),
                const SizedBox(width: 12),
                Expanded(child: AppTextField(controller: _deptCtrl, label: 'Department', icon: Icons.business_outlined, validator: (v) => Validators.required(v, field: 'Department'))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: AppTextField(controller: _blockCtrl, label: 'Block', icon: Icons.apps_outlined, validator: (v) => Validators.required(v, field: 'Block'))),
                const SizedBox(width: 12),
                Expanded(child: AppTextField(controller: _roomCtrl, label: 'Room No.', icon: Icons.door_front_door_outlined, validator: (v) => Validators.required(v, field: 'Room number'))),
              ]),
              const SizedBox(height: 12),
              // Hostel dropdown
              DropdownButtonFormField<String>(
                value: _selectedHostelId,
                decoration: InputDecoration(
                  labelText: 'Hostel',
                  filled: true,
                  fillColor: AppTheme.bgSurface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                dropdownColor: AppTheme.bgCard,
                style: const TextStyle(color: AppTheme.textPrimary),
                items: _hostels.map((h) => DropdownMenuItem<String>(value: h['id'], child: Text(h['name']))).toList(),
                onChanged: (v) => setState(() => _selectedHostelId = v),
                validator: (v) => v == null ? 'Select a hostel' : null,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _passCtrl,
                label: _isEdit ? 'New Password (leave blank to keep)' : 'Password',
                icon: Icons.lock_outline,
                isPassword: true,
                validator: _isEdit ? null : Validators.password,
              ),
              const SizedBox(height: 24),
              AppButton(
                label: _isEdit ? 'Save Changes' : 'Add Student',
                isLoading: _loading,
                gradient: const [AppTheme.adminPrimary, AppTheme.adminSecondary],
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
