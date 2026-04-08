import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api.dart';
import '../features/pos/billing_service.dart';
import '../config.dart';
import 'auth_provider.dart';

final apiProvider = Provider<Api>((ref) {
  final authState = ref.watch(authProvider);
  return Api(
    baseUrl: kBaseUrl,
    token: authState.token,
  );
});

final billingServiceProvider = Provider<BillingService>((ref) {
  final authState = ref.watch(authProvider);
  return BillingService(
    baseUrl: kBaseUrl,
    authToken: authState.token ?? '',
  );
});
