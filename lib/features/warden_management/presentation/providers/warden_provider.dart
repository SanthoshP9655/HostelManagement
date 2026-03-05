// lib/features/warden_management/presentation/providers/warden_provider.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/utils/bcrypt_helper.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final wardenListProvider =
    AsyncNotifierProvider<WardenListNotifier, List<Map<String, dynamic>>>(
        WardenListNotifier.new);

class WardenListNotifier
    extends AsyncNotifier<List<Map<String, dynamic>>> {
  final _db = FirestoreService.instance;
  String _search = '';
  String? _hostelFilter;

  @override
  Future<List<Map<String, dynamic>>> build() async => _fetch();

  Future<List<Map<String, dynamic>>> _fetch() async {
    final session = ref.read(sessionProvider).valueOrNull;
    if (session == null) return [];

    var query = _db.wardens.where('college_id', isEqualTo: session.collegeId);

    final snap = await query.get();
    final List<Map<String, dynamic>> rows = [];
    for (var doc in snap.docs) {
      final s = doc.data();
      s['id'] = doc.id;
      
      final hostelId = s['hostel_id'];
      if (hostelId != null && hostelId != '') {
        final hSnap = await _db.hostels.doc(hostelId).get();
        if (hSnap.exists) {
          s['hostels'] = {'id': hSnap.id, 'name': hSnap.data()!['name']};
        }
      }
      rows.add(s);
    }
    rows.sort((a,b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));

    // Client-side filter
    return rows.where((s) {
      final matchSearch = _search.isEmpty ||
          (s['name'] as String? ?? '').toLowerCase().contains(_search.toLowerCase()) ||
          (s['warden_code'] as String? ?? '').toLowerCase().contains(_search.toLowerCase());
      final matchHostel = _hostelFilter == null || s['hostel_id'] == _hostelFilter;
      return matchSearch && matchHostel;
    }).toList();
  }

  void setSearch(String q) {
    _search = q;
    ref.invalidateSelf();
  }

  void setHostelFilter(String? hostelId) {
    _hostelFilter = hostelId;
    ref.invalidateSelf();
  }

  Future<void> addWarden(Map<String, dynamic> data) async {
    final session = ref.read(sessionProvider).valueOrNull!;
    final hash = BcryptHelper.hashPassword(data['password']);
    data.remove('password');
    await _db.wardens.add({
      ...data,
      'college_id': session.collegeId,
      'password_hash': hash,
    });
    ref.invalidateSelf();
  }

  Future<void> updateWarden(String id, Map<String, dynamic> data) async {
    final Map<String, dynamic> update = {...data};
    if (update.containsKey('password') && (update['password'] as String).isNotEmpty) {
      update['password_hash'] = BcryptHelper.hashPassword(update['password']);
    }
    update.remove('password');
    await _db.wardens.doc(id).update(update);
    ref.invalidateSelf();
  }

  Future<void> deleteWarden(String id) async {
    await _db.wardens.doc(id).delete();
    // Also delete any token of this warden if we strictly wanted to, 
    // but the system mostly cleans up old tokens over time or ignores invalid notifications
    ref.invalidateSelf();
  }
}
