// lib/features/auth/presentation/providers/auth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/notification_service.dart';

// ── Session Provider ──────────────────────────────────────────
final sessionProvider =
    AsyncNotifierProvider<SessionNotifier, UserSession?>(SessionNotifier.new);

class SessionNotifier extends AsyncNotifier<UserSession?> {
  @override
  Future<UserSession?> build() async {
    return await AuthService.instance.loadSession();
  }

  Future<void> loginAdmin({
    required String email,
    required String password,
    required String collegeCode,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final session = await AuthService.instance.loginAdmin(
        email: email,
        password: password,
        collegeCode: collegeCode,
      );
      try {
        await NotificationService.instance.saveToken(
          userId: session.id,
          role: session.role,
          collegeId: session.collegeId,
        );
        // Show welcome notification
        NotificationService.instance.showWelcomeNotification(session.role);
      } catch (e) {
        // Ignore token save errors on login (e.g. web notifications denied)
      }
      return session;
    });
  }

  Future<void> loginWarden({
    required String collegeCode,
    required String wardenCode,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final session = await AuthService.instance.loginWarden(
        collegeCode: collegeCode,
        wardenCode: wardenCode,
        password: password,
      );
      try {
        await NotificationService.instance.saveToken(
          userId: session.id,
          role: session.role,
          collegeId: session.collegeId,
        );
        // Show welcome notification
        NotificationService.instance.showWelcomeNotification(session.role);
      } catch (e) {
        // Ignore token save errors on login (e.g. web notifications denied)
      }
      return session;
    });
  }

  Future<void> loginStudent({
    required String collegeCode,
    required String registerNumber,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final session = await AuthService.instance.loginStudent(
        collegeCode: collegeCode,
        registerNumber: registerNumber,
        password: password,
      );
      try {
        await NotificationService.instance.saveToken(
          userId: session.id,
          role: session.role,
          collegeId: session.collegeId,
        );
        // Show welcome notification
        NotificationService.instance.showWelcomeNotification(session.role);
      } catch (e) {
        // Ignore token save errors on login (e.g. web notifications denied)
      }
      return session;
    });
  }

  Future<void> registerCollege({
    required String collegeName,
    required String collegeCode,
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => AuthService.instance.registerCollege(
          collegeName: collegeName,
          collegeCode: collegeCode,
          email: email,
          password: password,
        ));
  }

  Future<void> logout() async {
    await AuthService.instance.clearSession();
    state = const AsyncData(null);
  }
}
