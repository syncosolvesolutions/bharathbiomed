class Validators {
  Validators._();

  static final RegExp _emailPattern = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
  static final RegExp _namePattern = RegExp(r"^[a-zA-Z][a-zA-Z '.-]*$");

  /// Mirrors the Cloud Function's `USERNAME_PATTERN` (see
  /// functions/src/index.ts) so a bad username is caught client-side before
  /// the round trip.
  static final RegExp _usernamePattern = RegExp(r'^[a-z0-9._-]{3,32}$');

  static String? email(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }
    if (!_emailPattern.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  static String? name(String? value, {String fieldLabel = 'name'}) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Please enter a $fieldLabel';
    }
    if (!_namePattern.hasMatch(trimmed)) {
      return 'Only letters, spaces, apostrophes and hyphens allowed';
    }
    return null;
  }

  static String? required(String? value, {String fieldLabel = 'value'}) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a $fieldLabel';
    }
    return null;
  }

  static String? username(String? value) {
    final trimmed = value?.trim().toLowerCase() ?? '';
    if (trimmed.isEmpty) {
      return 'Please enter a username';
    }
    if (!_usernamePattern.hasMatch(trimmed)) {
      return '3-32 characters: lowercase letters, numbers, dots, underscores or hyphens only';
    }
    return null;
  }

  /// Optional field: `null`/empty passes, but a non-empty value must look
  /// like a real phone number.
  static String? mobileNumber(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    if (!RegExp(r'^\+?[0-9\s-]{7,15}$').hasMatch(trimmed)) {
      return 'Please enter a valid mobile number';
    }
    return null;
  }

  /// The login screen's identifier field accepts either the admin's real
  /// email or an MR's plain username (see core/auth/employee_login.dart), so
  /// it can't require email formatting the way [email] does.
  static String? loginIdentifier(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email or username';
    }
    if (value.trim().contains(' ')) {
      return 'No spaces allowed';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    return null;
  }

  /// For an admin setting an MR's initial password — mirrors the Cloud
  /// Function's minimum length so the check happens before the round trip.
  static String? newPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }
}
