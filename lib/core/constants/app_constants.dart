// lib/core/constants/app_constants.dart
class AppConstants {
  AppConstants._();

  // Supabase
  static const String supabaseUrl = 'https://mplyhxgdwipyedgccbji.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1wbHloeGdkd2lweWVkZ2NjYmppIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI2Mjg0NzMsImV4cCI6MjA4ODIwNDQ3M30.uqOPRyfKNa59mcloBY1bQVAwzn7rJTwmGlz-xXBFLKk';

  // Storage
  static const String complaintsStorageBucket = 'complaints';
  static const int maxImageSizeBytes = 10 * 1024 * 1024; // 10MB

  // Session Keys
  static const String sessionKey = 'user_session';
  static const String roleKey = 'user_role';

  // Roles
  static const String roleAdmin = 'admin';
  static const String roleWarden = 'warden';
  static const String roleStudent = 'student';

  // Pagination
  static const int pageSize = 20;

  // Debounce
  static const int debounceMs = 400;

  // App Info
  static const String appName = 'SmartHostel';
  static const String appVersion = '1.0.0';
}
