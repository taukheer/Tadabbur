import 'dart:convert';

/// User profile returned by the Quran Foundation User API.
///
/// Stored so we can visibly surface the connection — "Signed in as
/// [name] · quran.com" — rather than treating QF OAuth as an invisible
/// token handshake. Making the identity visible reframes the app from
/// "uses QF auth" to "a window into your quran.com life."
///
/// All fields are nullable because QF's response shape isn't
/// uniformly documented across endpoints; we take whatever it gives
/// us and show what we can. Absence of a name is not fatal — we just
/// don't show the identity row.
class QfUserProfile {
  final String? id;
  final String? name;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? avatarUrl;
  final String? username;

  const QfUserProfile({
    this.id,
    this.name,
    this.firstName,
    this.lastName,
    this.email,
    this.avatarUrl,
    this.username,
  });

  /// Best-effort display name: full name if present, else first/last
  /// composed, else username, else email local part.
  String? get displayName {
    if (name != null && name!.trim().isNotEmpty) return name!.trim();
    final composed = [firstName, lastName]
        .where((p) => p != null && p.trim().isNotEmpty)
        .join(' ')
        .trim();
    if (composed.isNotEmpty) return composed;
    if (username != null && username!.trim().isNotEmpty) return username;
    if (email != null && email!.contains('@')) {
      return email!.split('@').first;
    }
    return null;
  }

  /// Probe several plausible field names — QF's API surface varies
  /// between content and user endpoints and between response shapes,
  /// so we don't assume a single schema.
  factory QfUserProfile.fromJson(Map<String, dynamic> raw) {
    // Some endpoints wrap the profile under `user` or `data`.
    final body = (raw['user'] ?? raw['data'] ?? raw) as Map;
    final m = body.cast<String, dynamic>();
    String? pick(List<String> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      return null;
    }

    return QfUserProfile(
      id: pick(['id', 'userId', 'user_id']),
      name: pick(['name', 'displayName', 'display_name', 'full_name']),
      firstName: pick(['firstName', 'first_name', 'given_name']),
      lastName: pick(['lastName', 'last_name', 'family_name']),
      email: pick(['email', 'email_address']),
      avatarUrl: pick(['avatar', 'avatarUrl', 'avatar_url', 'picture', 'photoUrl', 'photo_url']),
      username: pick(['username', 'handle']),
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (name != null) 'name': name,
        if (firstName != null) 'firstName': firstName,
        if (lastName != null) 'lastName': lastName,
        if (email != null) 'email': email,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
        if (username != null) 'username': username,
      };

  String encode() => jsonEncode(toJson());

  static QfUserProfile? tryDecode(String? encoded) {
    if (encoded == null || encoded.isEmpty) return null;
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is Map<String, dynamic>) return QfUserProfile.fromJson(decoded);
    } catch (_) {}
    return null;
  }
}
