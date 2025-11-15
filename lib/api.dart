// // import 'package:dio/dio.dart';

// // double _toDouble(dynamic v) {
// //   if (v == null) return 0.0;
// //   if (v is num) return v.toDouble();
// //   if (v is String) return double.tryParse(v) ?? 0.0;
// //   return 0.0;
// // }

// // class Api {
// //   final Dio _dio;
// //   Api({required String baseUrl, required String? token})
// //       : _dio = Dio(BaseOptions(
// //           baseUrl: baseUrl, // e.g. http://127.0.0.1:8000/api/
// //           headers: {
// //             if (token != null) 'Authorization': 'Token $token',
// //             'Content-Type': 'application/json',
// //             'Accept': 'application/json',
// //           },
// //           connectTimeout: const Duration(seconds: 10),
// //           receiveTimeout: const Duration(seconds: 20),
// //         ));

// //   void setToken(String? token) {
// //     if (token == null) {
// //       _dio.options.headers.remove('Authorization');
// //     } else {
// //       _dio.options.headers['Authorization'] = 'Token $token';
// //     }
// //   }

// //   Future<String> login(
// //       {required String phone, required String password}) async {
// //     final payloads = [
// //       {'phone': phone, 'password': password},
// //       {'username': phone, 'password': password},
// //     ];

// //     DioException? lastErr;

// //     for (final data in payloads) {
// //       try {
// //         final res = await _dio.post(
// //           'users/login/',
// //           data: data,
// //           options: Options(headers: {
// //             'Authorization': null,
// //             'Content-Type': 'application/json',
// //             'Accept': 'application/json',
// //           }),
// //         );
// //         final body = res.data;
// //         if (body is Map && body['token'] is String) {
// //           final t = body['token'] as String;
// //           setToken(t);
// //           return t;
// //         }
// //         throw Exception('Invalid login response: $body');
// //       } on DioException catch (e) {
// //         lastErr = e;
// //         if ((e.response?.statusCode ?? 0) != 401) break;
// //       }
// //     }

// //     if (lastErr != null) {
// //       final code = lastErr.response?.statusCode;
// //       final msg = lastErr.response?.data is Map
// //           ? ((lastErr.response!.data['detail'] ??
// //                   lastErr.response!.data['error'] ??
// //                   lastErr.message)
// //               .toString())
// //           : lastErr.message;
// //       throw Exception('Login failed (${code ?? 'no code'}): $msg');
// //     }
// //     throw Exception('Login failed for unknown reasons');
// //   }

// //   // ------------ ADMIN ORDERS API ------------
// //   Future<List<Order>> listOrders({String? status, DateTime? since}) async {
// //     final qp = <String, dynamic>{'source': 'ONLINE'};
// //     if (status != null) qp['status'] = status;
// //     if (since != null) qp['since'] = since.toUtc().toIso8601String();

// //     final res = await _dio.get('admin/orders/', queryParameters: qp);
// //     final data = res.data;
// //     if (data is List) {
// //       return data
// //           .map((e) => Order.fromJson(e as Map<String, dynamic>))
// //           .toList();
// //     }
// //     throw Exception('Invalid orders response');
// //   }

// //   Future<Order> setStatus(int orderId, String status) async {
// //     final res = await _dio
// //         .patch('admin/orders/$orderId/status/', data: {'status': status});
// //     return Order.fromJson(res.data as Map<String, dynamic>);
// //   }

// //   Future<Order> cancel(int orderId) async {
// //     final res = await _dio.post('admin/orders/$orderId/cancel/');
// //     return Order.fromJson(res.data as Map<String, dynamic>);
// //   }

// //   Future<Order> getOrder(int orderId) async {
// //     final res = await _dio.get('admin/orders/$orderId/');
// //     return Order.fromJson(res.data as Map<String, dynamic>);
// //   }
// // }

// // // ----------------- MODELS -----------------

// // class Order {
// //   final int id;
// //   final String status;
// //   final String statusDisplay;
// //   final String shippingName;
// //   final String shippingPhone;
// //   final String addressLine1;
// //   final String addressLine2;
// //   final String city;
// //   final String state;
// //   final String pincode;
// //   final double totalAmount;
// //   final DateTime createdAt;
// //   final List<OrderItem> items;

// //   Order({
// //     required this.id,
// //     required this.status,
// //     required this.statusDisplay,
// //     required this.shippingName,
// //     required this.shippingPhone,
// //     required this.addressLine1,
// //     required this.addressLine2,
// //     required this.city,
// //     required this.state,
// //     required this.pincode,
// //     required this.totalAmount,
// //     required this.createdAt,
// //     required this.items,
// //   });

// //   factory Order.fromJson(Map<String, dynamic> j) => Order(
// //         id: j['id'] as int,
// //         status: j['status'] as String,
// //         statusDisplay: j['status_display'] as String? ?? j['status'] as String,
// //         shippingName: j['shipping_name'] ?? '',
// //         shippingPhone: j['shipping_phone'] ?? '',
// //         addressLine1: j['address_line1'] ?? '',
// //         addressLine2: j['address_line2'] ?? '',
// //         city: j['city'] ?? '',
// //         state: j['state'] ?? '',
// //         pincode: j['pincode'] ?? '',
// //         totalAmount: _toDouble(j['total_amount']),
// //         createdAt: DateTime.parse(j['created_at'] as String),
// //         items: (j['items'] as List? ?? [])
// //             .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
// //             .toList(),
// //       );
// // }

