// lib/features/hostel_management/presentation/providers/hostel_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/utils/bcrypt_helper.dart';
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
      
      final wardensSnap = await _db.wardens.where('hostel_id', isEqualTo: doc.id).get();
      final wardens = wardensSnap.docs.map((wDoc) {
        final w = wDoc.data();
        return {
          'id': wDoc.id,
          'name': w['name'],
          'warden_code': w['warden_code'],
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

  Future<void> updateHostel(String id, Map<String, dynamic> data) async {
    await _db.hostels.doc(id).update(data);
    ref.invalidateSelf();
  }

  Future<void> deleteHostel(String id) async {
    await _db.hostels.doc(id).delete();
    ref.invalidateSelf();
  }

  /// Assign warden to hostel (creates warden record)
  Future<void> assignWarden({
    required String hostelId,
    required String name,
    required String wardenCode,
    required String password,
  }) async {
    final session = ref.read(sessionProvider).valueOrNull!;
    final hash = BcryptHelper.hashPassword(password);
    await _db.wardens.add({
      'college_id': session.collegeId,
      'hostel_id': hostelId,
      'name': name,
      'warden_code': wardenCode,
      'password_hash': hash,
    });
    ref.invalidateSelf();
  }

  /// Reset warden password
  Future<void> resetWardenPassword(String wardenId, String newPassword) async {
    final hash = BcryptHelper.hashPassword(newPassword);
    await _db.wardens.doc(wardenId).update({'password_hash': hash});
  }
}
