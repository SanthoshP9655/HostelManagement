// lib/core/services/supabase_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';

class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
    );
  }

  SupabaseClient get client => Supabase.instance.client;

  // ── Shorthand table getters ───────────────────────────────
  SupabaseQueryBuilder get colleges => client.from('colleges');
  SupabaseQueryBuilder get admins => client.from('admins');
  SupabaseQueryBuilder get hostels => client.from('hostels');
  SupabaseQueryBuilder get wardens => client.from('wardens');
  SupabaseQueryBuilder get students => client.from('students');
  SupabaseQueryBuilder get complaints => client.from('complaints');
  SupabaseQueryBuilder get complaintHistory => client.from('complaint_history');
  SupabaseQueryBuilder get attendance => client.from('attendance');
  SupabaseQueryBuilder get notices => client.from('notices');
  SupabaseQueryBuilder get outpasses => client.from('outpasses');
  SupabaseQueryBuilder get deviceTokens => client.from('device_tokens');

  // ── Storage ───────────────────────────────────────────────
  StorageFileApi get complaintsStorage =>
      client.storage.from(AppConstants.complaintsStorageBucket);

  // ── Auth ──────────────────────────────────────────────────
  GoTrueClient get auth => client.auth;
  User? get currentUser => client.auth.currentUser;
}