// // class OrderItem {
// //   final int id;
// //   final int productId;
// //   final String productName;
// //   final int quantity;
// //   final double unitPrice;
// //   final double lineTotal;
// //   final String? imageUrl;

// //   OrderItem({
// //     required this.id,
// //     required this.productId,
// //     required this.productName,
// //     required this.quantity,
// //     required this.unitPrice,
// //     required this.lineTotal,
// //     required this.imageUrl,
// //   });

// //   factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
// //         id: j['id'] as int,
// //         productId: j['product_id'] as int,
// //         productName: j['product_name'] as String? ?? '',
// //         quantity: j['quantity'] as int? ?? 0,
// //         unitPrice: _toDouble(j['unit_price']),
// //         lineTotal: _toDouble(j['line_total']),
// //         imageUrl: j['image_url'] as String?,
// //       );
// // }

// // lib/api.dart
// import 'dart:typed_data';
// import 'package:dio/dio.dart';

// double _toDouble(dynamic v) {
//   if (v == null) return 0.0;
//   if (v is num) return v.toDouble();
//   if (v is String) return double.tryParse(v) ?? 0.0;
//   return 0.0;
// }

// class Api {
//   final Dio _dio;

//   Api({required String baseUrl, required String? token})
//       : _dio = Dio(
//           BaseOptions(
//             baseUrl: baseUrl, // e.g. http://127.0.0.1:8000/api/
//             headers: {
//               if (token != null) 'Authorization': 'Token $token',
//               'Content-Type': 'application/json',
//               'Accept': 'application/json',
//             },
//             connectTimeout: const Duration(seconds: 10),
//             receiveTimeout: const Duration(seconds: 20),
//           ),
//         );

//   void setToken(String? token) {
//     if (token == null) {
//       _dio.options.headers.remove('Authorization');
//     } else {
//       _dio.options.headers['Authorization'] = 'Token $token';
//     }
//   }

//   // ---------------- AUTH ----------------

//   Future<String> login(
//       {required String phone, required String password}) async {
//     final payloads = [
//       {'phone': phone, 'password': password},
//       {'username': phone, 'password': password}, // fallback
//     ];

//     DioException? lastErr;

//     for (final data in payloads) {
//       try {
//         final res = await _dio.post(
//           'users/login/',
//           data: data,
//           options: Options(headers: {
//             'Authorization': null, // ensure no token on login
//             'Content-Type': 'application/json',
//             'Accept': 'application/json',
//           }),
//         );
//         final body = res.data;
//         if (body is Map && body['token'] is String) {
//           final t = body['token'] as String;
//           setToken(t);
//           return t;
//         }
//         throw Exception('Invalid login response: $body');
//       } on DioException catch (e) {
//         lastErr = e;
//         if ((e.response?.statusCode ?? 0) != 401) break;
//       }
//     }

//     if (lastErr != null) {
//       final code = lastErr.response?.statusCode;
//       final msg = lastErr.response?.data is Map
//           ? ((lastErr.response!.data['detail'] ??
//                   lastErr.response!.data['error'] ??
//                   lastErr.message)
//               .toString())
//           : lastErr.message;
//       throw Exception('Login failed (${code ?? 'no code'}): $msg');
//     }
//     throw Exception('Login failed for unknown reasons');
//   }

//   // ---------------- ADMIN ORDERS ----------------

//   Future<List<Order>> listOrders({String? status, DateTime? since}) async {
//     final qp = <String, dynamic>{'source': 'ONLINE'};
//     if (status != null) qp['status'] = status;
//     if (since != null) qp['since'] = since.toUtc().toIso8601String();

//     final res = await _dio.get('admin/orders/', queryParameters: qp);
//     final data = res.data;
//     if (data is List) {
//       return data
//           .map((e) => Order.fromJson(e as Map<String, dynamic>))
//           .toList();
//     }
//     throw Exception('Invalid orders response');
//   }

//   Future<Order> setStatus(int orderId, String status) async {
//     final res = await _dio
//         .patch('admin/orders/$orderId/status/', data: {'status': status});
//     return Order.fromJson(res.data as Map<String, dynamic>);
//   }

//   Future<Order> cancel(int orderId) async {
//     final res = await _dio.post('admin/orders/$orderId/cancel/');
//     return Order.fromJson(res.data as Map<String, dynamic>);
//   }

//   Future<Order> getOrder(int orderId) async {
//     final res = await _dio.get('admin/orders/$orderId/');
//     return Order.fromJson(res.data as Map<String, dynamic>);
//   }

//   // ---------------- STOCK MANAGEMENT ----------------

//   /// Download XLSX from /api/products/stock/download/
//   Future<StockFile> downloadStockXlsx() async {
//     final res = await _dio.get<List<int>>(
//       'products/stock/download/',
//       options: Options(
//         responseType: ResponseType.bytes,
//         headers: {
//           'Accept':
//               'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
//           'Accept-Encoding': 'identity', // avoid gzip for binary
//         },
//         validateStatus: (s) => true,
//       ),
//     );

//     if ((res.statusCode ?? 500) != 200 || res.data == null) {
//       throw Exception(
//           'Download failed (${res.statusCode}): ${res.statusMessage}');
//     }

