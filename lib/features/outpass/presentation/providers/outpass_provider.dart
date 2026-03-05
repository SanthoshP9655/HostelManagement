// lib/features/outpass/presentation/providers/outpass_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final outpassProvider =
    AsyncNotifierProvider<OutpassNotifier, List<Map<String, dynamic>>>(
        OutpassNotifier.new);

class OutpassNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  final _db = SupabaseService.instance;
  String? _statusFilter;

  @override
  Future<List<Map<String, dynamic>>> build() async => _fetch();

  Future<List<Map<String, dynamic>>> _fetch() async {
    final session = ref.read(sessionProvider).valueOrNull;
    if (session == null) return [];

    var query = _db.client
        .from('outpasses')
        .select('*, students(id,name,register_number,room_number)')
        .eq('college_id', session.collegeId);

    if (session.role == AppConstants.roleStudent) {
      query = _db.client
          .from('outpasses')
          .select()
          .eq('student_id', session.id);
    } else if (session.role == AppConstants.roleWarden && session.hostelId != null) {
      query = _db.client
          .from('outpasses')
          .select('*, students(id,name,register_number,room_number)')
          .eq('college_id', session.collegeId)
          .eq('hostel_id', session.hostelId!);
    }

    final rows = await query.order('created_at', ascending: false) as List;

    if (_statusFilter != null) {
      return rows.where((o) => o['status'] == _statusFilter).toList().cast<Map<String, dynamic>>();
    }
    return rows.cast<Map<String, dynamic>>();
  }

  void setStatusFilter(String? status) {
    _statusFilter = status;
    ref.invalidateSelf();
  }

  Future<void> requestOutpass(String reason) async {
    final session = ref.read(sessionProvider).valueOrNull!;
    final student = await _db.students
        .select('hostel_id')
        .eq('id', session.id)
        .single();

    await _db.outpasses.insert({
      'college_id': session.collegeId,
      'student_id': session.id,
      'hostel_id': student['hostel_id'],
      'reason': reason,
      'status': 'Pending',
    });
    ref.invalidateSelf();
  }

  Future<void> approveOutpass(String id, String studentId) async {
    final session = ref.read(sessionProvider).valueOrNull!;
    await _db.outpasses.update({
      'status': 'Approved',
      'approved_by': session.id,
    }).eq('id', id);

    await NotificationService.instance.sendNotification(
      recipientIds: [studentId],
      role: 'student',
      title: '✅ Outpass Approved',
      body: 'Your outpass request has been approved',
      route: '/student/outpass',
      collegeId: session.collegeId,
    );
    ref.invalidateSelf();
  }

  Future<void> rejectOutpass(String id, String studentId) async {
    final session = ref.read(sessionProvider).valueOrNull!;
    await _db.outpasses.update({'status': 'Rejected'}).eq('id', id);

    await NotificationService.instance.sendNotification(
      recipientIds: [studentId],
      role: 'student',
      title: '❌ Outpass Rejected',
      body: 'Your outpass request has been rejected',
      route: '/student/outpass',
      collegeId: session.collegeId,
    );
    ref.invalidateSelf();
  }

  Future<void> markOut(String id) async {
    await _db.outpasses.update({
      'out_time': DateTime.now().toIso8601String(),
    }).eq('id', id).eq('status', 'Approved');
    ref.invalidateSelf();
  }

  Future<void> markIn(String id) async {
    await _db.outpasses.update({
      'in_time': DateTime.now().toIso8601String(),
    }).eq('id', id);
    ref.invalidateSelf();
  }
}
