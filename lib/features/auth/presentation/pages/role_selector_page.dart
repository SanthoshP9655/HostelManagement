// lib/features/auth/presentation/pages/role_selector_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/router/app_router.dart';



class RoleSelectorPage extends StatelessWidget {
  const RoleSelectorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.adminPrimary, AppTheme.adminSecondary],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.home_work, color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'SmartHostel',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Who are you?',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Select your role to continue',
                    style: TextStyle(fontSize: 15, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 40),
                  _RoleCard(
                    icon: Icons.admin_panel_settings,
                    label: 'College Admin',
                    description: 'Manage hostels, wardens, and students',
                    gradient: const [AppTheme.adminPrimary, AppTheme.adminSecondary],
                    onTap: () => context.push(AppRoutes.adminLogin),
                  ),
                  const SizedBox(height: 16),
                  _RoleCard(
                    icon: Icons.person_pin,
                    label: 'Hostel Warden',
                    description: 'Manage attendance, complaints & outpass',
                    gradient: const [AppTheme.wardenPrimary, AppTheme.wardenSecondary],
                    onTap: () => context.push(AppRoutes.wardenLogin),
                  ),
                  const SizedBox(height: 16),
                  _RoleCard(
                    icon: Icons.school,
                    label: 'Student',
                    description: 'View notices, complaints & outpass status',
                    gradient: const [AppTheme.studentPrimary, AppTheme.studentSecondary],
                    onTap: () => context.push(AppRoutes.studentLogin),
                  ),
                  const SizedBox(height: 32),
                  Center(
                    child: TextButton(
                      onPressed: () => context.push(AppRoutes.colRegister),
                      child: const Text(
                        'Register a new college →',
                        style: TextStyle(color: AppTheme.adminPrimary, fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: gradient.first.withOpacity(0.3), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}
