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

  /// Username sign-in through the `login-with-username` Edge Function,
  /// which looks up the email on the server and returns a session.
  /// Throws [AuthException] with code `invalid_credentials`,
  /// `email_not_confirmed` or `over_request_rate_limit`.
  Future<void> signInWithUsername({
    required String username,
    required String password,
  }) async {
    final Map<String, dynamic> body;
    try {
      final res = await _client.functions
          .invoke(
            'login-with-username',
            body: {'username': username, 'password': password},
          )
          .timeout(_timeout);
      body = Map<String, dynamic>.from(res.data as Map);
    } on FunctionException catch (e) {
      final details = e.details;
      final code = details is Map ? details['error'] as String? : null;
      throw AuthException(
        code ?? 'invalid_credentials',
        statusCode: '${e.status}',
        code: switch (code) {
          'email_not_confirmed' => 'email_not_confirmed',
          'rate_limited' => 'over_request_rate_limit',
          _ => 'invalid_credentials',
        },
      );
    }
    await _auth.setSession(body['refresh_token'] as String).timeout(_timeout);
  }

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
