// lib/features/dashboard/presentation/pages/admin_dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../shared/widgets/stat_card.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/layouts/responsive_layout.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  int _selectedIndex = 0;
  Map<String, int> _stats = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final session = ref.read(sessionProvider).valueOrNull;
    if (session == null) return;

    final db = SupabaseService.instance;
    try {
      final hostels = await db.hostels.select('id').eq('college_id', session.collegeId) as List;
      final students = await db.students.select('id').eq('college_id', session.collegeId) as List;
      final complaints = await db.complaints.select('id,status').eq('college_id', session.collegeId) as List;
      final outpasses = await db.outpasses.select('id,status').eq('college_id', session.collegeId) as List;

      setState(() {
        _stats = {
          'hostels': hostels.length,
          'students': students.length,
          'complaints': complaints.length,
          'pending': complaints.where((c) => c['status'] == 'Pending').length,
          'in_progress': complaints.where((c) => c['status'] == 'In Progress').length,
          'resolved': complaints.where((c) => c['status'] == 'Resolved').length,
          'outpass_pending': outpasses.where((o) => o['status'] == 'Pending').length,
          'outpass_approved': outpasses.where((o) => o['status'] == 'Approved').length,
        };
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider).valueOrNull;
    final items = [
      const NavigationItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Dashboard'),
      const NavigationItem(icon: Icons.school_outlined, activeIcon: Icons.school, label: 'Students'),
      const NavigationItem(icon: Icons.apartment_outlined, activeIcon: Icons.apartment, label: 'Hostels'),
      const NavigationItem(icon: Icons.report_outlined, activeIcon: Icons.report, label: 'Complaints'),
      const NavigationItem(icon: Icons.campaign_outlined, activeIcon: Icons.campaign, label: 'Notices'),
    ];

    return ResponsiveLayout(
      title: 'Admin Dashboard',
      selectedIndex: _selectedIndex,
      items: items,
      onItemSelected: (i) {
        setState(() => _selectedIndex = i);
        final routes = [
          AppRoutes.adminDashboard,
          AppRoutes.adminStudents,
          AppRoutes.adminHostels,
          AppRoutes.adminComplaints,
          AppRoutes.adminNotices,
        ];
        context.go(routes[i]);
      },
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_outlined),
          onPressed: () { setState(() => _loading = true); _loadStats(); },
        ),
        PopupMenuButton(
          icon: const Icon(Icons.more_vert),
          itemBuilder: (_) => [
            PopupMenuItem(
              child: const Text('Attendance Analytics'),
              onTap: () => context.push(AppRoutes.adminAttendance),
            ),
            PopupMenuItem(
              child: const Text('Logout', style: TextStyle(color: AppTheme.error)),
              onTap: () => ref.read(sessionProvider.notifier).logout(),
            ),
          ],
        ),
      ],
      body: _loading
          ? const LoadingWidget()
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _welcome(session?.name ?? ''),
                    const SizedBox(height: 20),
                    const Text('Overview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    const SizedBox(height: 12),
                    _StatGrid(stats: _stats),
                    const SizedBox(height: 24),
                    const Text('Complaints Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    const SizedBox(height: 12),
                    _ComplaintSummary(stats: _stats),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _welcome(String name) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.adminPrimary, AppTheme.adminSecondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.admin_panel_settings, color: Colors.white, size: 40),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Welcome back,', style: TextStyle(color: Colors.white70, fontSize: 13)),
              Text(name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              const Text('College Administrator', style: TextStyle(color: Colors.white60, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  final Map<String, int> stats;
  const _StatGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        StatCard(title: 'Total Hostels', value: '${stats['hostels'] ?? 0}', icon: Icons.apartment, color: AppTheme.adminPrimary),
        StatCard(title: 'Total Students', value: '${stats['students'] ?? 0}', icon: Icons.school, color: AppTheme.wardenPrimary),
        StatCard(title: 'Total Complaints', value: '${stats['complaints'] ?? 0}', icon: Icons.report, color: AppTheme.studentPrimary),
        StatCard(title: 'Outpass Pending', value: '${stats['outpass_pending'] ?? 0}', icon: Icons.exit_to_app, color: AppTheme.warning),
      ],
    );
  }
}

class _ComplaintSummary extends StatelessWidget {
  final Map<String, int> stats;
  const _ComplaintSummary({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: StatCard(title: 'Pending', value: '${stats['pending'] ?? 0}', icon: Icons.hourglass_empty, color: AppTheme.statusPending)),
        const SizedBox(width: 12),
        Expanded(child: StatCard(title: 'In Progress', value: '${stats['in_progress'] ?? 0}', icon: Icons.work_outline, color: AppTheme.statusInProgress)),
        const SizedBox(width: 12),
        Expanded(child: StatCard(title: 'Resolved', value: '${stats['resolved'] ?? 0}', icon: Icons.check_circle_outline, color: AppTheme.statusResolved)),
      ],
    );
  }
}
