// lib/core/services/auth_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';
import '../utils/bcrypt_helper.dart';
import 'supabase_service.dart';

class UserSession {
  final String id;
  final String role;
  final String collegeId;
  final String collegeName;
  final String collegeCode;
  final String name;
  final String? hostelId;

  const UserSession({
    required this.id,
    required this.role,
    required this.collegeId,
    required this.collegeName,
    required this.collegeCode,
    required this.name,
    this.hostelId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'college_id': collegeId,
        'college_name': collegeName,
        'college_code': collegeCode,
        'name': name,
        'hostel_id': hostelId,
      };

  factory UserSession.fromJson(Map<String, dynamic> json) => UserSession(
        id: json['id'],
        role: json['role'],
        collegeId: json['college_id'],
        collegeName: json['college_name'],
        collegeCode: json['college_code'],
        name: json['name'],
        hostelId: json['hostel_id'],
      );
}

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final _db = SupabaseService.instance;

  // ── Session Persistence ───────────────────────────────────
  Future<void> saveSession(UserSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.sessionKey, jsonEncode(session.toJson()));
  }

  Future<UserSession?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConstants.sessionKey);
    if (raw == null) return null;
    try {
      return UserSession.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.sessionKey);
    try {
      await _db.auth.signOut();
    } catch (_) {}
  }

  // ── Admin Login (Supabase Auth) ───────────────────────────
  Future<UserSession> loginAdmin({
    required String email,
    required String password,
    required String collegeCode,
  }) async {
    // 1. Supabase Auth sign-in
    final res = await _db.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (res.user == null) throw Exception('Invalid credentials');

    // 2. Match college_code
    final adminRow = await _db.admins
        .select('*, colleges(*)')
        .eq('id', res.user!.id)
        .single();

    final college = adminRow['colleges'] as Map<String, dynamic>;
    if (college['college_code'] != collegeCode) {
      await _db.auth.signOut();
      throw Exception('College code does not match');
    }

    final session = UserSession(
      id: res.user!.id,
      role: AppConstants.roleAdmin,
      collegeId: college['id'],
      collegeName: college['college_name'],
      collegeCode: college['college_code'],
      name: adminRow['name'],
    );
    await saveSession(session);
    return session;
  }

  // ── Warden Login (custom bcrypt) ──────────────────────────
  Future<UserSession> loginWarden({
    required String collegeCode,
    required String wardenCode,
    required String password,
  }) async {
    // 1. Find college
    final college = await _db.colleges
        .select()
        .eq('college_code', collegeCode)
        .single();

    // 2. Find warden
    final warden = await _db.wardens
        .select('*, hostels(id,name)')
        .eq('college_id', college['id'] as String)
        .eq('warden_code', wardenCode)
        .single();

    // 3. Verify password
    final isValid = BcryptHelper.verifyPassword(
        password, warden['password_hash'] as String);
    if (!isValid) throw Exception('Invalid credentials');

    final hostel = warden['hostels'] as Map<String, dynamic>;
    final session = UserSession(
      id: warden['id'],
      role: AppConstants.roleWarden,
      collegeId: college['id'],
      collegeName: college['college_name'],
      collegeCode: college['college_code'],
      name: warden['name'],
      hostelId: hostel['id'],
    );
    await saveSession(session);
    return session;
  }

  // ── Student Login (custom bcrypt) ─────────────────────────
  Future<UserSession> loginStudent({
    required String collegeCode,
    required String registerNumber,
    required String password,
  }) async {
    // 1. Find college
    final college = await _db.colleges
        .select()
        .eq('college_code', collegeCode)
        .single();

    // 2. Find student
    final student = await _db.students
        .select()
        .eq('college_id', college['id'] as String)
        .eq('register_number', registerNumber)
        .single();

    // 3. Verify password
    final isValid = BcryptHelper.verifyPassword(
        password, student['password_hash'] as String);
    if (!isValid) throw Exception('Invalid credentials');

    final session = UserSession(
      id: student['id'],
      role: AppConstants.roleStudent,
      collegeId: college['id'],
      collegeName: college['college_name'],
      collegeCode: college['college_code'],
      name: student['name'],
      hostelId: student['hostel_id'],
    );
    await saveSession(session);
    return session;
  }

  // ── College Registration (Admin) ──────────────────────────
  Future<UserSession> registerCollege({
    required String collegeName,
    required String collegeCode,
    required String email,
    required String password,
  }) async {
    // 1. Check college_code uniqueness
    final existing = await _db.colleges
        .select('id')
        .eq('college_code', collegeCode)
        .maybeSingle();
    if (existing != null) {
      throw Exception('College code already exists');
    }

    // 2. Create Supabase Auth user
    final res = await _db.auth.signUp(email: email, password: password);
    if (res.user == null) throw Exception('Registration failed');

    // 3. Insert college
    final college = await _db.colleges.insert({
      'college_name': collegeName,
      'college_code': collegeCode,
      'email': email,
    }).select().single();

    // 4. Insert admin
    await _db.admins.insert({
      'id': res.user!.id,
      'college_id': college['id'],
      'name': 'Admin',
      'email': email,
    });

    final session = UserSession(
      id: res.user!.id,
      role: AppConstants.roleAdmin,
      collegeId: college['id'],
      collegeName: collegeName,
      collegeCode: collegeCode,
      name: 'Admin',
    );
    await saveSession(session);
    return session;
  }
}
