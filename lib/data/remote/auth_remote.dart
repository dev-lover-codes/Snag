import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRemote {
  AuthRemote(this._client);
  final SupabaseClient _client;

  static const _timeout = Duration(seconds: 20);

  GoTrueClient get _auth => _client.auth;

  User? get currentUser => _auth.currentUser;
  Stream<AuthState> get changes => _auth.onAuthStateChange;

  Future<bool> isUsernameAvailable(String username) async {
    final result = await _client
        .rpc('is_username_available', params: {'p_username': username})
        .timeout(_timeout);
    return result == true;
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String username,
  }) => _auth
      .signUp(email: email, password: password, data: {'username': username})
      .timeout(_timeout);

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) => _auth
      .signInWithPassword(email: email, password: password)
      .timeout(_timeout);

  Future<void> signOut() => _auth.signOut();

  Future<String?> fetchUsername(String userId) async {
    final row = await _client
        .from('profiles')
        .select('username')
        .eq('id', userId)
        .maybeSingle()
        .timeout(_timeout);
    return row?['username'] as String?;
  }
}
