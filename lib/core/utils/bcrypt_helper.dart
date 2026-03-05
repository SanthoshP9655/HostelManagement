// lib/core/utils/bcrypt_helper.dart
import 'package:bcrypt/bcrypt.dart';

class BcryptHelper {
  BcryptHelper._();

  static String hashPassword(String password) {
    final salt = BCrypt.gensalt(logRounds: 10);
    return BCrypt.hashpw(password, salt);
  }

  static bool verifyPassword(String password, String hash) {
    try {
      return BCrypt.checkpw(password, hash);
    } catch (_) {
      return false;
    }
  }
}
