// lib/services/refresh_notifier.dart

import 'package:flutter/foundation.dart';

/// Any screen that changes stock calls: AppRefresh.inventory.notify()
/// InventoryScreen listens and reloads automatically.
class AppRefresh {
  static final inventory = _SimpleNotifier();
}

class _SimpleNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}