//     final bytes = Uint8List.fromList(res.data!);
//     final filename = _filenameFromContentDisposition(
//       res.headers.value('content-disposition'),
//       fallback: 'stock_${DateTime.now().millisecondsSinceEpoch}.xlsx',
//     );

//     return StockFile(filename: filename, bytes: bytes);
//   }

//   /// Upload XLSX to /api/products/stock/upload/
//   Future<void> uploadStockXlsx({
//     required Uint8List bytes,
//     String filename = 'stock_update.xlsx',
//   }) async {
//     final form = FormData.fromMap({
//       'file': MultipartFile.fromBytes(bytes, filename: filename),
//     });
//     final res = await _dio.post(
//       'products/stock/upload/',
//       data: form,
//       options: Options(
//         contentType: 'multipart/form-data',
//         validateStatus: (s) => true,
//       ),
//     );

//     if ((res.statusCode ?? 500) >= 400) {
//       final body = res.data;
//       final msg = (body is Map)
//           ? (body['detail'] ??
//               body['message'] ??
//               body['error'] ??
//               'Upload failed')
//           : 'Upload failed';
//       throw Exception('$msg (${res.statusCode})');
//     }
//   }

//   /// Update ONE product using /api/products/bulk_update/
//   Future<void> updateProductSingle({
//     required int productId,
//     int? stock,
//     double? price,
//   }) async {
//     if (stock == null && price == null) {
//       throw Exception('Provide stock and/or price to update');
//     }
//     final payload = {
//       'updates': [
//         {
//           'id': productId,
//           if (stock != null) 'stock': stock,
//           if (price != null) 'price': price,
//         }
//       ]
//     };

//     final res = await _dio.post(
//       'products/bulk_update/',
//       data: payload,
//       options: Options(validateStatus: (s) => true),
//     );

//     if ((res.statusCode ?? 500) >= 400) {
//       final body = res.data;
//       final msg = (body is Map)
//           ? (body['detail'] ??
//               body['message'] ??
//               body['error'] ??
//               'Update failed')
//           : 'Update failed';
//       throw Exception('$msg (${res.statusCode})');
//     }
//   }

//   /// Sales report: /api/reports/daily-sales/?from=...&to=...
//   Future<SalesReport> salesReport({
//     required DateTime from,
//     required DateTime to,
//   }) async {
//     final res = await _dio.get(
//       'reports/daily-sales/',
//       queryParameters: {
//         'from': from.toUtc().toIso8601String(),
//         'to': to.toUtc().toIso8601String(),
//       },
//       options: Options(validateStatus: (s) => true),
//     );

//     if ((res.statusCode ?? 500) >= 400 || res.data is! Map) {
//       throw Exception(
//           'Report failed (${res.statusCode}): ${res.statusMessage}');
//     }
//     return SalesReport.fromJson(res.data as Map<String, dynamic>);
//   }
// }

// // ----------------- HELPERS -----------------

// String _filenameFromContentDisposition(String? cd, {String fallback = 'file'}) {
//   if (cd == null || cd.isEmpty) return fallback;

//   // RFC 5987: filename*=UTF-8''encoded-name.xlsx
//   final star = RegExp(r"filename\*=(?:UTF-8''|)([^;]+)", caseSensitive: false)
//       .firstMatch(cd);
//   if (star != null) {
//     var v = star.group(1)!.trim();
//     if (v.startsWith('"') && v.endsWith('"')) {
//       v = v.substring(1, v.length - 1);
//     }
//     return Uri.decodeFull(v);
//   }

//   // filename="name.xlsx" OR filename=name.xlsx
//   final plain =
//       RegExp(r'filename="?([^";]+)"?', caseSensitive: false).firstMatch(cd);
//   if (plain != null) {
//     return plain.group(1)!.trim();
//   }
//   return fallback;
// }

// // ----------------- MODELS -----------------

// class Order {
//   final int id;
//   final String status;
//   final String statusDisplay;
//   final String shippingName;
//   final String shippingPhone;
//   final String addressLine1;
//   final String addressLine2;
//   final String city;
//   final String state;
//   final String pincode;
//   final double totalAmount;
//   final DateTime createdAt;
//   final List<OrderItem> items;

//   Order({
//     required this.id,
//     required this.status,
//     required this.statusDisplay,
//     required this.shippingName,
//     required this.shippingPhone,
//     required this.addressLine1,
//     required this.addressLine2,
//     required this.city,
//     required this.state,
//     required this.pincode,
//     required this.totalAmount,
//     required this.createdAt,
//     required this.items,
//   });

//   factory Order.fromJson(Map<String, dynamic> j) => Order(
//         id: j['id'] as int,
//         status: j['status'] as String,
//         statusDisplay: j['status_display'] as String? ?? j['status'] as String,
//         shippingName: j['shipping_name'] ?? '',
//         shippingPhone: j['shipping_phone'] ?? '',
//         addressLine1: j['address_line1'] ?? '',
//         addressLine2: j['address_line2'] ?? '',
//         city: j['city'] ?? '',
//         state: j['state'] ?? '',
//         pincode: j['pincode'] ?? '',
//         totalAmount: _toDouble(j['total_amount']),
//         createdAt: DateTime.parse(j['created_at'] as String),
//         items: (j['items'] as List? ?? [])
//             .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
//             .toList(),
//       );
// }

// class OrderItem {
//   final int id;
//   final int productId;
//   final String productName;
//   final int quantity;
//   final double unitPrice;
//   final double lineTotal;
//   final String? imageUrl;

