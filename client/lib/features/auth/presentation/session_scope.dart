import 'package:flutter/widgets.dart';
import 'package:momen_pair_client/features/auth/presentation/session_controller.dart';

class SessionScope extends InheritedNotifier<SessionController> {
  const SessionScope({
    required SessionController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static SessionController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SessionScope>();
    assert(scope != null, 'SessionScope is missing above this context.');
    return scope!.notifier!;
  }
}
