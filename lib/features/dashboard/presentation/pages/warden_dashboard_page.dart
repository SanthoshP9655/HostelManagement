// lib/features/dashboard/presentation/pages/warden_dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/widgets/stat_card.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/layouts/responsive_layout.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class WardenDashboardPage extends ConsumerStatefulWidget {
  const WardenDashboardPage({super.key});

  @override
  ConsumerState<WardenDashboardPage> createState() => _WardenDashboardPageState();
}

class _WardenDashboardPageState
    extends ConsumerState<WardenDashboardPage> {
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
    if (session == null || session.hostelId == null) return;
    final db = SupabaseService.instance;
    try {
      final students = await db.students.select('id').eq('hostel_id', session.hostelId!) as List;
      final today = DateFormatter.formatDate(DateTime.now());
      final todayAtt = await db.attendance.select('status').eq('hostel_id', session.hostelId!).eq('date', today) as List;
      final complaints = await db.complaints.select('id,status').eq('hostel_id', session.hostelId!).eq('status', 'Pending') as List;
      final outpasses = await db.outpasses.select('id,status').eq('hostel_id', session.hostelId!).inFilter('status', ['Pending', 'Approved']) as List;

      final present = todayAtt.where((a) => a['status'] == 'Present').length;
      setState(() {
        _stats = {
          'students': students.length,
          'present_today': present,
          'absent_today': todayAtt.length - present,
          'open_complaints': complaints.length,
          'pending_outpass': outpasses.where((o) => o['status'] == 'Pending').length,
          'active_outpass': outpasses.where((o) => o['status'] == 'Approved').length,
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
      const NavigationItem(icon: Icons.report_outlined, activeIcon: Icons.report, label: 'Complaints'),
      const NavigationItem(icon: Icons.how_to_reg_outlined, activeIcon: Icons.how_to_reg, label: 'Attendance'),
      const NavigationItem(icon: Icons.exit_to_app_outlined, activeIcon: Icons.exit_to_app, label: 'Outpass'),
    ];

    return ResponsiveLayout(
      title: 'Warden Dashboard',
      selectedIndex: _selectedIndex,
      items: items,
      onItemSelected: (i) {
        setState(() => _selectedIndex = i);
        final routes = [
          AppRoutes.wardenDashboard,
          AppRoutes.wardenStudents,
          AppRoutes.wardenComplaints,
          AppRoutes.wardenAttendance,
          AppRoutes.wardenOutpass,
        ];
        context.go(routes[i]);
      },
      actions: [
        IconButton(icon: const Icon(Icons.campaign_outlined), onPressed: () => context.push(AppRoutes.wardenNotices)),
        PopupMenuButton(
          icon: const Icon(Icons.more_vert),
          itemBuilder: (_) => [
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
                    const Text('Today\'s Overview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.4,
                      children: [
                        StatCard(title: 'Total Students', value: '${_stats['students'] ?? 0}', icon: Icons.school, color: AppTheme.wardenPrimary),
                        StatCard(title: 'Present Today', value: '${_stats['present_today'] ?? 0}', icon: Icons.check_circle_outline, color: AppTheme.success),
                        StatCard(title: 'Absent Today', value: '${_stats['absent_today'] ?? 0}', icon: Icons.cancel_outlined, color: AppTheme.error),
                        StatCard(title: 'Open Complaints', value: '${_stats['open_complaints'] ?? 0}', icon: Icons.report_outlined, color: AppTheme.studentPrimary),
                        StatCard(title: 'Outpass Pending', value: '${_stats['pending_outpass'] ?? 0}', icon: Icons.pending_outlined, color: AppTheme.warning),
                        StatCard(title: 'Active Outpass', value: '${_stats['active_outpass'] ?? 0}', icon: Icons.exit_to_app, color: AppTheme.info),
                      ],
                    ),
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
          colors: [AppTheme.wardenPrimary, AppTheme.wardenSecondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_pin, color: Colors.white, size: 40),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Welcome back,', style: TextStyle(color: Colors.white70, fontSize: 13)),
              Text(name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              const Text('Hostel Warden', style: TextStyle(color: Colors.white60, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
