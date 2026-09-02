import 'package:flutter/widgets.dart';

class WorkerNavigationScope extends InheritedWidget {
  const WorkerNavigationScope({super.key, required super.child});

  static bool isEmbedded(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WorkerNavigationScope>() !=
      null;

  @override
  bool updateShouldNotify(WorkerNavigationScope oldWidget) => false;
}
