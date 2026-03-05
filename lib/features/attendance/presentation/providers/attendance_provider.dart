// lib/features/attendance/presentation/providers/attendance_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/utils/date_formatter.dart';

final attendanceProvider =
    AsyncNotifierProvider<AttendanceNotifier, List<Map<String, dynamic>>>(
        AttendanceNotifier.new);

final myAttendanceProvider =
    AsyncNotifierProvider<MyAttendanceNotifier, List<Map<String, dynamic>>>(
        MyAttendanceNotifier.new);

// ── Warden: mark attendance ───────────────────────────────────
class AttendanceNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  final _db = FirestoreService.instance;
  DateTime _selectedDate = DateTime.now();

  @override
  Future<List<Map<String, dynamic>>> build() async => _fetch();

  Future<List<Map<String, dynamic>>> _fetch() async {
    final session = ref.read(sessionProvider).valueOrNull;
    if (session == null) return [];

    final dateStr = DateFormatter.formatDate(_selectedDate);

    // Get students in warden's hostel
    final studentsSnap = await _db.students
        .where('college_id', isEqualTo: session.collegeId)
        .where('hostel_id', isEqualTo: session.hostelId ?? '')
        .get();

    final students = studentsSnap.docs.map((d) {
      final s = d.data();
      s['id'] = d.id;
      return s;
    }).toList();
    students.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));

    // Get today's attendance
    final existingSnap = await _db.attendance
        .where('hostel_id', isEqualTo: session.hostelId ?? '')
        .where('date', isEqualTo: dateStr)
        .get();

    final attMap = <String, String>{};
    for (var doc in existingSnap.docs) {
      final a = doc.data();
      attMap[a['student_id'] as String] = a['status'] as String;
    }

    return students.map((sm) {
      return <String, dynamic>{
        ...sm,
        'attendance_status': attMap[sm['id']] ?? 'Present',
        'marked': attMap.containsKey(sm['id']),
      };
    }).toList();
  }

  void setDate(DateTime date) {
    _selectedDate = date;
    ref.invalidateSelf();
  }

  Future<void> markAttendance(String studentId, String hostelId, String status) async {
    final session = ref.read(sessionProvider).valueOrNull!;
    final dateStr = DateFormatter.formatDate(_selectedDate);

    // Use composite doc ID for upsert behavior
    final docId = '${studentId}_$dateStr';
    await _db.attendance.doc(docId).set({
      'college_id': session.collegeId,
      'student_id': studentId,
      'hostel_id': hostelId,
      'date': dateStr,
      'status': status,
      'marked_by': session.id,
    });

    ref.invalidateSelf();
  }

  /// Save bulk attendance
  Future<void> saveBulkAttendance(List<Map<String, dynamic>> records) async {
    final session = ref.read(sessionProvider).valueOrNull!;
    final dateStr = DateFormatter.formatDate(_selectedDate);

    final batch = _db.db.batch();
    for (final r in records) {
      final docId = '${r['id']}_$dateStr';
      batch.set(_db.attendance.doc(docId), {
        'college_id': session.collegeId,
        'student_id': r['id'],
        'hostel_id': session.hostelId,
        'date': dateStr,
        'status': r['attendance_status'],
        'marked_by': session.id,
      });
    }
    await batch.commit();
    ref.invalidateSelf();
  }
}

// ── Student: my attendance ────────────────────────────────────
class MyAttendanceNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  final _db = FirestoreService.instance;

  @override
  Future<List<Map<String, dynamic>>> build() async {
    final session = ref.read(sessionProvider).valueOrNull;
    if (session == null) return [];

    final snap = await _db.attendance
        .where('student_id', isEqualTo: session.id)
        .get();

    final rows = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    rows.sort((a, b) => (b['date'] ?? '').toString().compareTo((a['date'] ?? '').toString()));

    return rows.cast<Map<String, dynamic>>();
  }

  double get attendancePercentage {
    final records = state.valueOrNull ?? [];
    if (records.isEmpty) return 0;
    final present = records.where((r) => r['status'] == 'Present').length;
    return (present / records.length) * 100;
  }
}

