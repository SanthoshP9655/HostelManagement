// lib/features/notices/presentation/providers/notice_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final noticeListProvider =
    AsyncNotifierProvider<NoticeListNotifier, List<Map<String, dynamic>>>(
        NoticeListNotifier.new);

class NoticeListNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  final _db = FirestoreService.instance;

  @override
  Future<List<Map<String, dynamic>>> build() async {
    final session = ref.read(sessionProvider).valueOrNull;
    if (session == null) return [];

    final snap = await _db.notices.where('college_id', isEqualTo: session.collegeId).get();
    final rows = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    
    rows.sort((a,b) {
      final tA = a['created_at'] ?? '';
      final tB = b['created_at'] ?? '';
      return tB.toString().compareTo(tA.toString());
    });

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

    await _db.notices.add({
      'college_id': session.collegeId,
      'hostel_id': hostelId,
      'created_by_role': session.role,
      'created_by_id': session.id,
      'title': title,
      'description': description,
      'created_at': DateTime.now().toIso8601String(),
    });

    // Get recipients
    var studentsQuery = _db.students.where('college_id', isEqualTo: session.collegeId);
    if (hostelId != null) {
      studentsQuery = studentsQuery.where('hostel_id', isEqualTo: hostelId);
    }
    
    final studentsSnap = await studentsQuery.get();
    final ids = studentsSnap.docs.map((d) => d.id).toList();

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
    await _db.notices.doc(id).update({
      'title': title,
      'description': description,
      'hostel_id': hostelId,
    });
    ref.invalidateSelf();
  }

  Future<void> deleteNotice(String id) async {
    await _db.notices.doc(id).delete();
    ref.invalidateSelf();
  }
}
