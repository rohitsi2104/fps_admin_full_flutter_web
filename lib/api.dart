import 'package:dio/dio.dart';

double _toDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0.0;
  return 0.0;
}

class Api {
  final Dio _dio;
  Api({required String baseUrl, required String? token})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl, // e.g. http://127.0.0.1:8000/api/
          headers: {
            if (token != null) 'Authorization': 'Token $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ));

  void setToken(String? token) {
    if (token == null) {
      _dio.options.headers.remove('Authorization');
    } else {
      _dio.options.headers['Authorization'] = 'Token $token';
    }
  }

  /// Login WITHOUT changing the backend:
  /// - clears any Authorization header for this call
  /// - sends to `users/login/` (with trailing slash)
  /// - tries {phone, password} first, then {username, password} as fallback
  /// - surfaces clear error messages
  Future<String> login(
      {required String phone, required String password}) async {
    final payloads = [
      {'phone': phone, 'password': password},
      {
        'username': phone,
        'password': password
      }, // fallback if server expects "username"
    ];

    DioException? lastErr;

    for (final data in payloads) {
      try {
        final res = await _dio.post(
          'users/login/', // keep trailing slash
          data: data,
          options: Options(headers: {
            // ensure no token is sent during login
            'Authorization': null,
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          }),
        );
        final body = res.data;
        if (body is Map && body['token'] is String) {
          final t = body['token'] as String;
          setToken(t);
          return t;
        }
        throw Exception('Invalid login response: $body');
      } on DioException catch (e) {
        lastErr = e;
        final code = e.response?.statusCode ?? 0;
        // Only try the fallback payload if this was a 401 (bad creds shape)
        if (code != 401) break;
      }
    }

    if (lastErr != null) {
      final code = lastErr.response?.statusCode;
      final msg = lastErr.response?.data is Map
          ? ((lastErr.response!.data['detail'] ??
                  lastErr.response!.data['error'] ??
                  lastErr.message)
              .toString())
          : lastErr.message;
      throw Exception('Login failed (${code ?? 'no code'}): $msg');
    }
    throw Exception('Login failed for unknown reasons');
  }

  // ------------ ADMIN ORDERS API ------------
  /// List all orders (admin). Optional filters: status, since
  Future<List<Order>> listOrders({String? status, DateTime? since}) async {
    final qp = <String, dynamic>{};
    if (status != null) qp['status'] = status;
    if (since != null) qp['since'] = since.toUtc().toIso8601String();

    final res = await _dio.get('admin/orders/', queryParameters: qp);
    final data = res.data;
    if (data is List) {
      return data
          .map((e) => Order.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Invalid orders response');
  }

  /// Change status (admin): PENDING | PAID | SHIPPED | COMPLETED | CANCELLED
  Future<Order> setStatus(int orderId, String status) async {
    final res = await _dio
        .patch('admin/orders/$orderId/status/', data: {'status': status});
    return Order.fromJson(res.data as Map<String, dynamic>);
  }

  /// Cancel (admin) if pending
  Future<Order> cancel(int orderId) async {
    final res = await _dio.post('admin/orders/$orderId/cancel/');
    return Order.fromJson(res.data as Map<String, dynamic>);
  }

  /// Retrieve one order (admin)
  Future<Order> getOrder(int orderId) async {
    final res = await _dio.get('admin/orders/$orderId/');
    return Order.fromJson(res.data as Map<String, dynamic>);
  }
}

// ----------------- MODELS -----------------

class Order {
  final int id;
  final String status;
  final String statusDisplay;
  final String shippingName;
  final String shippingPhone;
  final String addressLine1;
  final String addressLine2;
  final String city;
  final String state;
  final String pincode;
  final double totalAmount;
  final DateTime createdAt;
  final List<OrderItem> items;

  Order({
    required this.id,
    required this.status,
    required this.statusDisplay,
    required this.shippingName,
    required this.shippingPhone,
    required this.addressLine1,
    required this.addressLine2,
    required this.city,
    required this.state,
    required this.pincode,
    required this.totalAmount,
    required this.createdAt,
    required this.items,
  });

  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id: j['id'] as int,
        status: j['status'] as String,
        statusDisplay: j['status_display'] as String? ?? j['status'] as String,
        shippingName: j['shipping_name'] ?? '',
        shippingPhone: j['shipping_phone'] ?? '',
        addressLine1: j['address_line1'] ?? '',
        addressLine2: j['address_line2'] ?? '',
        city: j['city'] ?? '',
        state: j['state'] ?? '',
        pincode: j['pincode'] ?? '',
        totalAmount: _toDouble(j['total_amount']),
        createdAt: DateTime.parse(j['created_at'] as String),
        items: (j['items'] as List? ?? [])
            .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class OrderItem {
  final int id;
  final int productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
  final String? imageUrl;

  OrderItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    required this.imageUrl,
  });

  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
        id: j['id'] as int,
        productId: j['product_id'] as int,
        productName: j['product_name'] as String? ?? '',
        quantity: j['quantity'] as int? ?? 0,
        unitPrice: _toDouble(j['unit_price']),
        lineTotal: _toDouble(j['line_total']),
        imageUrl: j['image_url'] as String?,
      );
}
