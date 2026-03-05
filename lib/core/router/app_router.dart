// lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/pages/role_selector_page.dart';
import '../../features/auth/presentation/pages/admin_login_page.dart';
import '../../features/auth/presentation/pages/warden_login_page.dart';
import '../../features/auth/presentation/pages/student_login_page.dart';
import '../../features/auth/presentation/pages/college_register_page.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/dashboard/presentation/pages/admin_dashboard_page.dart';
import '../../features/dashboard/presentation/pages/warden_dashboard_page.dart';
import '../../features/dashboard/presentation/pages/student_dashboard_page.dart';
import '../../features/student_management/presentation/pages/student_list_page.dart';
import '../../features/student_management/presentation/pages/student_form_page.dart';
import '../../features/hostel_management/presentation/pages/hostel_list_page.dart';
import '../../features/hostel_management/presentation/pages/hostel_form_page.dart';
import '../../features/complaints/presentation/pages/complaints_page.dart';
import '../../features/complaints/presentation/pages/complaint_form_page.dart';
import '../../features/complaints/presentation/pages/complaint_detail_page.dart';
import '../../features/attendance/presentation/pages/attendance_mark_page.dart';
import '../../features/attendance/presentation/pages/my_attendance_page.dart';
import '../../features/attendance/presentation/pages/attendance_analytics_page.dart';
import '../../features/notices/presentation/pages/notices_page.dart';
import '../../features/notices/presentation/pages/notice_form_page.dart';
import '../../features/outpass/presentation/pages/outpass_student_page.dart';
import '../../features/outpass/presentation/pages/outpass_warden_page.dart';
import '../../core/constants/app_constants.dart';

class AppRoutes {
  static const roleSelector = '/';
  static const colRegister = '/college/register';
  static const adminLogin = '/admin/login';
  static const adminDashboard = '/admin/dashboard';
  static const adminStudents = '/admin/students';
  static const adminStudentForm = '/admin/students/form';
  static const adminHostels = '/admin/hostels';
  static const adminHostelForm = '/admin/hostels/form';
  static const adminComplaints = '/admin/complaints';
  static const adminComplaintDetail = '/admin/complaints/detail';
  static const adminNotices = '/admin/notices';
  static const adminNoticeForm = '/admin/notices/form';
  static const adminAttendance = '/admin/attendance';
  static const wardenLogin = '/warden/login';
  static const wardenDashboard = '/warden/dashboard';
  static const wardenStudents = '/warden/students';
  static const wardenStudentForm = '/warden/students/form';
  static const wardenComplaints = '/warden/complaints';
  static const wardenComplaintDetail = '/warden/complaints/detail';
  static const wardenAttendance = '/warden/attendance';
  static const wardenNotices = '/warden/notices';
  static const wardenNoticeForm = '/warden/notices/form';
  static const wardenOutpass = '/warden/outpass';
  static const studentLogin = '/student/login';
  static const studentDashboard = '/student/dashboard';
  static const studentComplaints = '/student/complaints';
  static const studentComplaintForm = '/student/complaints/form';
  static const studentComplaintDetail = '/student/complaints/detail';
  static const studentAttendance = '/student/attendance';
  static const studentNotices = '/student/notices';
  static const studentOutpass = '/student/outpass';
}

// A ChangeNotifier that bridges Riverpod session state → GoRouter refreshListenable
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen(sessionProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final sessionAsync = _ref.read(sessionProvider);
    final session = sessionAsync.valueOrNull;
    final loc = state.uri.toString();

    const publicRoutes = [
      AppRoutes.roleSelector,
      AppRoutes.adminLogin,
      AppRoutes.wardenLogin,
      AppRoutes.studentLogin,
      AppRoutes.colRegister,
    ];

    // While loading session, stay put
    if (sessionAsync.isLoading) return null;

    if (session == null) {
      // Not logged in – allow only public routes
      if (publicRoutes.any((r) => loc.startsWith(r))) return null;
      return AppRoutes.roleSelector;
    }

    // Logged in – if on a public/login route, go to correct dashboard
    if (publicRoutes.any((r) => loc == r || loc.startsWith(r))) {
      return _dashboardForRole(session.role);
    }

    // Prevent cross-role access
    if (session.role == AppConstants.roleAdmin && loc.startsWith('/admin')) return null;
    if (session.role == AppConstants.roleWarden && loc.startsWith('/warden')) return null;
    if (session.role == AppConstants.roleStudent && loc.startsWith('/student')) return null;

    return _dashboardForRole(session.role);
  }
}