//   OrderItem({
//     required this.id,
//     required this.productId,
//     required this.productName,
//     required this.quantity,
//     required this.unitPrice,
//     required this.lineTotal,
//     required this.imageUrl,
//   });

//   factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
//         id: j['id'] as int,
//         productId: j['product_id'] as int,
//         productName: j['product_name'] as String? ?? '',
//         quantity: j['quantity'] as int? ?? 0,
//         unitPrice: _toDouble(j['unit_price']),
//         lineTotal: _toDouble(j['line_total']),
//         imageUrl: j['image_url'] as String?,
//       );
// }

// // ---- Stock/download helpers ----

// class StockFile {
//   final String filename;
//   final Uint8List bytes;
//   StockFile({required this.filename, required this.bytes});
// }

// class SalesReport {
//   final DateTime? from;
//   final DateTime? to;
//   final int totalOrders;
//   final int totalItems;
//   final double totalRevenue;
//   final List<TopSeller> top;

//   SalesReport({
//     required this.from,
//     required this.to,
//     required this.totalOrders,
//     required this.totalItems,
//     required this.totalRevenue,
//     required this.top,
//   });

//   factory SalesReport.fromJson(Map<String, dynamic> j) => SalesReport(
//         from: (j['from'] is String && (j['from'] as String).isNotEmpty)
//             ? DateTime.tryParse(j['from'])
//             : null,
//         to: (j['to'] is String && (j['to'] as String).isNotEmpty)
//             ? DateTime.tryParse(j['to'])
//             : null,
//         totalOrders: (j['total_orders'] as num?)?.toInt() ?? 0,
//         totalItems: (j['total_items'] as num?)?.toInt() ?? 0,
//         totalRevenue: _toDouble(j['total_revenue']),
//         top: (j['top'] as List? ?? [])
//             .map((e) => TopSeller.fromJson(e as Map<String, dynamic>))
//             .toList(),
//       );
// }

// class TopSeller {
//   final int productId;
//   final String name;
//   final int qty;
//   final double revenue;

//   TopSeller({
//     required this.productId,
//     required this.name,
//     required this.qty,
//     required this.revenue,
//   });

//   factory TopSeller.fromJson(Map<String, dynamic> j) => TopSeller(
//         productId: (j['product_id'] as num?)?.toInt() ?? 0,
//         name: j['name']?.toString() ?? '',
//         qty: (j['qty'] as num?)?.toInt() ?? 0,
//         revenue: _toDouble(j['revenue']),
//       );
// }

// // lib/api.dart
// import 'dart:typed_data';
// import 'package:dio/dio.dart';

// double _toDouble(dynamic v) {
//   if (v == null) return 0.0;
//   if (v is num) return v.toDouble();
//   if (v is String) return double.tryParse(v) ?? 0.0;
//   return 0.0;
// }

// class Api {
//   final Dio _dio;

//   Api({required String baseUrl, required String? token})
//       : _dio = Dio(
//           BaseOptions(
//             baseUrl: baseUrl, // e.g. http://127.0.0.1:8000/api/
//             headers: {
//               if (token != null) 'Authorization': 'Token $token',
//               'Content-Type': 'application/json',
//               'Accept': 'application/json',
//             },
//             connectTimeout: const Duration(seconds: 10),
//             receiveTimeout: const Duration(seconds: 20),
//           ),
//         );

//   void setToken(String? token) {
//     if (token == null) {
//       _dio.options.headers.remove('Authorization');
//     } else {
//       _dio.options.headers['Authorization'] = 'Token $token';
//     }
//   }

//   // ---------------- AUTH ----------------

//   Future<String> login({
//     required String phone,
//     required String password,
//   }) async {
//     final payloads = [
//       {'phone': phone, 'password': password},
//       {'username': phone, 'password': password}, // fallback
//     ];

//     DioException? lastErr;

//     for (final data in payloads) {
//       try {
//         final res = await _dio.post(
//           'users/login/',
//           data: data,
//           options: Options(headers: {
//             'Authorization': null, // ensure no token on login
//             'Content-Type': 'application/json',
//             'Accept': 'application/json',
//           }),
//         );
//         final body = res.data;
//         if (body is Map && body['token'] is String) {
//           final t = body['token'] as String;
//           setToken(t);
//           return t;
//         }
//         throw Exception('Invalid login response: $body');
//       } on DioException catch (e) {
//         lastErr = e;
//         if ((e.response?.statusCode ?? 0) != 401) break;
//       }
//     }

//     if (lastErr != null) {
//       final code = lastErr.response?.statusCode;
//       final msg = lastErr.response?.data is Map
//           ? ((lastErr.response!.data['detail'] ??
//                   lastErr.response!.data['error'] ??
//                   lastErr.message)
//               .toString())
//           : lastErr.message;
//       throw Exception('Login failed (${code ?? 'no code'}): $msg');
//     }
//     throw Exception('Login failed for unknown reasons');
//   }

//   // ---------------- ADMIN ORDERS ----------------

//   Future<List<Order>> listOrders({String? status, DateTime? since}) async {
//     final qp = <String, dynamic>{'source': 'ONLINE'};
//     if (status != null) qp['status'] = status;
//     if (since != null) qp['since'] = since.toUtc().toIso8601String();

