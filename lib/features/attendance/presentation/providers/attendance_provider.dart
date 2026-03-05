// lib/features/attendance/presentation/providers/attendance_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/supabase_service.dart';
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
  final _db = SupabaseService.instance;
  DateTime _selectedDate = DateTime.now();

  @override
  Future<List<Map<String, dynamic>>> build() async => _fetch();

  Future<List<Map<String, dynamic>>> _fetch() async {
    final session = ref.read(sessionProvider).valueOrNull;
    if (session == null) return [];

    final dateStr = DateFormatter.formatDate(_selectedDate);

    // Get students in warden's hostel
    final students = await _db.students
        .select('id,name,register_number,room_number')
        .eq('college_id', session.collegeId)
        .eq('hostel_id', session.hostelId ?? '')
        .order('name') as List;

    // Get today's attendance
    final existing = await _db.attendance
        .select()
        .eq('hostel_id', session.hostelId ?? '')
        .eq('date', dateStr) as List;

    final attMap = {
      for (var a in existing) a['student_id'] as String: a['status'] as String,
    };

    return students.map((s) {
      final sm = s as Map<String, dynamic>;
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

    await _db.attendance.upsert({
      'college_id': session.collegeId,
      'student_id': studentId,
      'hostel_id': hostelId,
      'date': dateStr,
      'status': status,
      'marked_by': session.id,
    }, onConflict: 'student_id,date');

    ref.invalidateSelf();
  }

  /// Save bulk attendance
  Future<void> saveBulkAttendance(List<Map<String, dynamic>> records) async {
    final session = ref.read(sessionProvider).valueOrNull!;
    final dateStr = DateFormatter.formatDate(_selectedDate);

    final batch = records.map((r) => {
      'college_id': session.collegeId,
      'student_id': r['id'],
      'hostel_id': session.hostelId,
      'date': dateStr,
      'status': r['attendance_status'],
      'marked_by': session.id,
    }).toList();

    await _db.attendance.upsert(batch, onConflict: 'student_id,date');
    ref.invalidateSelf();
  }
}

// ── Student: my attendance ────────────────────────────────────
class MyAttendanceNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  final _db = SupabaseService.instance;

  @override
  Future<List<Map<String, dynamic>>> build() async {
    final session = ref.read(sessionProvider).valueOrNull;
    if (session == null) return [];

    final rows = await _db.attendance
        .select()
        .eq('student_id', session.id)
        .order('date', ascending: false) as List;

    return rows.cast<Map<String, dynamic>>();
  }

  double get attendancePercentage {
    final records = state.valueOrNull ?? [];
    if (records.isEmpty) return 0;
    final present = records.where((r) => r['status'] == 'Present').length;
    return (present / records.length) * 100;
  }
}
