// lib/features/auth/presentation/pages/college_register_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../providers/auth_provider.dart';

class CollegeRegisterPage extends ConsumerStatefulWidget {
  const CollegeRegisterPage({super.key});

  @override
  ConsumerState<CollegeRegisterPage> createState() => _CollegeRegisterPageState();
}

class _CollegeRegisterPageState extends ConsumerState<CollegeRegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordCtrl.text != _confirmCtrl.text) {
      AppSnackbar.error(context, 'Passwords do not match');
      return;
    }
    await ref.read(sessionProvider.notifier).registerCollege(
          collegeName: _nameCtrl.text.trim(),
          collegeCode: _codeCtrl.text.trim().toUpperCase(),
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
    if (!mounted) return;
    final session = ref.read(sessionProvider);
    if (session.hasError) AppSnackbar.error(context, session.error.toString());
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(sessionProvider).isLoading;
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        title: const Text('Register College'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              const Text(
                'Register your\nCollege 🏫',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 6),
              const Text(
                'Set up your institution on SmartHostel',
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 32),
              AppTextField(
                controller: _nameCtrl,
                label: 'College Name',
                hint: 'Sri Ramachandra Engineering College',
                icon: Icons.account_balance,
                validator: (v) => Validators.required(v, field: 'College name'),
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _codeCtrl,
                label: 'College Code',
                hint: 'Unique code e.g. SREC001',
                icon: Icons.tag,
                validator: Validators.collegeCode,
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _emailCtrl,
                label: 'Admin Email',
                hint: 'admin@college.edu',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: Validators.email,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _passwordCtrl,
                label: 'Password',
                hint: '••••••••',
                icon: Icons.lock_outline,
                isPassword: true,
                validator: Validators.password,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _confirmCtrl,
                label: 'Confirm Password',
                hint: '••••••••',
                icon: Icons.lock_outline,
                isPassword: true,
                validator: (v) => Validators.required(v, field: 'Confirm password'),
              ),
              const SizedBox(height: 32),
              AppButton(
                label: 'Register College',
                isLoading: isLoading,
                gradient: const [AppTheme.adminPrimary, AppTheme.adminSecondary],
                onPressed: _register,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