//     final res = await _dio.get('admin/orders/', queryParameters: qp);
//     final data = res.data;
//     if (data is List) {
//       return data
//           .map((e) => Order.fromJson(e as Map<String, dynamic>))
//           .toList();
//     }
//     throw Exception('Invalid orders response');
//   }

//   Future<Order> setStatus(int orderId, String status) async {
//     final res = await _dio
//         .patch('admin/orders/$orderId/status/', data: {'status': status});
//     return Order.fromJson(res.data as Map<String, dynamic>);
//   }

//   Future<Order> cancel(int orderId) async {
//     final res = await _dio.post('admin/orders/$orderId/cancel/');
//     return Order.fromJson(res.data as Map<String, dynamic>);
//   }

//   Future<Order> getOrder(int orderId) async {
//     final res = await _dio.get('admin/orders/$orderId/');
//     return Order.fromJson(res.data as Map<String, dynamic>);
//   }

//   // ---------------- STOCK MANAGEMENT ----------------
//   // Your backend routes:
//   //   - products/stock/upload/     (POST multipart)
//   //   - products/stock/download/   (GET  -> XLSX)
//   //   - products/bulk_update/      (POST -> {updates:[{id,stock,price}]})
//   //   - reports/daily-sales/       (GET  -> ?from=&to=)

//   /// Download XLSX from /api/products/stock/download/
//   Future<StockFile> downloadStockXlsx() async {
//     final res = await _dio.get<List<int>>(
//       'products/stock/download/',
//       options: Options(
//         responseType: ResponseType.bytes,
//         // Important: don't send a narrow Accept to avoid DRF 406.
//         headers: {
//           'Accept': '*/*',
//           'Accept-Encoding': 'identity', // avoid gzip for binary
//         },
//         validateStatus: (s) => true,
//       ),
//     );

//     if ((res.statusCode ?? 500) != 200 || res.data == null) {
//       throw Exception(
//           'Download failed (${res.statusCode}): ${res.statusMessage}');
//     }

//     final bytes = Uint8List.fromList(res.data!);
//     final filename = _filenameFromContentDisposition(
//       res.headers.value('content-disposition'),
//       fallback: 'stock_${DateTime.now().millisecondsSinceEpoch}.xlsx',
//     );

//     return StockFile(filename: filename, bytes: bytes);
//   }

//   /// Upload XLSX to /api/products/stock/upload/
//   Future<void> uploadStockXlsx({
//     required Uint8List bytes,
//     String filename = 'stock_update.xlsx',
//   }) async {
//     final form = FormData.fromMap({
//       'file': MultipartFile.fromBytes(bytes, filename: filename),
//     });
//     final res = await _dio.post(
//       'products/stock/upload/',
//       data: form,
//       options: Options(
//         contentType: 'multipart/form-data',
//         validateStatus: (s) => true,
//       ),
//     );

//     if ((res.statusCode ?? 500) >= 400) {
//       final body = res.data;
//       final msg = (body is Map)
//           ? (body['detail'] ??
//               body['message'] ??
//               body['error'] ??
//               'Upload failed')
//           : 'Upload failed';
//       throw Exception('$msg (${res.statusCode})');
//     }
//   }

//   /// Update ONE product using /api/products/bulk_update/
//   Future<void> updateProductSingle({
//     required int productId,
//     int? stock,
//     double? price,
//   }) async {
//     if (stock == null && price == null) {
//       throw Exception('Provide stock and/or price to update');
//     }
//     final payload = {
//       'updates': [
//         {
//           'id': productId,
//           if (stock != null) 'stock': stock,
//           if (price != null) 'price': price,
//         }
//       ]
//     };

//     final res = await _dio.post(
//       'products/bulk_update/',
//       data: payload,
//       options: Options(validateStatus: (s) => true),
//     );

//     if ((res.statusCode ?? 500) >= 400) {
//       final body = res.data;
//       final msg = (body is Map)
//           ? (body['detail'] ??
//               body['message'] ??
//               body['error'] ??
//               'Update failed')
//           : 'Update failed';
//       throw Exception('$msg (${res.statusCode})');
//     }
//   }

//   /// Sales report: /api/reports/daily-sales/?from=...&to=...
//   Future<SalesReport> salesReport({
//     required DateTime from,
//     required DateTime to,
//   }) async {
//     final res = await _dio.get(
//       'reports/daily-sales/',
//       queryParameters: {
//         'from': from.toUtc().toIso8601String(),
//         'to': to.toUtc().toIso8601String(),
//       },
//       options: Options(validateStatus: (s) => true),
//     );

//     if ((res.statusCode ?? 500) >= 400 || res.data is! Map) {
//       throw Exception(
//           'Report failed (${res.statusCode}): ${res.statusMessage}');
//     }
//     return SalesReport.fromJson(res.data as Map<String, dynamic>);
//   }
// }

// // ----------------- HELPERS -----------------

// String _filenameFromContentDisposition(String? cd, {String fallback = 'file'}) {
//   if (cd == null || cd.isEmpty) return fallback;

//   // RFC 5987: filename*=UTF-8''encoded-name.xlsx
//   final star = RegExp(r"filename\*=(?:UTF-8''|)([^;]+)", caseSensitive: false)
//       .firstMatch(cd);
//   if (star != null) {
//     var v = star.group(1)!.trim();
//     if (v.startsWith('"') && v.endsWith('"')) {
//       v = v.substring(1, v.length - 1);
//     }
//     return Uri.decodeFull(v);
//   }

