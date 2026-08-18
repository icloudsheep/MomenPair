enum SocialProvider { wechat, qq }

extension SocialProviderApi on SocialProvider {
  String get apiPath => switch (this) {
        SocialProvider.wechat => 'auth/wechat/mobile',
        SocialProvider.qq => 'auth/qq/mobile',
      };

  String get wireName => name;
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.displayName,
    required this.provider,
  });

  factory AuthUser.fromJson(Map<String, Object?> json) {
    final providerName = json['provider'];
    return AuthUser(
      id: json['id']! as String,
      displayName: json['display_name']! as String,
      provider: SocialProvider.values.byName(providerName! as String),
    );
  }

  final String id;
  final String displayName;
  final SocialProvider provider;
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.user,
  });

  factory AuthSession.fromJson(Map<String, Object?> json) {
    return AuthSession(
      accessToken: json['access_token']! as String,
      refreshToken: json['refresh_token']! as String,
      expiresIn: json['expires_in']! as int,
      user: AuthUser.fromJson(json['user']! as Map<String, Object?>),
    );
  }

  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final AuthUser user;
}
