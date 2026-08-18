import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momen_pair_client/app/app.dart';
import 'package:momen_pair_client/features/auth/domain/auth_models.dart';
import 'package:momen_pair_client/features/auth/domain/auth_repository.dart';
import 'package:momen_pair_client/features/auth/presentation/session_controller.dart';

void main() {
  testWidgets('shows the five primary destinations', (tester) async {
    final controller = SessionController(
      repository: _FakeAuthRepository(),
      initialSession: _session,
    );
    await tester.pumpWidget(
      MomenPairApp(
        sessionController: controller,
        enableFakeSocialLogin: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byIcon(Icons.auto_stories), findsWidgets);
    expect(find.byIcon(Icons.campaign_outlined), findsOneWidget);
    expect(find.byIcon(Icons.hourglass_empty), findsOneWidget);
    expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
  });

  testWidgets('shows independent WeChat and QQ login choices', (tester) async {
    final controller = SessionController(repository: _FakeAuthRepository());
    await controller.restore();
    await tester.pumpWidget(
      MomenPairApp(
        sessionController: controller,
        enableFakeSocialLogin: true,
        locale: const Locale('zh'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('使用微信登录'), findsOneWidget);
    expect(find.text('使用 QQ 登录'), findsOneWidget);
    expect(find.textContaining('两个独立账号'), findsOneWidget);
  });
}

const _user = AuthUser(
  id: 'user-id',
  displayName: '本地用户',
  provider: SocialProvider.wechat,
);
const _session = AuthSession(
  accessToken: 'access-token',
  refreshToken: 'refresh-token',
  expiresIn: 900,
  user: _user,
);

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<AuthSession> loginWithCode(
      SocialProvider provider, String code) async {
    return _session;
  }

  @override
  Future<void> logout() async {}

  @override
  Future<AuthSession?> restore() async => null;
}
