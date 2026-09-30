import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors.dart';
import '../../core/result.dart';
import '../remote/auth_remote.dart';
import 'items_repository.dart';

class AuthRepository {
  AuthRepository(this._remote, this._items);
  final AuthRemote _remote;
  final ItemsRepository _items;

  User? get currentUser => _remote.currentUser;
  Stream<AuthState> get changes => _remote.changes;

  Future<Result<bool>> isUsernameAvailable(String username) async {
    try {
      return Ok(await _remote.isUsernameAvailable(username.toLowerCase()));
    } catch (e) {
      return Err(userMessageFor(e));
    }
  }

  /// Returns `true` when signed in right away, `false` when the project
  /// still requires email confirmation.
  Future<Result<bool>> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      final available = await _remote.isUsernameAvailable(username);
      if (!available) {
        return const Err('That username is already taken.', retryable: false);
      }
      final res = await _remote.signUp(
        email: email.trim(),
        password: password,
        username: username.toLowerCase(),
      );
      // Supabase hides "already registered" behind a user with no identities.
      final identities = res.user?.identities;
      if (res.session == null && identities != null && identities.isEmpty) {
        return const Err(Messages.emailTaken, retryable: false);
      }
      return Ok(res.session != null);
    } catch (e) {
      return Err(userMessageFor(e));
    }
  }

  Future<Result<void>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _remote.signIn(email: email.trim(), password: password);
      return const Ok(null);
    } catch (e) {
      return Err(userMessageFor(e));
    }
  }

  Future<String?> username() async {
    final id = currentUser?.id;
    if (id == null) return null;
    try {
      return await _remote.fetchUsername(id);
    } catch (_) {
      return currentUser?.userMetadata?['username'] as String?;
    }
  }

  /// Section 6.5: sign out, then delete everything local.
  Future<void> signOut() async {
    try {
      await _remote.signOut();
    } catch (_) {
      // Even if the server call fails (offline), the local session is gone.
    }
    await _items.wipeLocal();
  }
}
