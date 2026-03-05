// lib/features/student_management/presentation/providers/student_provider.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/bcrypt_helper.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final studentListProvider =
    AsyncNotifierProvider<StudentListNotifier, List<Map<String, dynamic>>>(
        StudentListNotifier.new);

class StudentListNotifier
    extends AsyncNotifier<List<Map<String, dynamic>>> {
  final _db = SupabaseService.instance;
  String _search = '';
  String? _hostelFilter;
  String? _yearFilter;

  @override
  Future<List<Map<String, dynamic>>> build() async => _fetch();

  Future<List<Map<String, dynamic>>> _fetch() async {
    final session = ref.read(sessionProvider).valueOrNull;
    if (session == null) return [];

    var query = _db.students
        .select('*, hostels(id,name)')
        .eq('college_id', session.collegeId)
        .order('name');

    if (session.role == AppConstants.roleWarden && session.hostelId != null) {
      query = _db.students
          .select('*, hostels(id,name)')
          .eq('college_id', session.collegeId)
          .eq('hostel_id', session.hostelId!)
          .order('name');
    }

    final rows = await query as List;

    // Client-side filter
    return rows.where((s) {
      final matchSearch = _search.isEmpty ||
          (s['name'] as String).toLowerCase().contains(_search.toLowerCase()) ||
          (s['register_number'] as String).toLowerCase().contains(_search.toLowerCase());
      final matchHostel = _hostelFilter == null || s['hostel_id'] == _hostelFilter;
      final matchYear = _yearFilter == null || s['year'].toString() == _yearFilter;
      return matchSearch && matchHostel && matchYear;
    }).cast<Map<String, dynamic>>().toList();
  }

  void setSearch(String q) {
    _search = q;
    ref.invalidateSelf();
  }

  void setHostelFilter(String? hostelId) {
    _hostelFilter = hostelId;
    ref.invalidateSelf();
  }

  void setYearFilter(String? year) {
    _yearFilter = year;
    ref.invalidateSelf();
  }

  Future<void> addStudent(Map<String, dynamic> data) async {
    final session = ref.read(sessionProvider).valueOrNull!;
    final hash = BcryptHelper.hashPassword(data['password']);
    await _db.students.insert({
      ...data,
      'college_id': session.collegeId,
      'password_hash': hash,
    });
    ref.invalidateSelf();
  }

  Future<void> updateStudent(String id, Map<String, dynamic> data) async {
    final Map<String, dynamic> update = {...data};
    if (update.containsKey('password') && (update['password'] as String).isNotEmpty) {
      update['password_hash'] = BcryptHelper.hashPassword(update['password']);
    }
    update.remove('password');
    await _db.students.update(update).eq('id', id);
    ref.invalidateSelf();
  }

  Future<void> deleteStudent(String id) async {
    await _db.students.delete().eq('id', id);
    ref.invalidateSelf();
  }
}