//   // filename="name.xlsx" OR filename=name.xlsx
//   final plain =
//       RegExp(r'filename="?([^";]+)"?', caseSensitive: false).firstMatch(cd);
//   if (plain != null) {
//     return plain.group(1)!.trim();
//   }
//   return fallback;
// }

// // ----------------- MODELS -----------------

// class Order {
//   final int id;
//   final String status;
//   final String statusDisplay;
//   final String shippingName;
//   final String shippingPhone;
//   final String addressLine1;
//   final String addressLine2;
//   final String city;
//   final String state;
//   final String pincode;
//   final double totalAmount;
//   final DateTime createdAt;
//   final List<OrderItem> items;

//   Order({
//     required this.id,
//     required this.status,
//     required this.statusDisplay,
//     required this.shippingName,
//     required this.shippingPhone,
//     required this.addressLine1,
//     required this.addressLine2,
//     required this.city,
//     required this.state,
//     required this.pincode,
//     required this.totalAmount,
//     required this.createdAt,
//     required this.items,
//   });

//   factory Order.fromJson(Map<String, dynamic> j) => Order(
//         id: j['id'] as int,
//         status: j['status'] as String,
//         statusDisplay: j['status_display'] as String? ?? j['status'] as String,
//         shippingName: j['shipping_name'] ?? '',
//         shippingPhone: j['shipping_phone'] ?? '',
//         addressLine1: j['address_line1'] ?? '',
//         addressLine2: j['address_line2'] ?? '',
//         city: j['city'] ?? '',
//         state: j['state'] ?? '',
//         pincode: j['pincode'] ?? '',
//         totalAmount: _toDouble(j['total_amount']),
//         createdAt: DateTime.parse(j['created_at'] as String),
//         items: (j['items'] as List? ?? [])
//             .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
//             .toList(),
//       );
// }

// class OrderItem {
//   final int id;
//   final int productId;
//   final String productName;
//   final int quantity;
//   final double unitPrice;
//   final double lineTotal;
//   final String? imageUrl;

//   OrderItem({
//     required this.id,
//     required this.productId,
//     required this.productName,
//     required this.quantity,
//     required this.unitPrice,
//     required this.lineTotal,
//     required this.imageUrl,
//   });

//   factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
//         id: j['id'] as int,
//         productId: j['product_id'] as int,
//         productName: j['product_name'] as String? ?? '',
//         quantity: j['quantity'] as int? ?? 0,
//         unitPrice: _toDouble(j['unit_price']),
//         lineTotal: _toDouble(j['line_total']),
//         imageUrl: j['image_url'] as String?,
//       );
// }

// // ---- Stock/download helpers ----

// class StockFile {
//   final String filename;
//   final Uint8List bytes;
//   StockFile({required this.filename, required this.bytes});
// }

// class SalesReport {
//   final DateTime? from;
//   final DateTime? to;
//   final int totalOrders;
//   final int totalItems;
//   final double totalRevenue;
//   final List<TopSeller> top;

//   SalesReport({
//     required this.from,
//     required this.to,
//     required this.totalOrders,
//     required this.totalItems,
//     required this.totalRevenue,
//     required this.top,
//   });

//   factory SalesReport.fromJson(Map<String, dynamic> j) => SalesReport(
//         from: (j['from'] is String && (j['from'] as String).isNotEmpty)
//             ? DateTime.tryParse(j['from'])
//             : null,
//         to: (j['to'] is String && (j['to'] as String).isNotEmpty)
//             ? DateTime.tryParse(j['to'])
//             : null,
//         totalOrders: (j['total_orders'] as num?)?.toInt() ?? 0,
//         totalItems: (j['total_items'] as num?)?.toInt() ?? 0,
//         totalRevenue: _toDouble(j['total_revenue']),
//         top: (j['top'] as List? ?? [])
//             .map((e) => TopSeller.fromJson(e as Map<String, dynamic>))
//             .toList(),
//       );
// }

// class TopSeller {
//   final int productId;
//   final String name;
//   final int qty;
//   final double revenue;

//   TopSeller({
//     required this.productId,
//     required this.name,
//     required this.qty,
//     required this.revenue,
//   });

