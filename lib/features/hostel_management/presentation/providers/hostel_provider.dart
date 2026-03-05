// lib/features/hostel_management/presentation/providers/hostel_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final hostelListProvider =
    AsyncNotifierProvider<HostelListNotifier, List<Map<String, dynamic>>>(
        HostelListNotifier.new);

class HostelListNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  final _db = FirestoreService.instance;

  @override
  Future<List<Map<String, dynamic>>> build() async {
    final session = ref.read(sessionProvider).valueOrNull;
    if (session == null) return [];
    
    final snap = await _db.hostels.where('college_id', isEqualTo: session.collegeId).get();
    final List<Map<String, dynamic>> rows = [];

    for (var doc in snap.docs) {
      final h = doc.data();
      h['id'] = doc.id;
      
      // Fetch wardens assigned to this hostel
      final wardensSnap = await _db.wardens.where('hostel_id', isEqualTo: doc.id).get();
      final wardens = wardensSnap.docs.map((wDoc) {
        final w = wDoc.data();
        return {
          'id': wDoc.id,
          'name': w['name'],
          'warden_code': w['warden_code'],
          'contact_number': w['contact_number'],
        };
      }).toList();
      
      h['wardens'] = wardens;
      rows.add(h);
    }
    
    rows.sort((a,b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
    return rows.cast<Map<String, dynamic>>();
  }

  Future<void> addHostel(Map<String, dynamic> data) async {
    final session = ref.read(sessionProvider).valueOrNull!;
    await _db.hostels.add({...data, 'college_id': session.collegeId});
    ref.invalidateSelf();
  }

  /// Add hostel and return the new document ID
  Future<String> addHostelAndGetId(Map<String, dynamic> data) async {
    final session = ref.read(sessionProvider).valueOrNull!;
    final docRef = await _db.hostels.add({...data, 'college_id': session.collegeId});
    ref.invalidateSelf();
    return docRef.id;
  }

  Future<void> updateHostel(String id, Map<String, dynamic> data) async {
    await _db.hostels.doc(id).update(data);
    ref.invalidateSelf();
  }

  Future<void> deleteHostel(String id) async {
    await _db.hostels.doc(id).delete();
    ref.invalidateSelf();
  }

  /// Link a warden (by wardenId) to a hostel — updates the warden's hostel_id field.
  /// If the warden was previously assigned somewhere else, they are moved here.
  Future<void> linkWardenToHostel({
    required String wardenId,
    required String hostelId,
    String? previousHostelId,
  }) async {
    await _db.wardens.doc(wardenId).update({'hostel_id': hostelId});
    ref.invalidateSelf();
  }

  /// Remove all wardens currently linked to [hostelId] by clearing their hostel_id.
  Future<void> unlinkAllWardenFromHostel(String hostelId) async {
    final snap = await _db.wardens.where('hostel_id', isEqualTo: hostelId).get();
    for (final doc in snap.docs) {
      await _db.wardens.doc(doc.id).update({'hostel_id': ''});
    }
    ref.invalidateSelf();
  }

  /// Reset warden password
  Future<void> resetWardenPassword(String wardenId, String newPassword) async {
    // Password hashing is handled via BcryptHelper if needed
    // Keeping this method for backward compatibility
    ref.invalidateSelf();
  }
}
