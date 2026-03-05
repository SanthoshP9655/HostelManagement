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
import '../../../warden_management/presentation/providers/warden_provider.dart';

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
  bool _loading = false;
  String? _selectedWardenId;
  bool get _isEdit => widget.hostel != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _nameCtrl.text = widget.hostel!['name'] ?? '';
      _blockCtrl.text = widget.hostel!['block'] ?? '';
      // Pre-select the first warden currently assigned to this hostel
      final wardens = widget.hostel!['wardens'] as List? ?? [];
      if (wardens.isNotEmpty) {
        _selectedWardenId = wardens.first['id'] as String?;
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _blockCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      String hostelId;
      if (_isEdit) {
        hostelId = widget.hostel!['id'];
        await ref.read(hostelListProvider.notifier).updateHostel(
          hostelId,
          {'name': _nameCtrl.text.trim(), 'block': _blockCtrl.text.trim()},
        );
      } else {
        hostelId = await ref.read(hostelListProvider.notifier).addHostelAndGetId({
          'name': _nameCtrl.text.trim(),
          'block': _blockCtrl.text.trim(),
        });
      }

      // Link the selected warden to this hostel
      if (_selectedWardenId != null) {
        await ref.read(hostelListProvider.notifier).linkWardenToHostel(
          wardenId: _selectedWardenId!,
          hostelId: hostelId,
          // Unlink any other wardens that were previously assigned to this hostel
          previousHostelId: _isEdit ? widget.hostel!['id'] : null,
        );
      } else if (_isEdit) {
        // If edit and warden was cleared, unlink any existing warden from this hostel
        await ref.read(hostelListProvider.notifier).unlinkAllWardenFromHostel(widget.hostel!['id']);
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
    final wardensAsync = ref.watch(wardenListProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(title: Text(_isEdit ? 'Edit Hostel' : 'Add Hostel')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(
                controller: _nameCtrl,
                label: 'Hostel Name',
                icon: Icons.apartment,
                validator: (v) => Validators.required(v, field: 'Hostel name'),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _blockCtrl,
                label: 'Block',
                icon: Icons.apps_outlined,
                validator: (v) => Validators.required(v, field: 'Block'),
              ),
              const SizedBox(height: 20),
              const Text(
                'Assign Warden',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              wardensAsync.when(
                data: (wardens) => DropdownButtonFormField<String?>(
                  value: _selectedWardenId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Select Warden (optional)',
                    labelStyle: const TextStyle(color: AppTheme.textSecondary),
                    prefixIcon: const Icon(Icons.person_pin, color: AppTheme.adminPrimary),
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
                  dropdownColor: AppTheme.bgCard,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  hint: const Text('No warden assigned', style: TextStyle(color: AppTheme.textSecondary)),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('— No warden assigned —', style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                    ...wardens.map((w) {
                      final isThisHostel = _isEdit && w['hostel_id'] == widget.hostel!['id'];
                      final isAssigned = w['hostel_id'] != null && w['hostel_id'] != '';
                      final hostelName = w['hostels']?['name'] as String? ?? '';
                      final suffix = isThisHostel
                          ? ' ✓'
                          : isAssigned
                              ? ' ($hostelName)'
                              : '';
                      return DropdownMenuItem<String?>(
                        value: w['id'] as String,
                        child: Text(
                          '${w['name']} · ${w['warden_code']}$suffix',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isThisHostel ? AppTheme.success : AppTheme.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                      );
                    }),
                  ],
                  onChanged: (v) => setState(() => _selectedWardenId = v),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Text('Failed to load wardens', style: TextStyle(color: AppTheme.error)),
              ),
              const SizedBox(height: 4),
              const Text(
                'The selected warden will be linked to this hostel. Selecting a warden already assigned to another hostel will move them to this hostel.',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
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
        ),
      ),
    );
  }
}
