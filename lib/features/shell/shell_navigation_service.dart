import 'package:flutter/foundation.dart';

class ShellNavigationService {
  ShellNavigationService._();

  static final ValueNotifier<int?> tabRequests = ValueNotifier<int?>(null);

  static void openTab(int index) {
    tabRequests.value = index;
  }

  static void clear() {
    tabRequests.value = null;
  }
}