import 'package:flutter/material.dart';
import 'package:momen_pair_client/features/auth/presentation/login_page.dart';
import 'package:momen_pair_client/features/auth/presentation/session_controller.dart';
import 'package:momen_pair_client/features/auth/presentation/session_scope.dart';
import 'package:momen_pair_client/features/home/presentation/home_shell.dart';

class SessionGate extends StatelessWidget {
  const SessionGate({required this.enableFakeSocialLogin, super.key});

  final bool enableFakeSocialLogin;

  @override
  Widget build(BuildContext context) {
    final controller = SessionScope.of(context);
    return switch (controller.status) {
      SessionStatus.loading => const _LoadingPage(),
      SessionStatus.authenticated => const HomeShell(),
      SessionStatus.unauthenticated => LoginPage(
        enableFakeSocialLogin: enableFakeSocialLogin,
      ),
    };
  }
}

class _LoadingPage extends StatelessWidget {
  const _LoadingPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
