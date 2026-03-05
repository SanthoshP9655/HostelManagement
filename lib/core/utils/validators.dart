// lib/core/utils/validators.dart
class Validators {
  Validators._();

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final regex = RegExp(r'^[\w.-]+@[\w.-]+\.\w{2,}$');
    if (!regex.hasMatch(value.trim())) return 'Enter a valid email';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  static String? required(String? value, {String field = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$field is required';
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return null; // optional
    if (value.trim().length < 10) return 'Enter a valid phone number';
    return null;
  }

  static String? collegeCode(String? value) {
    if (value == null || value.trim().isEmpty) return 'College code is required';
    if (value.trim().length < 3) return 'College code must be at least 3 characters';
    return null;
  }
}
