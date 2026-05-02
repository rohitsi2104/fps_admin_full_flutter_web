import 'dart:async';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api.dart';
import '../services/push_service.dart';
import 'api_provider.dart';

/// Holds the currently selected date range for order filtering.
class DateRangeNotifier extends Notifier<DateTimeRange> {
  @override
  DateTimeRange build() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return DateTimeRange(start: today, end: today);
  }

  void set(DateTimeRange range) => state = range;
}

final ordersDateRangeProvider =
    NotifierProvider<DateRangeNotifier, DateTimeRange>(DateRangeNotifier.new);

final ordersProvider = AsyncNotifierProvider<OrdersNotifier, List<Order>>(
  OrdersNotifier.new,
);

class OrdersNotifier extends AsyncNotifier<List<Order>> {
  Timer? _timer;
  AppLifecycleListener? _lifecycleListener;

  @override
  Future<List<Order>> build() async {
    ref.keepAlive();

    final api = ref.watch(apiProvider);
    final range = ref.watch(ordersDateRangeProvider);

    final pushSub = PushService.onOrderRefresh.listen((_) {
      ref.invalidateSelf();
    });

    // Refresh when the app resumes from background.
    _lifecycleListener = AppLifecycleListener(
      onResume: () => ref.invalidateSelf(),
    );

    // Fallback polling every 30 s (push covers the real-time case).
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      ref.invalidateSelf();
    });

    ref.onDispose(() {
      pushSub.cancel();
      _timer?.cancel();
      _lifecycleListener?.dispose();
      _lifecycleListener = null;
    });

    return api.listOrders(dateFrom: range.start, dateTo: range.end);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}
