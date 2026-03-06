// lib/features/dashboard/presentation/pages/warden_dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/widgets/stat_card.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../student_management/presentation/pages/student_list_page.dart';
import '../../../complaints/presentation/pages/complaints_page.dart';
import '../../../attendance/presentation/pages/attendance_mark_page.dart';
import '../../../outpass/presentation/pages/outpass_warden_page.dart';

class WardenDashboardPage extends ConsumerStatefulWidget {
  const WardenDashboardPage({super.key});

  @override
  ConsumerState<WardenDashboardPage> createState() => _WardenDashboardPageState();
}

class _WardenDashboardPageState extends ConsumerState<WardenDashboardPage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final body = IndexedStack(
      index: _selectedIndex,
      children: const [
        _WardenDashboardBody(),
        StudentListPage(role: 'warden'),
        ComplaintsPage(role: 'warden'),
        AttendanceMarkPage(),
        OutpassWardenPage(),
      ],
    );

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: body,
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppTheme.bgCard,
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard, color: AppTheme.wardenPrimary), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.school_outlined), selectedIcon: Icon(Icons.school, color: AppTheme.wardenPrimary), label: 'Students'),
          NavigationDestination(icon: Icon(Icons.report_outlined), selectedIcon: Icon(Icons.report, color: AppTheme.wardenPrimary), label: 'Complaints'),
          NavigationDestination(icon: Icon(Icons.how_to_reg_outlined), selectedIcon: Icon(Icons.how_to_reg, color: AppTheme.wardenPrimary), label: 'Attendance'),
          NavigationDestination(icon: Icon(Icons.exit_to_app_outlined), selectedIcon: Icon(Icons.exit_to_app, color: AppTheme.wardenPrimary), label: 'Outpass'),
        ],
      ),
    );
  }
}

// ── Dashboard tab body ──────────────────────────────────────────
class _WardenDashboardBody extends ConsumerStatefulWidget {
  const _WardenDashboardBody();

  @override
  ConsumerState<_WardenDashboardBody> createState() => _WardenDashboardBodyState();
}

class _WardenDashboardBodyState extends ConsumerState<_WardenDashboardBody> {
  Map<String, dynamic> _stats = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final session = ref.read(sessionProvider).valueOrNull;
    if (session == null || session.hostelId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final db = FirestoreService.instance;
    try {
      final studentsSnap = await db.students.where('hostel_id', isEqualTo: session.hostelId!).get();
      final today = DateFormatter.formatDate(DateTime.now());
      final todayAttSnap = await db.attendance
          .where('hostel_id', isEqualTo: session.hostelId!)
          .where('date', isEqualTo: today)
          .get();
      final complaintsSnap = await db.complaints
          .where('hostel_id', isEqualTo: session.hostelId!)
          .where('status', isEqualTo: 'Pending')
          .get();
      final outpassesSnap = await db.outpasses
          .where('hostel_id', isEqualTo: session.hostelId!)
          .get();

      final todayAtt = todayAttSnap.docs.map((d) => d.data()).toList();
      final outpasses = outpassesSnap.docs.map((d) => d.data()).toList();
      final present = todayAtt.where((a) => a['status'] == 'Present').length;
      final activeOutpasses = outpasses.where((o) => o['status'] == 'Pending' || o['status'] == 'Approved').toList();

      final complaints = complaintsSnap.docs.map((d) => d.data()).toList();
      complaints.sort((a,b) => (b['created_at'] ?? '').toString().compareTo((a['created_at'] ?? '').toString()));

      if (!mounted) return;
      setState(() {
        _stats = {
          'students': studentsSnap.docs.length,
          'present_today': present,
          'absent_today': todayAtt.length - present,
          'open_complaints': complaints.length,
          'pending_outpass': activeOutpasses.where((o) => o['status'] == 'Pending').length,
          'active_outpass': activeOutpasses.where((o) => o['status'] == 'Approved').length,
          'latest_complaints': complaints.take(3).toList(),
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
        title: const Text('Warden Dashboard'),
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
          IconButton(
            icon: const Icon(Icons.campaign_outlined),
            onPressed: () => context.push(AppRoutes.wardenNotices),
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
                  const Text("Today's Overview", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  const SizedBox(height: 12),
                  GridView.extent(
                    maxCrossAxisExtent: 180,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.15,
                    children: [
                      StatCard(title: 'Total Students', value: '${_stats['students'] ?? 0}', icon: Icons.school, color: AppTheme.wardenPrimary),
                      StatCard(title: 'Present Today', value: '${_stats['present_today'] ?? 0}', icon: Icons.check_circle_outline, color: AppTheme.success),
                      StatCard(title: 'Absent Today', value: '${_stats['absent_today'] ?? 0}', icon: Icons.cancel_outlined, color: AppTheme.error),
                      StatCard(title: 'Open Complaints', value: '${_stats['open_complaints'] ?? 0}', icon: Icons.report_outlined, color: AppTheme.studentPrimary),
                      StatCard(title: 'Outpass Pending', value: '${_stats['pending_outpass'] ?? 0}', icon: Icons.pending_outlined, color: AppTheme.warning),
                      StatCard(title: 'Active Outpass', value: '${_stats['active_outpass'] ?? 0}', icon: Icons.exit_to_app, color: AppTheme.info),
                    ],
                  ),
                  if ((_stats['latest_complaints'] as List?)?.isNotEmpty == true) ...[
                    const SizedBox(height: 24),
                    const Text('Latest Complaints', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    const SizedBox(height: 12),
                    ...(_stats['latest_complaints'] as List).map((c) => _DashboardComplaintItem(complaint: c)),
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
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Welcome back,', style: TextStyle(color: Colors.white70, fontSize: 13)),
                Text(name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                const Text('Hostel Warden', style: TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardComplaintItem extends StatelessWidget {
  final Map<String, dynamic> complaint;
  const _DashboardComplaintItem({required this.complaint});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.wardenComplaintDetail, extra: complaint['id']),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.divider, width: 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(complaint['title'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  const SizedBox(height: 4),
                  Text(complaint['description'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            if (complaint['image_url'] != null && complaint['image_url'].toString().isNotEmpty) ...[
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  complaint['image_url'],
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 20, color: AppTheme.textSecondary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
