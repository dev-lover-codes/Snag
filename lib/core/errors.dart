import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Thrown by repositories when a write is attempted without internet.
class OfflineException implements Exception {
  const OfflineException();
  @override
  String toString() => Messages.offlineWrite;
}

/// Thrown when an item is missing or belongs to someone else.
/// Both cases must look identical to the user.
class ItemGoneException implements Exception {
  const ItemGoneException();
  @override
  String toString() => Messages.itemGone;
}

/// Thrown when user input fails validation (section 9 of the plan).
class ValidationException implements Exception {
  const ValidationException(this.message);
  final String message;
  @override
  String toString() => message;
}

class Messages {
  const Messages._();

  static const itemGone = 'This item no longer exists.';
  static const offlineWrite = "You're offline — your draft is saved.";
  static const wrongCredentials = 'Wrong email, username or password.';
  static const emailTaken = 'An account with this email already exists.';
  static const serverUnreachable = "Couldn't reach Snag's server.";
  static const fileTooLarge = 'File must be 10 MB or smaller.';
  static const pdfTooLarge = 'PDF must be 10 MB or smaller';
  static const emailNotConfirmed =
      'Please confirm your email address first, then sign in.';
  static const generic = 'Something went wrong. Please try again.';
}

/// Maps Supabase / network errors to a short message for the user.
String userMessageFor(Object error) {
  if (error is OfflineException ||
      error is ItemGoneException ||
      error is ValidationException) {
    return error.toString();
  }
  if (error is AuthException) {
    final msg = error.message.toLowerCase();
    final code = error.code ?? '';
    if (code == 'invalid_credentials' ||
        msg.contains('invalid login credentials')) {
      return Messages.wrongCredentials;
    }
    if (code == 'user_already_exists' ||
        code == 'email_exists' ||
        msg.contains('already registered')) {
      return Messages.emailTaken;
    }
    if (code == 'email_not_confirmed' || msg.contains('email not confirmed')) {
      return Messages.emailNotConfirmed;
    }
    if (code == 'weak_password') {
      return 'Password is too weak. Use at least 8 characters.';
    }
    if (code == 'over_email_send_rate_limit' ||
        code == 'over_request_rate_limit') {
      return 'Too many attempts. Please wait a minute and try again.';
    }
    if (error is AuthRetryableFetchException) return Messages.serverUnreachable;
    return error.message;
  }
  if (error is StorageException) {
    final status = error.statusCode ?? '';
    if (status == '413' || error.message.toLowerCase().contains('size')) {
      return Messages.fileTooLarge;
    }
    return Messages.serverUnreachable;
  }
  if (error is PostgrestException) {
    // Unique username violation raised by the sign-up trigger.
    if (error.code == '23505') return 'That username is already taken.';
    if (error.code == '23514') return 'Some fields are too long or invalid.';
    return Messages.serverUnreachable;
  }
  if (error is SocketException ||
      error is TimeoutException ||
      error is HttpException ||
      error.toString().contains('ClientException')) {
    return Messages.serverUnreachable;
  }
  return Messages.generic;
}
