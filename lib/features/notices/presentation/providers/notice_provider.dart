// lib/features/notices/presentation/providers/notice_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final noticeListProvider =
    AsyncNotifierProvider<NoticeListNotifier, List<Map<String, dynamic>>>(
        NoticeListNotifier.new);

class NoticeListNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  final _db = SupabaseService.instance;

  @override
  Future<List<Map<String, dynamic>>> build() async {
    final session = ref.read(sessionProvider).valueOrNull;
    if (session == null) return [];

    final rows = await _db.notices
        .select()
        .eq('college_id', session.collegeId)
        .order('created_at', ascending: false) as List;

    // Students see notices targeted to their hostel OR whole college
    if (session.role == AppConstants.roleStudent) {
      return rows.where((n) =>
          n['hostel_id'] == null ||
          n['hostel_id'] == session.hostelId).toList().cast<Map<String, dynamic>>();
    }

    return rows.cast<Map<String, dynamic>>();
  }

  Future<void> createNotice({
    required String title,
    required String description,
    String? hostelId,
  }) async {
    final session = ref.read(sessionProvider).valueOrNull!;

    await _db.notices.insert({
      'college_id': session.collegeId,
      'hostel_id': hostelId,
      'created_by_role': session.role,
      'created_by_id': session.id,
      'title': title,
      'description': description,
    }).select().single();

    // Get recipients
    final studentsQuery = hostelId != null
        ? _db.students.select('id').eq('college_id', session.collegeId).eq('hostel_id', hostelId)
        : _db.students.select('id').eq('college_id', session.collegeId);

    final students = await studentsQuery as List;
    final ids = students.map((s) => s['id'] as String).toList();

    if (ids.isNotEmpty) {
      await NotificationService.instance.sendNotification(
        recipientIds: ids,
        role: 'student',
        title: '📢 New Notice',
        body: title,
        route: '/student/notices',
        collegeId: session.collegeId,
      );
    }
    ref.invalidateSelf();
  }

  Future<void> updateNotice(String id, {required String title, required String description, String? hostelId}) async {
    await _db.notices.update({
      'title': title,
      'description': description,
      'hostel_id': hostelId,
    }).eq('id', id);
    ref.invalidateSelf();
  }

  Future<void> deleteNotice(String id) async {
    await _db.notices.delete().eq('id', id);
    ref.invalidateSelf();
  }
}
