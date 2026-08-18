import 'package:flutter/widgets.dart';
import 'package:momen_pair_client/features/logs/presentation/log_controller.dart';

class LogScope extends InheritedNotifier<LogController> {
  const LogScope({
    required LogController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static LogController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LogScope>();
    assert(scope != null, 'LogScope is missing above this context.');
    return scope!.notifier!;
  }
}
