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

  // ── Storage ───────────────────────────────────────────────
  StorageFileApi get complaintsStorage =>
      client.storage.from(AppConstants.complaintsStorageBucket);
}
