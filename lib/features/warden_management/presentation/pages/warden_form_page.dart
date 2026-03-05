// lib/features/warden_management/presentation/pages/warden_form_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../hostel_management/presentation/providers/hostel_provider.dart';
import '../providers/warden_provider.dart';

class WardenFormPage extends ConsumerStatefulWidget {
  final Map<String, dynamic>? warden;
  const WardenFormPage({super.key, this.warden});

  @override
  ConsumerState<WardenFormPage> createState() => _WardenFormPageState();
}

class _WardenFormPageState extends ConsumerState<WardenFormPage> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  late TextEditingController _nameCtrl;
  late TextEditingController _codeCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _passCtrl;
  String? _selectedHostelId;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.warden?['name']);
    _codeCtrl = TextEditingController(text: widget.warden?['warden_code']);
    _phoneCtrl = TextEditingController(text: widget.warden?['contact_number']);
    _passCtrl = TextEditingController(); // password handled separately
    _selectedHostelId = widget.warden?['hostel_id'];
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (widget.warden == null && _passCtrl.text.isEmpty) {
      AppSnackbar.error(context, 'Password is required for new warden');
      return;
    }

    setState(() => _loading = true);
    final data = {
      'name': _nameCtrl.text.trim(),
      'warden_code': _codeCtrl.text.trim(),
      'contact_number': _phoneCtrl.text.trim(),
      'hostel_id': _selectedHostelId,
    };
    if (_passCtrl.text.isNotEmpty) {
      data['password'] = _passCtrl.text.trim();
    }

    try {
      final provider = ref.read(wardenListProvider.notifier);
      if (widget.warden == null) {
        await provider.addWarden(data);
        if (mounted) AppSnackbar.success(context, 'Warden added successfully');
      } else {
        await provider.updateWarden(widget.warden!['id'], data);
        if (mounted) AppSnackbar.success(context, 'Warden updated successfully');
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) AppSnackbar.error(context, 'Error saving warden: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hostelsAsync = ref.watch(hostelListProvider);
    final isEdit = widget.warden != null;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Warden' : 'Add Warden'),
      ),
      body: _loading
          ? const LoadingWidget()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildField(
                      controller: _nameCtrl,
                      label: 'Full Name',
                      icon: Icons.person,
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildField(
                      controller: _codeCtrl,
                      label: 'Warden Code',
                      icon: Icons.badge,
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildField(
                      controller: _phoneCtrl,
                      label: 'Contact Number',
                      icon: Icons.phone,
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildField(
                      controller: _passCtrl,
                      label: isEdit ? 'New Password (leave blank to keep)' : 'Password',
                      icon: Icons.lock,
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),
                    hostelsAsync.when(
                      data: (hostels) => DropdownButtonFormField<String>(
                        value: _selectedHostelId,
                        decoration: InputDecoration(
                          labelText: 'Assigned Hostel',
                          prefixIcon: const Icon(Icons.apartment, color: AppTheme.adminPrimary),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppTheme.divider),
                          ),
                          fillColor: AppTheme.bgCard,
                          filled: true,
                        ),
                        dropdownColor: AppTheme.bgCard,
                        items: [
                          const DropdownMenuItem(value: null, child: Text('No Hostel Assigned')),
                          ...hostels.map((h) => DropdownMenuItem(
                                value: h['id'] as String,
                                child: Text(h['name'] as String),
                              ))
                        ],
                        onChanged: (v) => setState(() => _selectedHostelId = v),
                      ),
                      loading: () => const CircularProgressIndicator(),
                      error: (_, __) => const Text('Failed to load hostels'),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.adminPrimary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _submit,
                        child: Text(
                          isEdit ? 'Save Changes' : 'Add Warden',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      style: const TextStyle(color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textSecondary),
        prefixIcon: Icon(icon, color: AppTheme.adminPrimary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.adminPrimary, width: 2),
        ),
        filled: true,
        fillColor: AppTheme.bgCard,
      ),
    );
  }
}
