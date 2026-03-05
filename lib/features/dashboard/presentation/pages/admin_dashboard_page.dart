// lib/features/dashboard/presentation/pages/admin_dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../shared/widgets/stat_card.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../student_management/presentation/pages/student_list_page.dart';
import '../../../hostel_management/presentation/pages/hostel_list_page.dart';
import '../../../complaints/presentation/pages/complaints_page.dart';
import '../../../warden_management/presentation/pages/warden_list_page.dart';
import '../../../outpass/presentation/pages/outpass_admin_page.dart';

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Build the body for the selected tab
    final body = IndexedStack(
      index: _selectedIndex,
      children: const [
        _AdminDashboardBody(),
        StudentListPage(role: 'admin'),
        WardenListPage(),
        HostelListPage(),
        ComplaintsPage(role: 'admin'),
        OutpassAdminPage(),
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
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard, color: AppTheme.adminPrimary), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.school_outlined), selectedIcon: Icon(Icons.school, color: AppTheme.adminPrimary), label: 'Students'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person, color: AppTheme.adminPrimary), label: 'Wardens'),
          NavigationDestination(icon: Icon(Icons.apartment_outlined), selectedIcon: Icon(Icons.apartment, color: AppTheme.adminPrimary), label: 'Hostels'),
          NavigationDestination(icon: Icon(Icons.report_outlined), selectedIcon: Icon(Icons.report, color: AppTheme.adminPrimary), label: 'Complaints'),
          NavigationDestination(icon: Icon(Icons.exit_to_app_outlined), selectedIcon: Icon(Icons.exit_to_app, color: AppTheme.adminPrimary), label: 'Outpass'),
        ],
      ),
    );
  }
}

// ── Dashboard tab body ──────────────────────────────────────────
class _AdminDashboardBody extends ConsumerStatefulWidget {
  const _AdminDashboardBody();

  @override
  ConsumerState<_AdminDashboardBody> createState() => _AdminDashboardBodyState();
}

class _AdminDashboardBodyState extends ConsumerState<_AdminDashboardBody> {
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

    final db = FirestoreService.instance;
    try {
      final hostelsSnap = await db.hostels.where('college_id', isEqualTo: session.collegeId).get();
      final wardensSnap = await db.wardens.where('college_id', isEqualTo: session.collegeId).get();
      final studentsSnap = await db.students.where('college_id', isEqualTo: session.collegeId).get();
      final complaintsSnap = await db.complaints.where('college_id', isEqualTo: session.collegeId).get();

      final complaints = complaintsSnap.docs.map((d) => d.data()).toList();

      if (!mounted) return;
      setState(() {
        _stats = {
          'hostels': hostelsSnap.docs.length,
          'wardens': wardensSnap.docs.length,
          'students': studentsSnap.docs.length,
          'complaints': complaints.length,
          'pending': complaints.where((c) => c['status'] == 'Pending').length,
          'in_progress': complaints.where((c) => c['status'] == 'In Progress').length,
          'resolved': complaints.where((c) => c['status'] == 'Resolved').length,
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
        title: const Text('Admin Dashboard'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => ref.read(sessionProvider.notifier).logout(),
          tooltip: 'Back to Role Selection',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.campaign_outlined),
            onPressed: () => context.push(AppRoutes.adminNotices),
          ),
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
                  const Text('Overview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  const SizedBox(height: 12),
                  _buildStatGrid(context),
                  const SizedBox(height: 24),
                  const Text('Complaints Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  const SizedBox(height: 12),
                  _buildComplaintSummary(),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildStatGrid(BuildContext context) {
    return GridView.extent(
      maxCrossAxisExtent: 200,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        StatCard(title: 'Total Hostels', value: '${_stats['hostels'] ?? 0}', icon: Icons.apartment, color: AppTheme.adminPrimary),
        StatCard(title: 'Total Wardens', value: '${_stats['wardens'] ?? 0}', icon: Icons.person, color: AppTheme.info),
        StatCard(title: 'Total Students', value: '${_stats['students'] ?? 0}', icon: Icons.school, color: AppTheme.wardenPrimary),
        StatCard(title: 'Total Complaints', value: '${_stats['complaints'] ?? 0}', icon: Icons.report, color: AppTheme.studentPrimary),
      ],
    );
  }

  Widget _buildComplaintSummary() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth < 450 ? 2 : 3;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.8,
          children: [
            StatCard(title: 'Pending', value: '${_stats['pending'] ?? 0}', icon: Icons.hourglass_empty, color: AppTheme.statusPending),
            StatCard(title: 'In Progress', value: '${_stats['in_progress'] ?? 0}', icon: Icons.work_outline, color: AppTheme.statusInProgress),
            StatCard(title: 'Resolved', value: '${_stats['resolved'] ?? 0}', icon: Icons.check_circle_outline, color: AppTheme.statusResolved),
          ],
        );
      },
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
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Welcome back,', style: TextStyle(color: Colors.white70, fontSize: 13)),
                Text(name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                const Text('College Administrator', style: TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
