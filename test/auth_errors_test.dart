import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:skill_link/core/auth/auth_errors.dart';
import 'package:skill_link/screens/auth_screens/auth_screen.dart';

void main() {
  group('Firebase Auth errors', () {
    test('wrong credentials never reveal which part was wrong', () {
      for (final code in [
        'invalid-credential',
        'wrong-password',
        'user-not-found',
        'INVALID_LOGIN_CREDENTIALS',
      ]) {
        expect(
          AuthErrors.forAuthCode(code),
          startsWith('Invalid email or password'),
        );
      }
    });

    test('registration problems are specific', () {
      expect(
        AuthErrors.forAuthCode('email-already-in-use'),
        startsWith('This email is already registered'),
      );
      expect(AuthErrors.forAuthCode('invalid-email'), contains('email'));
      expect(AuthErrors.forAuthCode('weak-password'), contains('password'));
    });

    test('offline and project setup problems get their own messages', () {
      expect(
        AuthErrors.forAuthCode('network-request-failed'),
        AuthErrors.offline,
      );
      for (final code in [
        'configuration-not-found',
        'app-not-authorized',
        'invalid-api-key',
        'api-key-not-valid',
      ]) {
        expect(AuthErrors.forAuthCode(code), AuthErrors.serviceUnavailable);
      }
      expect(AuthErrors.forAuthCode('internal-error'), AuthErrors.authFailed);
      expect(AuthErrors.forAuthCode('something-new'), AuthErrors.generic);
    });

    test('no message leaks a raw Firebase code', () {
      for (final code in [
        'configuration-not-found',
        'internal-error',
        'invalid-credential',
        'operation-not-allowed',
        'whatever',
      ]) {
        final message = AuthErrors.forAuthCode(code);
        expect(message, isNot(contains(code)));
        expect(message, isNot(contains('firebase')));
      }
    });
  });

  group('backend errors', () {
    test('a missing or failing initializeAccount function is explained', () {
      for (final code in ['not-found', 'internal', 'unimplemented']) {
        expect(
          AuthErrors.forFunctionsCode(code),
          AuthErrors.serviceUnavailable,
        );
      }
      expect(AuthErrors.forFunctionsCode('unavailable'), AuthErrors.offline);
      expect(
        AuthErrors.forFunctionsCode('deadline-exceeded'),
        AuthErrors.offline,
      );
      expect(
        AuthErrors.forFunctionsCode('unauthenticated'),
        contains('sign in'),
      );
    });

    test('Firestore setup problems are not shown as a generic error', () {
      expect(AuthErrors.forFirestoreCode('unavailable'), AuthErrors.offline);
      expect(
        AuthErrors.forFirestoreCode('not-found'),
        AuthErrors.serviceUnavailable,
      );
    });
  });

  group('Google Sign-In', () {
    test('cancel is acknowledged, configuration problems are explained', () {
      expect(
        googleSignInMessage(GoogleSignInExceptionCode.canceled),
        'Google Sign-In was cancelled.',
      );
      expect(
        googleSignInMessage(GoogleSignInExceptionCode.clientConfigurationError),
        AuthErrors.googleNotConfigured,
      );
      expect(
        googleSignInMessage(
          GoogleSignInExceptionCode.providerConfigurationError,
        ),
        AuthErrors.googleNotConfigured,
      );
      expect(
        googleSignInMessage(GoogleSignInExceptionCode.unknownError),
        AuthErrors.authFailed,
      );
    });
  });
}
