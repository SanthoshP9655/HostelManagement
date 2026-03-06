// lib/features/dashboard/presentation/pages/student_dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../shared/widgets/stat_card.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../complaints/presentation/pages/complaints_page.dart';
import '../../../attendance/presentation/pages/my_attendance_page.dart';
import '../../../outpass/presentation/pages/outpass_student_page.dart';
import '../../../notices/presentation/pages/notices_page.dart';
import '../../../../core/wrappers/student_portal_wrapper.dart';

class StudentDashboardPage extends ConsumerStatefulWidget {
  const StudentDashboardPage({super.key});

  @override
  ConsumerState<StudentDashboardPage> createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends ConsumerState<StudentDashboardPage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final body = IndexedStack(
      index: _selectedIndex,
      children: const [
        _StudentDashboardBody(),
        ComplaintsPage(role: 'student'),
        MyAttendancePage(),
        OutpassStudentPage(),
        NoticesPage(role: 'student'),
      ],
    );

    return StudentPortalWrapper(
      child: Scaffold(
        backgroundColor: AppTheme.bgDark,
        body: body,
        bottomNavigationBar: NavigationBar(
          backgroundColor: AppTheme.bgCard,
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard, color: AppTheme.studentPrimary), label: 'Dashboard'),
            NavigationDestination(icon: Icon(Icons.report_outlined), selectedIcon: Icon(Icons.report, color: AppTheme.studentPrimary), label: 'Complaints'),
            NavigationDestination(icon: Icon(Icons.how_to_reg_outlined), selectedIcon: Icon(Icons.how_to_reg, color: AppTheme.studentPrimary), label: 'Attendance'),
            NavigationDestination(icon: Icon(Icons.exit_to_app_outlined), selectedIcon: Icon(Icons.exit_to_app, color: AppTheme.studentPrimary), label: 'Outpass'),
            NavigationDestination(icon: Icon(Icons.campaign_outlined), selectedIcon: Icon(Icons.campaign, color: AppTheme.studentPrimary), label: 'Notices'),
          ],
        ),
      ),
    );
  }
}

// ── Dashboard tab body ──────────────────────────────────────────
class _StudentDashboardBody extends ConsumerStatefulWidget {
  const _StudentDashboardBody();

  @override
  ConsumerState<_StudentDashboardBody> createState() => _StudentDashboardBodyState();
}

class _StudentDashboardBodyState extends ConsumerState<_StudentDashboardBody> {
  Map<String, dynamic> _stats = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final session = ref.read(sessionProvider).valueOrNull;
    if (session == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final db = FirestoreService.instance;
    try {
      final complaintsSnap = await db.complaints.where('student_id', isEqualTo: session.id).get();
      final attendanceSnap = await db.attendance.where('student_id', isEqualTo: session.id).get();
      final outpassesSnap = await db.outpasses.where('student_id', isEqualTo: session.id).get();
      final noticesSnap = await db.notices.where('college_id', isEqualTo: session.collegeId).get();

      final complaints = complaintsSnap.docs.map((d) => d.data()).toList();
      final attendance = attendanceSnap.docs.map((d) => d.data()).toList();
      final outpasses = outpassesSnap.docs.map((d) => d.data()).toList();
      outpasses.sort((a,b) => (b['created_at'] ?? '').toString().compareTo((a['created_at'] ?? '').toString()));

      final noticesList = noticesSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      noticesList.sort((a,b) => (b['created_at'] ?? '').toString().compareTo((a['created_at'] ?? '').toString()));
      final notices = noticesList.take(3).toList();

      final present = attendance.where((a) => a['status'] == 'Present').length;
      final attPct = attendance.isEmpty ? 0.0 : (present / attendance.length) * 100;
      final latestOutpass = outpasses.isNotEmpty ? outpasses.first : null;

      if (!mounted) return;
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
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text('My Dashboard'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => ref.read(sessionProvider.notifier).logout(),
          tooltip: 'Back to Role Selection',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () { setState(() => _loading = true); _loadStats(); },
          ),
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
      ),
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
                  GridView.extent(
                    maxCrossAxisExtent: 190,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.15,
                    children: [
                      StatCard(
                        title: 'My Complaints',
                        value: '${_stats['complaints'] ?? 0}',
                        icon: Icons.report,
                        color: AppTheme.studentPrimary,
                      ),
                      StatCard(
                        title: 'Attendance',
                        value: '${_stats['attendance_pct'] ?? '0.0'}%',
                        icon: Icons.how_to_reg,
                        color: AppTheme.success,
                        subtitle: _stats['attendance_pct'] != null && double.parse(_stats['attendance_pct']) < 75
                            ? '⚠️ Below 75%'
                            : null,
                      ),
                      StatCard(
                        title: 'Outpass',
                        value: _stats['latest_outpass'] ?? 'None',
                        icon: Icons.exit_to_app,
                        color: AppTheme.info,
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
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Hello,', style: TextStyle(color: Colors.white70, fontSize: 13)),
                Text(name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                const Text('Student', style: TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
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
