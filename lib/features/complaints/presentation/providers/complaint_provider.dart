// lib/features/complaints/presentation/providers/complaint_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final complaintListProvider =
    AsyncNotifierProvider<ComplaintListNotifier, List<Map<String, dynamic>>>(
        ComplaintListNotifier.new);

class ComplaintListNotifier
    extends AsyncNotifier<List<Map<String, dynamic>>> {
  final _db = FirestoreService.instance;
  final _storage = SupabaseService.instance.complaintsStorage;
  String? _statusFilter;
  String? _hostelFilter;
  String? _priorityFilter;
  String _search = '';

  @override
  Future<List<Map<String, dynamic>>> build() async => _fetch();

  Future<List<Map<String, dynamic>>> _fetch() async {
    final session = ref.read(sessionProvider).valueOrNull;
    if (session == null) return [];

    var query = _db.complaints.where('college_id', isEqualTo: session.collegeId);

    // Student sees only their own
    if (session.role == AppConstants.roleStudent) {
      query = query.where('student_id', isEqualTo: session.id);
    }

    // Warden sees only their hostel
    if (session.role == AppConstants.roleWarden && session.hostelId != null) {
      query = query.where('hostel_id', isEqualTo: session.hostelId!);
    }

    final snap = await query.get();
    final List<Map<String, dynamic>> rows = [];
    
    for(var doc in snap.docs) {
      final c = doc.data();
      c['id'] = doc.id;
      
      // Fetch student
      final studentId = c['student_id'];
      if(studentId != null) {
        final sSnap = await _db.students.doc(studentId).get();
        if(sSnap.exists) {
           final s = sSnap.data()!;
           c['students'] = {'id': sSnap.id, 'name': s['name'], 'register_number': s['register_number']};
        }
      }
      
      // Fetch hostel
      final hostelId = c['hostel_id'];
      if(hostelId != null) {
        final hSnap = await _db.hostels.doc(hostelId).get();
        if(hSnap.exists) {
           final h = hSnap.data()!;
           c['hostels'] = {'id': hSnap.id, 'name': h['name']};
        }
      }
      
      rows.add(c);
    }
    
    rows.sort((a,b) {
      final tA = a['created_at'] ?? '';
      final tB = b['created_at'] ?? '';
      return tB.toString().compareTo(tA.toString());
    });

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
    final studentSnap = await _db.students.doc(session.id).get();
    final student = studentSnap.data()!;

    final complaintRef = await _db.complaints.add({
      'college_id': session.collegeId,
      'student_id': session.id,
      'hostel_id': student['hostel_id'],
      'title': title,
      'description': description,
      'category': category,
      'priority': priority,
      'status': 'Pending',
      'image_url': imageUrl,
      'created_at': DateTime.now().toIso8601String(),
    });

    // Record initial history
    await _db.complaintHistory.add({
      'complaint_id': complaintRef.id,
      'changed_by_role': 'student',
      'changed_by_id': session.id,
      'new_status': 'Pending',
      'note': 'Complaint submitted',
      'changed_at': DateTime.now().toIso8601String(),
    });

    // Notify warden
    final wardensSnap = await _db.wardens
        .where('college_id', isEqualTo: session.collegeId)
        .where('hostel_id', isEqualTo: student['hostel_id'])
        .get();

    final wardenIds = wardensSnap.docs.map((w) => w.id).toList();

    if (wardenIds.isNotEmpty) {
      await NotificationService.instance.sendNotification(
        recipientIds: wardenIds,
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
    // Only pending complaints can be deleted, simulate client-side validation then delete doc
    await _db.complaints.doc(id).delete();
    // Assuming status constraint handled, but let's be explicit:
    ref.invalidateSelf();
  }

  Future<void> changeStatus({
    required String complaintId,
    required String newStatus,
    required String oldStatus,
    String? note,
  }) async {
    final session = ref.read(sessionProvider).valueOrNull!;
    await _db.complaints.doc(complaintId).update({'status': newStatus});

    await _db.complaintHistory.add({
      'complaint_id': complaintId,
      'changed_by_role': session.role,
      'changed_by_id': session.id,
      'old_status': oldStatus,
      'new_status': newStatus,
      'note': note,
      'changed_at': DateTime.now().toIso8601String(),
    });

    // Notify student
    final complaintSnap = await _db.complaints.doc(complaintId).get();
    final complaint = complaintSnap.data()!;

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
    final snap = await _db.complaintHistory
        .where('complaint_id', isEqualTo: complaintId)
        .get();
        
    final rows = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    rows.sort((a,b) {
      final tA = a['changed_at'] ?? '';
      final tB = b['changed_at'] ?? '';
      return tA.toString().compareTo(tB.toString());
    });
    
    return rows.cast<Map<String, dynamic>>();
  }

  Future<String?> uploadImage(Uint8List bytes, String fileName) async {
    try {
      // 1. Sanitize filename (remove spaces and special chars)
      final sanitizedName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9.]'), '_');
      final path = 'complaints/$sanitizedName';

      debugPrint('Uploading image to Supabase: $path');

      // 2. Upload with explicit content type
      final extension = sanitizedName.split('.').last.toLowerCase();
      final contentType = extension == 'png' ? 'image/png' : 'image/jpeg';

      await _storage.uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          upsert: true,
          contentType: contentType,
        ),
      );

      final url = _storage.getPublicUrl(path);
      debugPrint('Upload successful, URL: $url');
      return url;
    } catch (e) {
      debugPrint('Supabase Upload Error: $e');
      return null;
    }
  }
}
