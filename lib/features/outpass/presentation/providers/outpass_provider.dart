// lib/features/outpass/presentation/providers/outpass_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final outpassProvider =
    AsyncNotifierProvider<OutpassNotifier, List<Map<String, dynamic>>>(
        OutpassNotifier.new);

class OutpassNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  final _db = FirestoreService.instance;
  String? _statusFilter;

  @override
  Future<List<Map<String, dynamic>>> build() async => _fetch();

  Future<List<Map<String, dynamic>>> _fetch() async {
    final session = ref.read(sessionProvider).valueOrNull;
    if (session == null) return [];

    var query = _db.outpasses.where('college_id', isEqualTo: session.collegeId);

    if (session.role == AppConstants.roleStudent) {
      // Chain both filters — student sees ONLY their own outpasses within their college
      query = query.where('student_id', isEqualTo: session.id);
    } else if (session.role == AppConstants.roleWarden && session.hostelId != null) {
      // Warden sees only their hostel's outpasses
      query = query.where('hostel_id', isEqualTo: session.hostelId!);
    }
    // Admin sees all outpasses for the college (no additional filter)

    final snap = await query.get();
    final List<Map<String, dynamic>> rows = [];
    
    for (var doc in snap.docs) {
      final o = doc.data();
      o['id'] = doc.id;
      
      if (session.role != AppConstants.roleStudent) {
        final studentDoc = await _db.students.doc(o['student_id']).get();
        if (studentDoc.exists) {
           final s = studentDoc.data()!;
           o['students'] = {
             'id': studentDoc.id,
             'name': s['name'],
             'register_number': s['register_number'],
             'room_number': s['room_number']
           };
        }
      }
      rows.add(o);
    }
    
    // Sort by created_at desc manually
    rows.sort((a,b) {
      final tA = a['created_at'] ?? '';
      final tB = b['created_at'] ?? '';
      return tB.toString().compareTo(tA.toString());
    });

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
    final studentDoc = await _db.students.doc(session.id).get();
    final student = studentDoc.data()!;

    await _db.outpasses.add({
      'college_id': session.collegeId,
      'student_id': session.id,
      'hostel_id': student['hostel_id'],
      'reason': reason,
      'status': 'Pending',
      'created_at': DateTime.now().toIso8601String(),
    });
    ref.invalidateSelf();
  }

  Future<void> approveOutpass(String id, String studentId) async {
    final session = ref.read(sessionProvider).valueOrNull!;
    await _db.outpasses.doc(id).update({
      'status': 'Approved',
      'approved_by': session.id,
    });

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
    await _db.outpasses.doc(id).update({'status': 'Rejected'});

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
    await _db.outpasses.doc(id).update({
      'out_time': DateTime.now().toIso8601String(),
    });
    ref.invalidateSelf();
  }

  Future<void> markIn(String id) async {
    await _db.outpasses.doc(id).update({
      'in_time': DateTime.now().toIso8601String(),
    });
    ref.invalidateSelf();
  }
}
