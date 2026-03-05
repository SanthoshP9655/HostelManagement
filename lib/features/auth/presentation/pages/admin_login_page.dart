// lib/features/auth/presentation/pages/admin_login_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../providers/auth_provider.dart';

class AdminLoginPage extends ConsumerStatefulWidget {
  const AdminLoginPage({super.key});

  @override
  ConsumerState<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends ConsumerState<AdminLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _collegeCodeCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _collegeCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(sessionProvider.notifier).loginAdmin(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          collegeCode: _collegeCodeCtrl.text.trim().toUpperCase(),
        );
    if (!mounted) return;
    final session = ref.read(sessionProvider);
    if (session.hasError) {
      AppSnackbar.error(context, session.error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(sessionProvider).isLoading;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        title: const Text('Admin Login'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              _buildHeader(),
              const SizedBox(height: 32),
              AppTextField(
                controller: _collegeCodeCtrl,
                label: 'College Code',
                hint: 'e.g. SREC001',
                icon: Icons.business,
                validator: Validators.collegeCode,
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _emailCtrl,
                label: 'Email',
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
              const SizedBox(height: 32),
              AppButton(
                label: 'Sign In',
                isLoading: isLoading,
                gradient: const [AppTheme.adminPrimary, AppTheme.adminSecondary],
                onPressed: _login,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.adminPrimary, AppTheme.adminSecondary],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 32),
        ),
        const SizedBox(height: 16),
        const Text(
          'Welcome back,\nAdmin 👋',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 8),
        const Text(
          'Sign in to manage your college hostel',
          style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}
