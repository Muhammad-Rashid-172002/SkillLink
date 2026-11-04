/// User-facing copy for authentication problems.
///
/// Every message says what happened and how to fix it, and never exposes raw
/// Firebase codes or stack traces.
abstract final class AuthErrors {
  static const String generic = 'Something went wrong. Please try again.';

  static const String authFailed = 'Authentication failed. Please try again.';

  static const String offline =
      'Please check your internet connection and try again.';

  /// Shown when the sign-in backend (Cloud Functions / Auth configuration)
  /// is unreachable or not set up for this Firebase project.
  static const String serviceUnavailable =
      'Sign-in is temporarily unavailable. Please try again in a few '
      'minutes.';

  static const String googleCancelled = 'Google Sign-In was cancelled.';

  static const String googleNotConfigured =
      'Google Sign-In isn’t available in this version of the app yet. '
      'Please sign in with your email and password.';

  static String forAuthCode(String code) => switch (code) {
    'invalid-email' =>
      'That email address doesn’t look right. Check for typos and try again.',
    'email-already-in-use' =>
      'This email is already registered. Sign in instead, or reset your '
          'password if you’ve forgotten it.',
    'weak-password' =>
      'That password is too easy to guess. Use at least 8 characters with '
          'letters and numbers.',
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' ||
    'INVALID_LOGIN_CREDENTIALS' =>
      'Invalid email or password. Check both and try again, or reset your '
          'password.',
    'too-many-requests' =>
      'Too many attempts from this device. For your security, wait a few '
          'minutes before trying again.',
    'network-request-failed' || 'unavailable' => offline,
    'user-disabled' =>
      'This account has been disabled. Contact SkillNova support for help.',
    'account-exists-with-different-credential' =>
      'This email is registered with a different sign-in method. Try '
          'signing in with email and password.',
    'operation-not-allowed' =>
      'This sign-in method isn’t enabled right now. Please use another '
          'option.',
    // Firebase project / app configuration problems (provider not enabled,
    // API key or app not authorised). Not the person's fault; logged in
    // debug builds by the caller.
    'configuration-not-found' ||
    'app-not-authorized' ||
    'invalid-api-key' ||
    'api-key-not-valid' ||
    'app-not-verified' => serviceUnavailable,
    'channel-error' => 'Enter your email and password to continue.',
    'internal-error' || 'unknown' || 'user-creation-failed' => authFailed,
    'google-token-missing' =>
      'Google didn’t confirm your sign-in. Please try again.',
    'user-token-expired' ||
    'requires-recent-login' => 'Your session expired. Please sign in again.',
    _ => generic,
  };

  static String forFirestoreCode(String code) => switch (code) {
    'unavailable' || 'deadline-exceeded' => offline,
    'permission-denied' =>
      'We couldn’t access your account data. Please sign in again.',
    // Database missing or misconfigured for this Firebase project.
    'not-found' || 'failed-precondition' => serviceUnavailable,
    _ => generic,
  };

  /// Callable Cloud Functions (`initializeAccount`, emails).
  static String forFunctionsCode(String code) => switch (code) {
    'unavailable' || 'deadline-exceeded' => offline,
    'unauthenticated' => 'Please sign in again to continue.',
    // The function is not deployed to this project, or crashed.
    'not-found' || 'internal' || 'unimplemented' => serviceUnavailable,
    'permission-denied' =>
      'Your account can’t be set up automatically. Please contact '
          'SkillNova support.',
    _ => authFailed,
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
