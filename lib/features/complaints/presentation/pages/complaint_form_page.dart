// lib/features/complaints/presentation/pages/complaint_form_page.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../providers/complaint_provider.dart';

class ComplaintFormPage extends ConsumerStatefulWidget {
  const ComplaintFormPage({super.key});

  @override
  ConsumerState<ComplaintFormPage> createState() => _ComplaintFormPageState();
}

class _ComplaintFormPageState extends ConsumerState<ComplaintFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _category = 'Hostel';
  String _priority = 'Low';
  Uint8List? _imageBytes;
  String? _imageName;
  bool _loading = false;

  final _categories = ['Hostel', 'Room', 'Mess'];
  final _priorities = ['Low', 'Medium', 'High', 'Emergency'];

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1920, imageQuality: 80);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.length > AppConstants.maxImageSizeBytes) {
      if (mounted) AppSnackbar.error(context, 'Image must be under 10MB');
      return;
    }
    setState(() { _imageBytes = bytes; _imageName = file.name; });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      String? imageUrl;
      if (_imageBytes != null && _imageName != null) {
        imageUrl = await ref.read(complaintListProvider.notifier)
            .uploadImage(_imageBytes!, '${DateTime.now().millisecondsSinceEpoch}_$_imageName');
        if (mounted && imageUrl != null) {
          AppSnackbar.success(context, 'Image successfully saved in Supabase!');
          await Future.delayed(const Duration(seconds: 1));
        }
      }
      await ref.read(complaintListProvider.notifier).createComplaint(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        category: _category,
        priority: _priority,
        imageUrl: imageUrl,
      );
      if (mounted) { AppSnackbar.success(context, 'Complaint submitted'); context.pop(); }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, e.toString());
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(title: const Text('New Complaint')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(controller: _titleCtrl, label: 'Title', icon: Icons.title, validator: (v) => Validators.required(v, field: 'Title')),
              const SizedBox(height: 12),
              AppTextField(controller: _descCtrl, label: 'Description', icon: Icons.description_outlined, maxLines: 4, validator: (v) => Validators.required(v, field: 'Description')),
              const SizedBox(height: 16),
              const Text('Category', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: _categories.map((c) => ChoiceChip(
                label: Text(c), selected: _category == c,
                onSelected: (_) => setState(() => _category = c),
              )).toList()),
              const SizedBox(height: 16),
              const Text('Priority', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: _priorities.map((p) => ChoiceChip(
                label: Text(p), selected: _priority == p,
                onSelected: (_) => setState(() => _priority = p),
              )).toList()),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: double.infinity,
                  height: _imageBytes != null ? 160 : 80,
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.divider, style: BorderStyle.solid),
                  ),
                  child: _imageBytes != null
                      ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(_imageBytes!, fit: BoxFit.cover))
                      : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.add_photo_alternate_outlined, color: AppTheme.textSecondary, size: 28),
                          SizedBox(height: 6),
                          Text('Attach photo (optional, max 10MB)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        ]),
                ),
              ),
              const SizedBox(height: 24),
              AppButton(label: 'Submit Complaint', isLoading: _loading, gradient: const [AppTheme.studentPrimary, AppTheme.studentSecondary], onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }
}
