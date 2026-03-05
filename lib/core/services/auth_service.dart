// lib/core/services/auth_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/app_constants.dart';
import '../utils/bcrypt_helper.dart';
import 'firestore_service.dart';

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

  final _db = FirestoreService.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
      await _auth.signOut();
    } catch (_) {}
  }

  // ── Admin Login (Firebase Auth) ───────────────────────────
  Future<UserSession> loginAdmin({
    required String email,
    required String password,
    required String collegeCode,
  }) async {
    try {
      // 1. Firebase Auth sign-in
      final res = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (res.user == null) throw Exception('Invalid credentials');

      // 2. Load Auth Data
      final adminSnap = await _db.admins.doc(res.user!.uid).get();
      if (!adminSnap.exists) {
        await _auth.signOut();
        throw Exception('Admin details not found in database. Make sure you entered the correct College Admin account.');
      }
      final adminRow = adminSnap.data()!;

      final collegeSnap = await _db.colleges.doc(adminRow['college_id']).get();
      if (!collegeSnap.exists) {
        await _auth.signOut();
        throw Exception('College details not found for this admin.');
      }
      final college = collegeSnap.data()!;
      college['id'] = collegeSnap.id;

      if (college['college_code'] != collegeCode) {
        await _auth.signOut();
        throw Exception('College code does not match.');
      }

      final session = UserSession(
        id: res.user!.uid,
        role: AppConstants.roleAdmin,
        collegeId: college['id'],
        collegeName: college['college_name'] ?? 'Unknown',
        collegeCode: college['college_code'],
        name: adminRow['name'] ?? 'Admin',
      );
      await saveSession(session);
      return session;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        throw Exception('Incorrect email or password. Please try again.');
      } else if (e.code == 'invalid-email') {
        throw Exception('Please enter a valid email address.');
      } else if (e.code == 'network-request-failed') {
        throw Exception('Network error. Please check your internet connection.');
      } else {
        throw Exception(e.message ?? 'Authentication failed (${e.code})');
      }
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  // ── Warden Login (custom bcrypt) ──────────────────────────
  Future<UserSession> loginWarden({
    required String collegeCode,
    required String wardenCode,
    required String password,
  }) async {
    try {
      // 1. Find college
      final collegeSnap = await _db.colleges.where('college_code', isEqualTo: collegeCode).get();
      if (collegeSnap.docs.isEmpty) throw Exception('College not found');
      final college = collegeSnap.docs.first.data();
      college['id'] = collegeSnap.docs.first.id;

      // 2. Find warden
      final wardenSnap = await _db.wardens
          .where('college_id', isEqualTo: college['id'])
          .where('warden_code', isEqualTo: wardenCode)
          .get();
      if (wardenSnap.docs.isEmpty) throw Exception('Warden code not found for this college.');
      final warden = wardenSnap.docs.first.data();
      warden['id'] = wardenSnap.docs.first.id;

      // 3. Verify password
      final isValid = BcryptHelper.verifyPassword(
          password, warden['password_hash'] as String);
      if (!isValid) throw Exception('Invalid credentials provided.');

      final hostelSnap = await _db.hostels.doc(warden['hostel_id']).get();
      final hostel = hostelSnap.exists ? hostelSnap.data()! : {};
      hostel['id'] = hostelSnap.id;

      final session = UserSession(
        id: warden['id'],
        role: AppConstants.roleWarden,
        collegeId: college['id'],
        collegeName: college['college_name'] ?? 'Unknown',
        collegeCode: college['college_code'],
        name: warden['name'] ?? 'Warden',
        hostelId: hostel['id'],
      );
      await saveSession(session);
      return session;
    } on FirebaseException catch (e) {
      throw Exception('Network or server error occurred. Please try again.');
    } catch (e) {
      if (e.toString().contains('HostelManagement Exception:')) {
         throw Exception(e.toString().replaceAll('HostelManagement Exception: ', '')); 
      }
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // ── Student Login (custom bcrypt) ─────────────────────────
  Future<UserSession> loginStudent({
    required String collegeCode,
    required String registerNumber,
    required String password,
  }) async {
    try {
      // 1. Find college
      final collegeSnap = await _db.colleges.where('college_code', isEqualTo: collegeCode).get();
      if (collegeSnap.docs.isEmpty) throw Exception('College not found');
      final college = collegeSnap.docs.first.data();
      college['id'] = collegeSnap.docs.first.id;

      // 2. Find student
      final studentSnap = await _db.students
          .where('college_id', isEqualTo: college['id'])
          .where('register_number', isEqualTo: registerNumber)
          .get();
      if (studentSnap.docs.isEmpty) throw Exception('Register number not found for this college.');
      final student = studentSnap.docs.first.data();
      student['id'] = studentSnap.docs.first.id;

      // 3. Verify password
      final isValid = BcryptHelper.verifyPassword(
          password, student['password_hash'] as String);
      if (!isValid) throw Exception('Invalid credentials provided.');

      final session = UserSession(
        id: student['id'],
        role: AppConstants.roleStudent,
        collegeId: college['id'],
        collegeName: college['college_name'] ?? 'Unknown',
        collegeCode: college['college_code'],
        name: student['name'] ?? 'Student',
        hostelId: student['hostel_id'],
      );
      await saveSession(session);
      return session;
    } on FirebaseException catch (e) {
      throw Exception('Network or server error occurred. Please try again.');
    } catch (e) {
      if (e.toString().contains('HostelManagement Exception:')) {
         throw Exception(e.toString().replaceAll('HostelManagement Exception: ', '')); 
      }
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // ── College Registration (Admin) ──────────────────────────
  Future<UserSession> registerCollege({
    required String collegeName,
    required String collegeCode,
    required String email,
    required String password,
  }) async {
    // 1. Check college_code uniqueness
    final existing = await _db.colleges.where('college_code', isEqualTo: collegeCode).get();
    if (existing.docs.isNotEmpty) {
      throw Exception('College code already exists');
    }

    // 2. Create Firebase Auth user
    final res = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    if (res.user == null) throw Exception('Registration failed');

    // 3. Insert college
    final collegeRef = await _db.colleges.add({
      'college_name': collegeName,
      'college_code': collegeCode,
      'email': email,
    });

    // 4. Insert admin
    await _db.admins.doc(res.user!.uid).set({
      'college_id': collegeRef.id,
      'name': 'Admin',
      'email': email,
    });

    final session = UserSession(
      id: res.user!.uid,
      role: AppConstants.roleAdmin,
      collegeId: collegeRef.id,
      collegeName: collegeName,
      collegeCode: collegeCode,
      name: 'Admin',
    );
    await saveSession(session);
    return session;
  }
}

