// lib/features/auth/presentation/pages/warden_login_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../providers/auth_provider.dart';

class WardenLoginPage extends ConsumerStatefulWidget {
  const WardenLoginPage({super.key});

  @override
  ConsumerState<WardenLoginPage> createState() => _WardenLoginPageState();
}

class _WardenLoginPageState extends ConsumerState<WardenLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _collegeCodeCtrl = TextEditingController();
  final _wardenCodeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _collegeCodeCtrl.dispose();
    _wardenCodeCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(sessionProvider.notifier).loginWarden(
          collegeCode: _collegeCodeCtrl.text.trim().toUpperCase(),
          wardenCode: _wardenCodeCtrl.text.trim(),
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
        title: const Text('Warden Login'),
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
                controller: _wardenCodeCtrl,
                label: 'Warden Code',
                hint: 'e.g. WRD001',
                icon: Icons.badge_outlined,
                validator: (v) => Validators.required(v, field: 'Warden code'),
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
                gradient: const [AppTheme.wardenPrimary, AppTheme.wardenSecondary],
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
              colors: [AppTheme.wardenPrimary, AppTheme.wardenSecondary],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.person_pin, color: Colors.white, size: 32),
        ),
        const SizedBox(height: 16),
        const Text(
          'Welcome,\nWarden 👋',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 8),
        const Text(
          'Sign in to manage your hostel',
          style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}
