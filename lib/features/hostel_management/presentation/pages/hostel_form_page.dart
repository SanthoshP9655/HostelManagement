// lib/features/hostel_management/presentation/pages/hostel_form_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../providers/hostel_provider.dart';

class HostelFormPage extends ConsumerStatefulWidget {
  final Map<String, dynamic>? hostel;
  const HostelFormPage({super.key, this.hostel});

  @override
  ConsumerState<HostelFormPage> createState() => _HostelFormPageState();
}

class _HostelFormPageState extends ConsumerState<HostelFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _blockCtrl = TextEditingController();
  // Warden assignment fields
  final _wardenNameCtrl = TextEditingController();
  final _wardenCodeCtrl = TextEditingController();
  final _wardenPassCtrl = TextEditingController();
  bool _loading = false;
  bool _showWardenForm = false;
  bool get _isEdit => widget.hostel != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _nameCtrl.text = widget.hostel!['name'] ?? '';
      _blockCtrl.text = widget.hostel!['block'] ?? '';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      if (_isEdit) {
        await ref.read(hostelListProvider.notifier).updateHostel(
          widget.hostel!['id'],
          {'name': _nameCtrl.text.trim(), 'block': _blockCtrl.text.trim()},
        );
      } else {
        // First create hostel then assign warden
        await ref.read(hostelListProvider.notifier).addHostel({
          'name': _nameCtrl.text.trim(),
          'block': _blockCtrl.text.trim(),
        });
      }

      // Assign warden if filled
      if (_showWardenForm && _wardenNameCtrl.text.isNotEmpty) {
        final hostels = ref.read(hostelListProvider).valueOrNull ?? [];
        final hostel = hostels.lastWhere((h) => h['name'] == _nameCtrl.text.trim(), orElse: () => widget.hostel ?? {});
        if (hostel['id'] != null) {
          await ref.read(hostelListProvider.notifier).assignWarden(
            hostelId: hostel['id'],
            name: _wardenNameCtrl.text.trim(),
            wardenCode: _wardenCodeCtrl.text.trim(),
            password: _wardenPassCtrl.text,
          );
        }
      }

      if (mounted) {
        AppSnackbar.success(context, _isEdit ? 'Hostel updated' : 'Hostel created');
        context.pop();
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, e.toString());
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(title: Text(_isEdit ? 'Edit Hostel' : 'Add Hostel')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(controller: _nameCtrl, label: 'Hostel Name', icon: Icons.apartment, validator: (v) => Validators.required(v, field: 'Hostel name')),
              const SizedBox(height: 12),
              AppTextField(controller: _blockCtrl, label: 'Block', icon: Icons.apps_outlined, validator: (v) => Validators.required(v, field: 'Block')),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => setState(() => _showWardenForm = !_showWardenForm),
                child: Row(children: [
                  Checkbox(value: _showWardenForm, onChanged: (v) => setState(() => _showWardenForm = v ?? false)),
                  const Text('Assign a warden to this hostel', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                ]),
              ),
              if (_showWardenForm) ...[
                const SizedBox(height: 12),
                AppTextField(controller: _wardenNameCtrl, label: 'Warden Name', icon: Icons.person_pin),
                const SizedBox(height: 12),
                AppTextField(controller: _wardenCodeCtrl, label: 'Warden Code', icon: Icons.badge_outlined),
                const SizedBox(height: 12),
                AppTextField(controller: _wardenPassCtrl, label: 'Warden Password', icon: Icons.lock_outline, isPassword: true),
              ],
              const SizedBox(height: 24),
              AppButton(
                label: _isEdit ? 'Save Changes' : 'Create Hostel',
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
