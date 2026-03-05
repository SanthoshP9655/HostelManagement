// lib/features/complaints/presentation/providers/complaint_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final complaintListProvider =
    AsyncNotifierProvider<ComplaintListNotifier, List<Map<String, dynamic>>>(
        ComplaintListNotifier.new);

class ComplaintListNotifier
    extends AsyncNotifier<List<Map<String, dynamic>>> {
  final _db = SupabaseService.instance;
  String? _statusFilter;
  String? _hostelFilter;
  String? _priorityFilter;
  String _search = '';

  @override
  Future<List<Map<String, dynamic>>> build() async => _fetch();

  Future<List<Map<String, dynamic>>> _fetch() async {
    final session = ref.read(sessionProvider).valueOrNull;
    if (session == null) return [];

    var query = _db.client
        .from('complaints')
        .select('*, students(id,name,register_number), hostels(id,name)')
        .eq('college_id', session.collegeId);

    // Student sees only their own
    if (session.role == AppConstants.roleStudent) {
      query = _db.client
          .from('complaints')
          .select('*, students(id,name,register_number), hostels(id,name)')
          .eq('college_id', session.collegeId)
          .eq('student_id', session.id);
    }

    // Warden sees only their hostel
    if (session.role == AppConstants.roleWarden && session.hostelId != null) {
      query = _db.client
          .from('complaints')
          .select('*, students(id,name,register_number), hostels(id,name)')
          .eq('college_id', session.collegeId)
          .eq('hostel_id', session.hostelId!);
    }

    final rows = await query.order('created_at', ascending: false) as List;

    return rows.where((c) {
      final matchStatus = _statusFilter == null || c['status'] == _statusFilter;
      final matchHostel = _hostelFilter == null || c['hostel_id'] == _hostelFilter;
      final matchPriority = _priorityFilter == null || c['priority'] == _priorityFilter;
      final matchSearch = _search.isEmpty ||
          (c['title'] as String).toLowerCase().contains(_search.toLowerCase());
      return matchStatus && matchHostel && matchPriority && matchSearch;
    }).cast<Map<String, dynamic>>().toList();
  }

  void setFilter({String? status, String? hostel, String? priority, String search = ''}) {
    _statusFilter = status;
    _hostelFilter = hostel;
    _priorityFilter = priority;
    _search = search;
    ref.invalidateSelf();
  }

  Future<void> createComplaint({
    required String title,
    required String description,
    required String category,
    required String priority,
    String? imageUrl,
  }) async {
    final session = ref.read(sessionProvider).valueOrNull!;

    // Get student's hostel_id
    final student = await _db.students
        .select('hostel_id')
        .eq('id', session.id)
        .single();

    final complaint = await _db.complaints.insert({
      'college_id': session.collegeId,
      'student_id': session.id,
      'hostel_id': student['hostel_id'],
      'title': title,
      'description': description,
      'category': category,
      'priority': priority,
      'status': 'Pending',
      'image_url': imageUrl,
    }).select().single();

    // Record initial history
    await _db.complaintHistory.insert({
      'complaint_id': complaint['id'],
      'changed_by_role': 'student',
      'changed_by_id': session.id,
      'new_status': 'Pending',
      'note': 'Complaint submitted',
    });

    // Notify warden
    final wardens = await _db.wardens
        .select('id')
        .eq('college_id', session.collegeId)
        .eq('hostel_id', student['hostel_id'] as String) as List;

    if (wardens.isNotEmpty) {
      await NotificationService.instance.sendNotification(
        recipientIds: wardens.map((w) => w['id'] as String).toList(),
        role: 'warden',
        title: '🔔 New Complaint',
        body: '$title - Priority: $priority',
        route: '/warden/complaints',
        collegeId: session.collegeId,
      );
    }
    ref.invalidateSelf();
  }

  Future<void> deleteComplaint(String id) async {
    await _db.complaints.delete().eq('id', id).eq('status', 'Pending');
    ref.invalidateSelf();
  }

  Future<void> changeStatus({
    required String complaintId,
    required String newStatus,
    required String oldStatus,
    String? note,
  }) async {
    final session = ref.read(sessionProvider).valueOrNull!;
    await _db.complaints
        .update({'status': newStatus}).eq('id', complaintId);

    await _db.complaintHistory.insert({
      'complaint_id': complaintId,
      'changed_by_role': session.role,
      'changed_by_id': session.id,
      'old_status': oldStatus,
      'new_status': newStatus,
      'note': note,
    });

    // Notify student
    final complaint = await _db.complaints
        .select('student_id')
        .eq('id', complaintId)
        .single();

    await NotificationService.instance.sendNotification(
      recipientIds: [complaint['student_id'] as String],
      role: 'student',
      title: '📋 Complaint Updated',
      body: 'Status changed to $newStatus',
      route: '/student/complaints',
      collegeId: session.collegeId,
    );
    ref.invalidateSelf();
  }

  Future<List<Map<String, dynamic>>> getHistory(String complaintId) async {
    final rows = await _db.complaintHistory
        .select()
        .eq('complaint_id', complaintId)
        .order('changed_at') as List;
    return rows.cast<Map<String, dynamic>>();
  }

  Future<String?> uploadImage(Uint8List bytes, String fileName) async {
    try {
      final path = 'complaints/$fileName';
      await _db.complaintsStorage.uploadBinary(path, bytes,
          fileOptions: const FileOptions(upsert: true));
      return _db.complaintsStorage.getPublicUrl(path);
    } catch (e) {
      debugPrint('Upload error: $e');
      return null;
    }
  }
}
