final usernamePattern = RegExp(r'^[a-z0-9_]{3,20}$');
final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

String? validateUsername(String? value) {
  final v = (value ?? '').trim().toLowerCase();
  if (v.isEmpty) return 'Choose a username';
  if (!usernamePattern.hasMatch(v)) {
    return '3–20 characters: a–z, 0–9 or _';
  }
  return null;
}

String? validateEmail(String? value) {
  final v = (value ?? '').trim();
  if (v.isEmpty) return 'Enter your email';
  if (!_emailPattern.hasMatch(v)) return 'Enter a valid email address';
  return null;
}

String? validatePassword(String? value) {
  final v = value ?? '';
  if (v.isEmpty) return 'Enter your password';
  if (v.length < 8) return 'At least 8 characters';
  return null;
}