final _routerNotifierProvider = Provider<_RouterNotifier>((ref) {
  return _RouterNotifier(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(_routerNotifierProvider);

  return GoRouter(
    initialLocation: AppRoutes.roleSelector,
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      // ── Public ────────────────────────────────────────────
      GoRoute(path: AppRoutes.roleSelector, builder: (c, s) => const RoleSelectorPage()),
      GoRoute(path: AppRoutes.colRegister, builder: (c, s) => const CollegeRegisterPage()),
      GoRoute(path: AppRoutes.adminLogin, builder: (c, s) => const AdminLoginPage()),
      GoRoute(path: AppRoutes.wardenLogin, builder: (c, s) => const WardenLoginPage()),
      GoRoute(path: AppRoutes.studentLogin, builder: (c, s) => const StudentLoginPage()),

      // ── Admin ─────────────────────────────────────────────
      GoRoute(path: AppRoutes.adminDashboard, builder: (c, s) => const AdminDashboardPage()),
      GoRoute(path: AppRoutes.adminStudents, builder: (c, s) => const StudentListPage(role: 'admin')),
      GoRoute(path: AppRoutes.adminStudentForm, builder: (c, s) => StudentFormPage(student: s.extra as Map<String, dynamic>?)),
      GoRoute(path: AppRoutes.adminHostels, builder: (c, s) => const HostelListPage()),
      GoRoute(path: AppRoutes.adminHostelForm, builder: (c, s) => HostelFormPage(hostel: s.extra as Map<String, dynamic>?)),
      GoRoute(path: AppRoutes.adminComplaints, builder: (c, s) => const ComplaintsPage(role: 'admin')),
      GoRoute(path: AppRoutes.adminComplaintDetail, builder: (c, s) => ComplaintDetailPage(complaintId: s.extra as String)),
      GoRoute(path: AppRoutes.adminNotices, builder: (c, s) => const NoticesPage(role: 'admin')),
      GoRoute(path: AppRoutes.adminNoticeForm, builder: (c, s) => NoticeFormPage(notice: s.extra as Map<String, dynamic>?)),
      GoRoute(path: AppRoutes.adminAttendance, builder: (c, s) => const AttendanceAnalyticsPage()),

      // ── Warden ────────────────────────────────────────────
      GoRoute(path: AppRoutes.wardenDashboard, builder: (c, s) => const WardenDashboardPage()),
      GoRoute(path: AppRoutes.wardenStudents, builder: (c, s) => const StudentListPage(role: 'warden')),
      GoRoute(path: AppRoutes.wardenStudentForm, builder: (c, s) => StudentFormPage(student: s.extra as Map<String, dynamic>?)),
      GoRoute(path: AppRoutes.wardenComplaints, builder: (c, s) => const ComplaintsPage(role: 'warden')),
      GoRoute(path: AppRoutes.wardenComplaintDetail, builder: (c, s) => ComplaintDetailPage(complaintId: s.extra as String)),
      GoRoute(path: AppRoutes.wardenAttendance, builder: (c, s) => const AttendanceMarkPage()),
      GoRoute(path: AppRoutes.wardenNotices, builder: (c, s) => const NoticesPage(role: 'warden')),
      GoRoute(path: AppRoutes.wardenNoticeForm, builder: (c, s) => NoticeFormPage(notice: s.extra as Map<String, dynamic>?)),
      GoRoute(path: AppRoutes.wardenOutpass, builder: (c, s) => const OutpassWardenPage()),

      // ── Student ───────────────────────────────────────────
      GoRoute(path: AppRoutes.studentDashboard, builder: (c, s) => const StudentDashboardPage()),
      GoRoute(path: AppRoutes.studentComplaints, builder: (c, s) => const ComplaintsPage(role: 'student')),
      GoRoute(path: AppRoutes.studentComplaintForm, builder: (c, s) => const ComplaintFormPage()),
      GoRoute(path: AppRoutes.studentComplaintDetail, builder: (c, s) => ComplaintDetailPage(complaintId: s.extra as String)),
      GoRoute(path: AppRoutes.studentAttendance, builder: (c, s) => const MyAttendancePage()),
      GoRoute(path: AppRoutes.studentNotices, builder: (c, s) => const NoticesPage(role: 'student')),
      GoRoute(path: AppRoutes.studentOutpass, builder: (c, s) => const OutpassStudentPage()),
    ],
  );
});

String _dashboardForRole(String role) {
  switch (role) {
    case AppConstants.roleAdmin:
      return AppRoutes.adminDashboard;
    case AppConstants.roleWarden:
      return AppRoutes.wardenDashboard;
    default:
      return AppRoutes.studentDashboard;
  }
}
