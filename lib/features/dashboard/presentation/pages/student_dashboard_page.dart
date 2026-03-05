// lib/features/dashboard/presentation/pages/student_dashboard_page.dart
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

class StudentDashboardPage extends ConsumerStatefulWidget {
  const StudentDashboardPage({super.key});

  @override
  ConsumerState<StudentDashboardPage> createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends ConsumerState<StudentDashboardPage> {
  int _selectedIndex = 0;
  Map<String, dynamic> _stats = {};
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
      final complaints = await db.complaints.select('id,status').eq('student_id', session.id) as List;
      final attendance = await db.attendance.select('status').eq('student_id', session.id) as List;
      final outpasses = await db.outpasses.select('id,status').eq('student_id', session.id).order('created_at', ascending: false) as List;
      final notices = await db.notices.select().eq('college_id', session.collegeId).order('created_at', ascending: false).limit(3) as List;

      final present = attendance.where((a) => a['status'] == 'Present').length;
      final attPct = attendance.isEmpty ? 0.0 : (present / attendance.length) * 100;
      final latestOutpass = outpasses.isNotEmpty ? outpasses.first : null;

      setState(() {
        _stats = {
          'complaints': complaints.length,
          'pending_complaints': complaints.where((c) => c['status'] == 'Pending').length,
          'attendance_pct': attPct.toStringAsFixed(1),
          'latest_outpass': latestOutpass?['status'],
          'notices': notices,
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
      const NavigationItem(icon: Icons.report_outlined, activeIcon: Icons.report, label: 'Complaints'),
      const NavigationItem(icon: Icons.how_to_reg_outlined, activeIcon: Icons.how_to_reg, label: 'Attendance'),
      const NavigationItem(icon: Icons.exit_to_app_outlined, activeIcon: Icons.exit_to_app, label: 'Outpass'),
      const NavigationItem(icon: Icons.campaign_outlined, activeIcon: Icons.campaign, label: 'Notices'),
    ];

    return ResponsiveLayout(
      title: 'My Dashboard',
      selectedIndex: _selectedIndex,
      items: items,
      onItemSelected: (i) {
        setState(() => _selectedIndex = i);
        final routes = [
          AppRoutes.studentDashboard,
          AppRoutes.studentComplaints,
          AppRoutes.studentAttendance,
          AppRoutes.studentOutpass,
          AppRoutes.studentNotices,
        ];
        context.go(routes[i]);
      },
      actions: [
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
                    const Text('My Overview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.4,
                      children: [
                        StatCard(
                          title: 'My Complaints',
                          value: '${_stats['complaints'] ?? 0}',
                          icon: Icons.report,
                          color: AppTheme.studentPrimary,
                          onTap: () => context.push(AppRoutes.studentComplaints),
                        ),
                        StatCard(
                          title: 'Attendance',
                          value: '${_stats['attendance_pct'] ?? '0.0'}%',
                          icon: Icons.how_to_reg,
                          color: AppTheme.success,
                          subtitle: _stats['attendance_pct'] != null && double.parse(_stats['attendance_pct']) < 75
                              ? '⚠️ Below 75%'
                              : null,
                          onTap: () => context.push(AppRoutes.studentAttendance),
                        ),
                        StatCard(
                          title: 'Outpass',
                          value: _stats['latest_outpass'] ?? 'None',
                          icon: Icons.exit_to_app,
                          color: AppTheme.info,
                          onTap: () => context.push(AppRoutes.studentOutpass),
                        ),
                        StatCard(
                          title: 'Open Complaints',
                          value: '${_stats['pending_complaints'] ?? 0}',
                          icon: Icons.pending,
                          color: AppTheme.warning,
                        ),
                      ],
                    ),
                    if ((_stats['notices'] as List?)?.isNotEmpty == true) ...[
                      const SizedBox(height: 24),
                      const Text('Latest Notices', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      const SizedBox(height: 12),
                      ...(_stats['notices'] as List).map((n) => _NoticeItem(notice: n)),
                    ],
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
          colors: [AppTheme.studentPrimary, AppTheme.studentSecondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.school, color: Colors.white, size: 40),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Hello,', style: TextStyle(color: Colors.white70, fontSize: 13)),
              Text(name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              const Text('Student', style: TextStyle(color: Colors.white60, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoticeItem extends StatelessWidget {
  final Map<String, dynamic> notice;
  const _NoticeItem({required this.notice});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.campaign, size: 16, color: AppTheme.info),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  notice['title'] as String,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            notice['description'] as String,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
