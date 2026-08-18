import 'package:flutter/widgets.dart';
import 'package:momen_pair_client/features/families/presentation/family_controller.dart';

class FamilyScope extends InheritedNotifier<FamilyController> {
  const FamilyScope({
    required FamilyController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static FamilyController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<FamilyScope>();
    assert(scope != null, 'FamilyScope is missing above this context.');
    return scope!.notifier!;
  }
}
