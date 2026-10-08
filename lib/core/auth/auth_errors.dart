/// User-facing copy for authentication problems.
///
/// Every message says what happened and how to fix it, and never exposes raw
/// Firebase codes or stack traces.
abstract final class AuthErrors {
  static const String generic =
      'Something went wrong on our side. Please try again in a moment.';

  static String forAuthCode(String code) => switch (code) {
    'invalid-email' =>
      'That email address doesn’t look right. Check for typos and try again.',
    'email-already-in-use' =>
      'An account already uses this email. Sign in instead, or reset your '
          'password if you’ve forgotten it.',
    'weak-password' =>
      'That password is too easy to guess. Use at least 8 characters with '
          'letters and numbers.',
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' ||
    'INVALID_LOGIN_CREDENTIALS' =>
      'Email or password is incorrect. Check both and try again, or reset '
          'your password.',
    'too-many-requests' =>
      'Too many attempts from this device. For your security, wait a few '
          'minutes before trying again.',
    'network-request-failed' =>
      'You appear to be offline. Check your internet connection and try '
          'again.',
    'user-disabled' =>
      'This account has been disabled. Contact SkillNova support for help.',
    'account-exists-with-different-credential' =>
      'This email is registered with a different sign-in method. Try '
          'signing in with email and password.',
    'operation-not-allowed' =>
      'This sign-in method isn’t enabled right now. Please use another '
          'option.',
    'google-token-missing' =>
      'Google didn’t confirm your sign-in. Please try again.',
    'user-token-expired' ||
    'requires-recent-login' => 'Your session expired. Please sign in again.',
    _ => generic,
  };

  static String forFirestoreCode(String code) => switch (code) {
    'unavailable' || 'deadline-exceeded' =>
      'We couldn’t reach SkillNova. Check your connection and try again.',
    'permission-denied' =>
      'We couldn’t access your account data. Please sign in again.',
    _ => generic,
  };
}

/// Shared form validators. Messages explain how to fix the input.
abstract final class AuthValidators {
  static final RegExp _email = RegExp(
    r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$',
  );

  static String? name(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter your full name.';
    if (text.length < 2) return 'Name should have at least 2 characters.';
    if (text.length > 60) return 'Keep your name under 60 characters.';
    return null;
  }

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter your email address.';
    if (!_email.hasMatch(text)) {
      return 'Enter a valid email, like name@example.com.';
    }
    return null;
  }

  static String? loginPassword(String? value) {
    if ((value ?? '').isEmpty) return 'Enter your password.';
    return null;
  }

  static String? newPassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Create a password.';
    if (text.length < 8) return 'Use at least 8 characters.';
    if (!RegExp(r'[A-Za-z]').hasMatch(text) || !RegExp(r'\d').hasMatch(text)) {
      return 'Include at least one letter and one number.';
    }
    return null;
  }
}
