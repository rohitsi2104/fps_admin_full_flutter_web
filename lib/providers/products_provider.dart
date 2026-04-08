import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api.dart';
import 'api_provider.dart';

final productsProvider = AsyncNotifierProvider<ProductsNotifier, List<dynamic>>(
  ProductsNotifier.new,
);

class ProductsNotifier extends AsyncNotifier<List<dynamic>> {
  @override
  Future<List<dynamic>> build() async {
    final api = ref.watch(apiProvider);
    // Fetch products. This is typically not polled continuously 
    // unless necessary, but we'll fetch once per mount
    final products = await api.searchProducts('');
    return products;
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}
