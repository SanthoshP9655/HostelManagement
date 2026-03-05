// lib/features/hostel_management/presentation/providers/hostel_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/utils/bcrypt_helper.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final hostelListProvider =
    AsyncNotifierProvider<HostelListNotifier, List<Map<String, dynamic>>>(
        HostelListNotifier.new);

class HostelListNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  final _db = SupabaseService.instance;

  @override
  Future<List<Map<String, dynamic>>> build() async {
    final session = ref.read(sessionProvider).valueOrNull;
    if (session == null) return [];
    final rows = await _db.hostels
        .select('*, wardens(id,name,warden_code)')
        .eq('college_id', session.collegeId)
        .order('name') as List;
    return rows.cast<Map<String, dynamic>>();
  }

  Future<void> addHostel(Map<String, dynamic> data) async {
    final session = ref.read(sessionProvider).valueOrNull!;
    await _db.hostels.insert({...data, 'college_id': session.collegeId});
    ref.invalidateSelf();
  }

  Future<void> updateHostel(String id, Map<String, dynamic> data) async {
    await _db.hostels.update(data).eq('id', id);
    ref.invalidateSelf();
  }

  Future<void> deleteHostel(String id) async {
    await _db.hostels.delete().eq('id', id);
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
    await _db.wardens.insert({
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
    await _db.wardens.update({'password_hash': hash}).eq('id', wardenId);
  }
}