//   factory TopSeller.fromJson(Map<String, dynamic> j) => TopSeller(
//         productId: (j['product_id'] as num?)?.toInt() ?? 0,
//         name: j['name']?.toString() ?? '',
//         qty: (j['qty'] as num?)?.toInt() ?? 0,
//         revenue: _toDouble(j['revenue']),
//       );
// }
// lib/api.dart
import 'dart:typed_data';
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
      : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl, // e.g. http://127.0.0.1:8000/api/
            headers: {
              if (token != null) 'Authorization': 'Token $token',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 20),
          ),
        );

  void setToken(String? token) {
    if (token == null) {
      _dio.options.headers.remove('Authorization');
    } else {
      _dio.options.headers['Authorization'] = 'Token $token';
    }
  }

  // ---------------- AUTH ----------------

  Future<String> login({
    required String phone,
    required String password,
  }) async {
    final payloads = [
      {'phone': phone, 'password': password},
      {'username': phone, 'password': password}, // fallback
    ];

    DioException? lastErr;

    for (final data in payloads) {
      try {
        final res = await _dio.post(
          'users/login/',
          data: data,
          options: Options(headers: {
            'Authorization': null, // ensure no token on login
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
        if ((e.response?.statusCode ?? 0) != 401) break;
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

  // ---------------- ADMIN ORDERS ----------------

  Future<List<Order>> listOrders({String? status, DateTime? since}) async {
    final qp = <String, dynamic>{'source': 'ONLINE'};
    if (status != null) qp['status'] = status;
    if (since != null) qp['since'] = since.toUtc().toIso8601String();

    final res = await _dio.get('admin/orders/', queryParameters: qp);
    final data = res.data;
    if (data is List) {
      return data
          .map((e) => Order.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    throw Exception('Invalid orders response');
  }

  Future<Order> setStatus(int orderId, String status) async {
    final res = await _dio
        .patch('admin/orders/$orderId/status/', data: {'status': status});
    return Order.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<Order> cancel(int orderId) async {
    final res = await _dio.post('admin/orders/$orderId/cancel/');
    return Order.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<Order> getOrder(int orderId) async {
    final res = await _dio.get('admin/orders/$orderId/');
    return Order.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  // ---------------- STOCK MANAGEMENT ----------------
  // Views:
  //   - products/stock/upload/     (POST multipart)
  //   - products/stock/download/   (GET  -> XLSX)
  //   - products/bulk_update/      (PATCH -> {"items":[{id,stock?,price?}]})
  //   - reports/daily-sales/       (GET  -> ?date=YYYY-MM-DD; ?format=xlsx for file)
  //   - products/                  (GET  -> list/search)

  /// Download XLSX from /api/products/stock/download/
  Future<StockFile> downloadStockXlsx() async {
    final res = await _dio.get<List<int>>(
      'products/stock/download/',
      options: Options(
        responseType: ResponseType.bytes,
        headers: {'Accept': '*/*', 'Accept-Encoding': 'identity'},
        validateStatus: (s) => true,
      ),
    );

    if ((res.statusCode ?? 500) != 200 || res.data == null) {
      throw Exception(
          'Download failed (${res.statusCode}): ${res.statusMessage}');
    }

    final bytes = Uint8List.fromList(res.data!);
    final filename = _filenameFromContentDisposition(
      res.headers.value('content-disposition'),
      fallback: 'stock_${DateTime.now().millisecondsSinceEpoch}.xlsx',
    );
    return StockFile(filename: filename, bytes: bytes);
  }

  /// Upload XLSX to /api/products/stock/upload/
  Future<void> uploadStockXlsx({
    required Uint8List bytes,
    String filename = 'stock_update.xlsx',
    bool dryRun = false,
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
      if (dryRun) 'dry_run': '1',
    });
    final res = await _dio.post(
      'products/stock/upload/',
      data: form,
      options: Options(
        contentType: 'multipart/form-data',
        validateStatus: (s) => true,
      ),
    );

    if ((res.statusCode ?? 500) >= 400) {
      final body = res.data;
      final msg = (body is Map)
          ? (body['detail'] ??
              body['message'] ??
              body['error'] ??
              'Upload failed')
          : 'Upload failed';
      throw Exception('$msg (${res.statusCode})');
    }
  }

  /// Bulk update (PATCH /api/products/bulk_update/)
  Future<BulkUpdateResult> updateProductsBulk(List<BulkPatch> items) async {
    if (items.isEmpty) {
      throw Exception('No items to update');
    }
    final payload = {
      'items': items.map((e) => e.toJson()).toList(),
    };

    final res = await _dio.patch(
      'products/bulk_update/',
      data: payload,
      options: Options(validateStatus: (s) => true),
    );

    if ((res.statusCode ?? 500) >= 400 || res.data is! Map) {
      final body = res.data;
      final msg = (body is Map)
          ? (body['detail'] ??
              body['message'] ??
              body['error'] ??
              'Bulk update failed')
          : 'Bulk update failed';
      throw Exception('$msg (${res.statusCode})');
    }

    final map = Map<String, dynamic>.from(res.data as Map);
    return BulkUpdateResult(
      ok: (map['ok'] == true),
      updated: (map['updated'] as num?)?.toInt() ?? 0,
      errors: (map['errors'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  /// Convenience: update a single product via bulk endpoint.
  Future<void> updateProductSingle({
    required int productId,
    int? stock,
    double? price,
  }) async {
    if (stock == null && price == null) {
      throw Exception('Provide stock and/or price to update');
    }
    await updateProductsBulk([
      BulkPatch(id: productId, stock: stock, price: price),
    ]);
  }

  /// Daily sales (JSON): /api/reports/daily-sales/?date=YYYY-MM-DD
  Future<DailySales> dailySalesJson(DateTime day) async {
    final res = await _dio.get(
      'reports/daily-sales/',
      queryParameters: {'date': _ymd(day)},
      options: Options(validateStatus: (s) => true),
    );

    if ((res.statusCode ?? 500) >= 400 || res.data is! Map) {
      throw Exception(
          'Report failed (${res.statusCode}): ${res.statusMessage}');
    }
    return DailySales.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  /// Daily sales XLSX download (?format=xlsx)
  Future<StockFile> dailySalesXlsx(DateTime day) async {
    final res = await _dio.get<List<int>>(
      'reports/daily-sales/',
      queryParameters: {'date': _ymd(day), 'format': 'xlsx'},
      options: Options(
        responseType: ResponseType.bytes,
        headers: {'Accept': '*/*', 'Accept-Encoding': 'identity'},
        validateStatus: (s) => true,
      ),
    );

    if ((res.statusCode ?? 500) != 200 || res.data == null) {
      throw Exception(
          'Download failed (${res.statusCode}): ${res.statusMessage}');
    }

    final bytes = Uint8List.fromList(res.data!);
    final filename = _filenameFromContentDisposition(
      res.headers.value('content-disposition'),
      fallback: 'sales_${_ymd(day)}.xlsx',
    );
    return StockFile(filename: filename, bytes: bytes);
  }

  /// Product search for autocomplete on name.
  Future<List<ProductLite>> searchProducts(String query,
      {int limit = 20}) async {
    final res = await _dio.get(
      'products/',
      queryParameters: {
        'search': query,
        'ordering': 'name',
        'page_size': limit,
      },
      options: Options(validateStatus: (s) => true),
    );

    final data = res.data;
    final List raw = (data is Map && data['results'] is List)
        ? (data['results'] as List)
        : (data is List ? data : const []);

    return raw
        .map((e) => ProductLite.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}

// ----------------- HELPERS -----------------

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _filenameFromContentDisposition(String? cd, {String fallback = 'file'}) {
  if (cd == null || cd.isEmpty) return fallback;

  final star = RegExp(r"filename\*=(?:UTF-8''|)([^;]+)", caseSensitive: false)
      .firstMatch(cd);
  if (star != null) {
    var v = star.group(1)!.trim();
    if (v.startsWith('"') && v.endsWith('"')) {
      v = v.substring(1, v.length - 1);
    }
    return Uri.decodeFull(v);
  }

  final plain =
      RegExp(r'filename="?([^";]+)"?', caseSensitive: false).firstMatch(cd);
  if (plain != null) {
    return plain.group(1)!.trim();
  }
  return fallback;
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
            .map((e) => OrderItem.fromJson(Map<String, dynamic>.from(e as Map)))
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

// ---- Stock/download helpers ----

class StockFile {
  final String filename;
  final Uint8List bytes;
  StockFile({required this.filename, required this.bytes});
}

// ---- Bulk update ----
class BulkPatch {
  final int id;
  final int? stock;
  final double? price;

  BulkPatch({required this.id, this.stock, this.price});

  Map<String, dynamic> toJson() => {
        'id': id,
        if (stock != null) 'stock': stock,
        if (price != null) 'price': price,
      };
}

class BulkUpdateResult {
  final bool ok;
  final int updated;
  final List<String> errors;

  BulkUpdateResult({
    required this.ok,
    required this.updated,
    required this.errors,
  });
}

// ---- Daily sales models (match your JSON) ----
class DailySales {
  final DateTime day;
  final int orders;
  final int unitsSold;
  final double revenue;
  final List<ProductSales> byProduct;
  final Map<String, SourceSummary> bySource;

  DailySales({
    required this.day,
    required this.orders,
    required this.unitsSold,
    required this.revenue,
    required this.byProduct,
    required this.bySource,
  });

  factory DailySales.fromJson(Map<String, dynamic> j) {
    final src = <String, SourceSummary>{};
    final m = (j['by_source'] as Map?) ?? const {};
    for (final k in m.keys) {
      final v = m[k];
      if (v is Map)
        src[k.toString()] =
            SourceSummary.fromJson(Map<String, dynamic>.from(v));
    }

    return DailySales(
      day: DateTime.tryParse(j['date']?.toString() ?? '') ?? DateTime.now(),
      orders: (j['orders'] as num?)?.toInt() ?? 0,
      unitsSold: (j['units_sold'] as num?)?.toInt() ?? 0,
      revenue: _toDouble(j['revenue']),
      byProduct: (j['by_product'] as List? ?? [])
          .map(
              (e) => ProductSales.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      bySource: src,
    );
  }
}

class SourceSummary {
  final int orders;
  final double revenue;

  SourceSummary({required this.orders, required this.revenue});

  factory SourceSummary.fromJson(Map<String, dynamic> j) => SourceSummary(
        orders: (j['orders'] as num?)?.toInt() ?? 0,
        revenue: _toDouble(j['revenue']),
      );
}

class ProductSales {
  final int productId;
  final String name;
  final String? category;
  final int quantity;
  final double amount;

  ProductSales({
    required this.productId,
    required this.name,
    required this.category,
    required this.quantity,
    required this.amount,
  });

  factory ProductSales.fromJson(Map<String, dynamic> j) => ProductSales(
        productId: (j['product_id'] as num?)?.toInt() ?? 0,
        name: j['name']?.toString() ?? '',
        category: j['category']?.toString(),
        quantity: (j['quantity'] as num?)?.toInt() ?? 0,
        amount: _toDouble(j['amount']),
      );
}

/// Minimal product for search/autocomplete in Quick Adjust / Bulk Update
class ProductLite {
  final int id;
  final String name;
  final int stock;
  final double price;

  ProductLite({
    required this.id,
    required this.name,
    required this.stock,
    required this.price,
  });

  factory ProductLite.fromJson(Map<String, dynamic> j) => ProductLite(
        id: (j['id'] as num).toInt(),
        name: (j['name'] ?? '').toString(),
        stock: (j['stock'] as num?)?.toInt() ?? 0,
        price: _toDouble(j['price'] ?? j['mrp'] ?? j['unit_price']),
      );
}
