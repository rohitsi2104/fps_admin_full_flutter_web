// // lib/pos/billing_service.dart
// import 'dart:convert';
// import 'package:http/http.dart' as http;

// /// ---------- Data models ----------
// class Product {
//   final int id;
//   final String name;
//   final double price; // unit price
//   final String? unit; // e.g., kg, pcs

//   Product({
//     required this.id,
//     required this.name,
//     required this.price,
//     this.unit,
//   });

//   factory Product.fromJson(Map<String, dynamic> j) {
//     final rawPrice = j['price'] ?? j['unit_price'] ?? j['mrp'] ?? 0;
//     return Product(
//       id: (j['id'] is int) ? j['id'] as int : int.tryParse('${j['id']}') ?? 0,
//       name: (j['name'] ?? j['title'] ?? '').toString(),
//       price: (rawPrice is num)
//           ? rawPrice.toDouble()
//           : double.tryParse(rawPrice.toString()) ?? 0.0,
//       unit: j['unit']?.toString(),
//     );
//   }
// }

// class CartLine {
//   final Product product;
//   int qty;
//   double unitPrice;

//   CartLine({
//     required this.product,
//     this.qty = 1,
//     double? unitPrice,
//   }) : unitPrice = unitPrice ?? product.price;

//   double get lineTotal => unitPrice * qty;

//   Map<String, dynamic> toJson() => {
//         'product_id': product.id,
//         'name': product.name,
//         'qty': qty,
//         'unit_price': unitPrice,
//         'line_total': lineTotal,
//       };
// }

// class InvoiceResult {
//   final bool ok;
//   final int? orderId;
//   final String? invoiceNumber;
//   final String? pdfUrl;
//   final String? message;

//   InvoiceResult({
//     required this.ok,
//     this.orderId,
//     this.invoiceNumber,
//     this.pdfUrl,
//     this.message,
//   });

//   factory InvoiceResult.fromResponse(int status, Map<String, dynamic> j) {
//     return InvoiceResult(
//       ok: status >= 200 && status < 300,
//       orderId: (j['order_id'] is int)
//           ? j['order_id']
//           : int.tryParse('${j['order_id'] ?? ''}'),
//       invoiceNumber: j['invoice_number']?.toString(),
//       pdfUrl: j['pdf_url']?.toString(),
//       message: (j['detail'] ?? j['message'] ?? '').toString(),
//     );
//   }
// }

// /// ---------- Service (cache-only suggestions) ----------
// class BillingService {
//   final String baseUrl; // e.g. https://fps-dayalbagh-backend.vercel.app
//   final String authToken; // DRF token
//   final http.Client _client;

//   BillingService({
//     required this.baseUrl,
//     required this.authToken,
//     http.Client? client,
//   }) : _client = client ?? http.Client();

//   Map<String, String> get _headers => {
//         'Content-Type': 'application/json',
//         'Authorization': 'Token $authToken',
//       };

//   /// In-memory cache for products (shared across instances).
//   static List<Product>? _cache;
//   static Future<void>? _warming; // dedupe parallel warm-ups

//   bool get hasCache => _cache != null && _cache!.isNotEmpty;

//   /// Load *all* products into memory. Handles:
//   /// - plain list:   [/api/products/] -> [...]
//   /// - paged result: [/api/products/] -> { results: [...], next: "url" }
//   Future<void> warmProducts({bool force = false}) async {
//     if (hasCache && !force) return;

//     // If a warm-up is already running, await it.
//     if (_warming != null && !force) {
//       await _warming;
//       return;
//     }

//     _warming = _doWarmProducts(force: force);
//     try {
//       await _warming;
//     } finally {
//       _warming = null;
//     }
//   }

//   Future<void> _doWarmProducts({required bool force}) async {
//     final all = <Product>[];
//     Uri? uri = Uri.parse('${baseUrl}products/');

//     for (var hop = 0; hop < 500 && uri != null; hop++) {
//       final resp = await _client.get(uri, headers: _headers);
//       if (resp.statusCode < 200 || resp.statusCode >= 300) {
//         // stop on first failure — keep any already-fetched items if not empty
//         break;
//       }
//       final j = _safeJson(resp.body);

//       if (j is List) {
//         all.addAll(j.map<Product>((e) => Product.fromJson(e)));
//         uri = null; // no pagination in plain list
//       } else if (j is Map) {
//         if (j['results'] is List) {
//           all.addAll(
//               (j['results'] as List).map<Product>((e) => Product.fromJson(e)));
//         }
//         final next = (j['next'] ?? '').toString();
//         uri = next.isNotEmpty ? Uri.parse(next) : null;
//       } else {
//         uri = null;
//       }
//     }

//     if (all.isNotEmpty) {
//       all.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
//       _cache = all;
//     } else if (!hasCache) {
//       _cache = <Product>[]; // avoid null checks later
//     }
//   }

//   /// Local filter (no network). Works from the first letter.
//   List<Product> filterProducts(String query, {int limit = 30}) {
//     if (!hasCache || query.trim().isEmpty) return <Product>[];
//     final q = query.toLowerCase();

//     final starts = <Product>[];
//     final contains = <Product>[];

//     for (final p in _cache!) {
//       final n = p.name.toLowerCase();
//       if (n.startsWith(q)) {
//         starts.add(p);
//       } else if (n.contains(q)) {
//         contains.add(p);
//       }
//       if (starts.length >= limit) break;
//     }

//     final combined = <Product>[];
//     combined.addAll(starts.take(limit));
//     for (final p in contains) {
//       if (combined.length >= limit) break;
//       combined.add(p);
//     }
//     return combined;
//   }

//   /// Public suggestion API. Ensures products are warmed once, then filters locally.
//   Future<List<Product>> suggest(String query, {int limit = 30}) async {
//     if (!hasCache) {
//       await warmProducts();
//     }
//     return filterProducts(query, limit: limit);
//   }

//   /// Create a manual (POS) invoice. Tries /api/orders/manual/, then /api/orders/.
//   Future<InvoiceResult> createManualInvoice({
//     required List<CartLine> lines,
//     String? customerName,
//     String? customerPhone,
//     String paymentMethod = 'CASH',
//     bool paid = true,
//     Map<String, dynamic>? extra,
//   }) async {
//     final payload = {
//       'items': lines.map((l) => l.toJson()).toList(),
//       'customer_name': customerName,
//       'customer_phone': customerPhone,
//       'payment_method': paymentMethod,
//       'paid': paid,
//       'is_manual': true,
//       if (extra != null) ...extra,
//     };

//     // 1) Preferred endpoint
//     final uri1 = Uri.parse('${baseUrl}pos/invoices/');
//     try {
//       final r1 = await _client.post(uri1,
//           headers: _headers, body: jsonEncode(payload));
//       final body = _safeMap(r1.body);
//       if (r1.statusCode != 404) {
//         return InvoiceResult.fromResponse(r1.statusCode, body);
//       }
//     } catch (_) {/* fall through */}

//     // 2) Fallback endpoint
//     final uri2 = Uri.parse('${baseUrl}orders/');
//     try {
//       final r2 = await _client.post(uri2,
//           headers: _headers, body: jsonEncode(payload));
//       final body = _safeMap(r2.body);
//       return InvoiceResult.fromResponse(r2.statusCode, body);
//     } catch (e) {
//       return InvoiceResult(ok: false, message: 'Network error: $e');
//     }
//   }

//   dynamic _safeJson(String s) {
//     try {
//       return jsonDecode(s);
//     } catch (_) {
//       return {'raw': s};
//     }
//   }

//   Map<String, dynamic> _safeMap(String s) {
//     final j = _safeJson(s);
//     return (j is Map<String, dynamic>) ? j : <String, dynamic>{'raw': j};
//   }
// }
// lib/billing_home_page.dart
// import 'dart:convert';
// import 'package:flutter/foundation.dart' show compute;
// import 'package:http/http.dart' as http;

// /// ---------- Data models ----------
// class Product {
//   final int id;
//   final String name;
//   final String nameLower; // for faster filtering
//   final double price; // unit price
//   final String? unit; // e.g., kg, pcs

//   Product({
//     required this.id,
//     required this.name,
//     required this.nameLower,
//     required this.price,
//     this.unit,
//   });

//   factory Product.fromJson(Map<String, dynamic> j) {
//     final rawPrice = j['price'] ?? j['unit_price'] ?? j['mrp'] ?? 0;
//     final name = (j['name'] ?? j['title'] ?? '').toString();
//     return Product(
//       id: (j['id'] is int) ? j['id'] as int : int.tryParse('${j['id']}') ?? 0,
//       name: name,
//       nameLower: name.toLowerCase(),
//       price: (rawPrice is num)
//           ? rawPrice.toDouble()
//           : double.tryParse(rawPrice.toString()) ?? 0.0,
//       unit: j['unit']?.toString(),
//     );
//   }
// }

// class CartLine {
//   final Product product;
//   int qty;
//   double unitPrice;

//   CartLine({
//     required this.product,
//     this.qty = 1,
//     double? unitPrice,
//   }) : unitPrice = unitPrice ?? product.price;

//   double get lineTotal => unitPrice * qty;

//   Map<String, dynamic> toJson() => {
//         'product_id': product.id,
//         'name': product.name,
//         'qty': qty,
//         'unit_price': unitPrice,
//         // DO NOT send line_total; backend computes it.
//       };
// }

// class InvoiceResult {
//   final bool ok;

//   /// Normalized: we try to give you a single orderId field.
//   /// If backend returns `order_id`, we use that.
//   /// If it only returns `invoice_id`, we fall back to that number.
//   final int? orderId;

//   final String? invoiceNumber; // kept for compatibility if backend returns it
//   final String? pdfUrl;
//   final String? message;

//   InvoiceResult({
//     required this.ok,
//     this.orderId,
//     this.invoiceNumber,
//     this.pdfUrl,
//     this.message,
//   });

//   factory InvoiceResult.fromResponse(int status, Map<String, dynamic> j) {
//     int? parseInt(dynamic v) =>
//         (v is int) ? v : int.tryParse(v?.toString() ?? '');

//     final ord = parseInt(j['order_id']);
//     final inv = parseInt(j['invoice_id']);
//     return InvoiceResult(
//       ok: status >= 200 && status < 300,
//       orderId: ord ?? inv, // prefer order_id, else fallback to invoice_id
//       invoiceNumber: j['invoice_number']?.toString(),
//       pdfUrl: j['pdf_url']?.toString(),
//       message: (j['detail'] ?? j['message'] ?? '').toString(),
//     );
//   }
// }

// /// ---------- Service (cache-only suggestions) ----------
// class BillingService {
//   final String baseUrl; // e.g. https://your-host/api/
//   final String authToken; // DRF token
//   final http.Client _client;

//   BillingService({
//     required this.baseUrl,
//     required this.authToken,
//     http.Client? client,
//   }) : _client = client ?? http.Client();

//   Map<String, String> get _headers => {
//         'Content-Type': 'application/json',
//         'Authorization': 'Token $authToken',
//       };

//   /// In-memory cache for products (shared across instances).
//   static List<Product>? _cache;
//   static Future<void>? _warming; // dedupe parallel warm-ups

//   bool get hasCache => _cache != null && _cache!.isNotEmpty;

//   /// Load *all* products into memory.
//   /// Supports both: plain list and paginated {results,next}
//   Future<void> warmProducts({bool force = false}) async {
//     if (hasCache && !force) return;

//     if (_warming != null && !force) {
//       await _warming;
//       return;
//     }

//     _warming = _doWarmProducts();
//     try {
//       await _warming;
//     } finally {
//       _warming = null;
//     }
//   }

//   static List<Product> _parseProductsBody(String body) {
//     final decoded = jsonDecode(body);
//     final out = <Product>[];
//     if (decoded is List) {
//       for (final e in decoded) {
//         if (e is Map<String, dynamic>) out.add(Product.fromJson(e));
//       }
//     } else if (decoded is Map && decoded['results'] is List) {
//       for (final e in (decoded['results'] as List)) {
//         if (e is Map<String, dynamic>) out.add(Product.fromJson(e));
//       }
//     }
//     return out;
//   }

//   Future<void> _doWarmProducts() async {
//     final all = <Product>[];
//     Uri? uri = Uri.parse('${baseUrl}products/');

//     for (var hop = 0; hop < 500 && uri != null; hop++) {
//       final resp = await _client.get(uri, headers: _headers);
//       if (resp.statusCode < 200 || resp.statusCode >= 300) break;

//       // Parse large payloads off the UI thread
//       final batch = resp.body.length > 40 * 1024
//           ? await compute(_parseProductsBody, resp.body)
//           : _parseProductsBody(resp.body);
//       all.addAll(batch);

//       // pagination
//       final decoded = jsonDecode(resp.body);
//       if (decoded is Map &&
//           decoded['next'] != null &&
//           decoded['next'].toString().isNotEmpty) {
//         uri = Uri.parse(decoded['next'].toString());
//       } else {
//         uri = null;
//       }
//     }

//     if (all.isNotEmpty) {
//       all.sort((a, b) => a.nameLower.compareTo(b.nameLower));
//       _cache = all;
//     } else if (!hasCache) {
//       _cache = <Product>[]; // avoid null checks later
//     }
//   }

//   /// Local filter (no network)
//   List<Product> filterProducts(String query, {int limit = 30}) {
//     if (!hasCache || query.trim().isEmpty) return <Product>[];
//     final q = query.toLowerCase();

//     final starts = <Product>[];
//     final contains = <Product>[];

//     for (final p in _cache!) {
//       final n = p.nameLower;
//       if (n.startsWith(q)) {
//         starts.add(p);
//       } else if (n.contains(q)) {
//         contains.add(p);
//       }
//       if (starts.length >= limit) break;
//     }

//     if (starts.length >= limit) return starts.take(limit).toList();

//     final combined = List<Product>.from(starts);
//     for (final p in contains) {
//       if (combined.length >= limit) break;
//       combined.add(p);
//     }
//     return combined;
//   }

//   Future<List<Product>> suggest(String query, {int limit = 30}) async {
//     if (!hasCache) {
//       await warmProducts();
//     }
//     return filterProducts(query, limit: limit);
//   }

//   /// Create a manual (POS) invoice (preferred: /api/pos/invoices/)
//   Future<InvoiceResult> createManualInvoice({
//     required List<CartLine> lines,
//     String? customerName,
//     String? customerPhone,
//     String paymentMethod = 'cash',
//     bool paid = true,
//     Map<String, dynamic>? extra,
//   }) async {
//     final total =
//         lines.fold<double>(0.0, (sum, l) => sum + (l.unitPrice * l.qty));

//     final payload = {
//       'items': lines.map((l) => l.toJson()).toList(),
//       'customer_name': (customerName ?? '').trim(),
//       'customer_phone': (customerPhone ?? '').trim(),
//       'payment_method': paymentMethod.toLowerCase(),
//       'paid': paid,
//       'paid_amount': paid ? total : 0,
//       'is_manual': true,
//       if (extra != null) ...extra,
//     };

//     // 1) Preferred endpoint
//     final uri1 = Uri.parse('${baseUrl}pos/invoices/');
//     try {
//       final r1 = await _client.post(uri1,
//           headers: _headers, body: jsonEncode(payload));
//       final body = _safeMap(r1.body);
//       if (r1.statusCode != 404) {
//         return InvoiceResult.fromResponse(r1.statusCode, body);
//       }
//     } catch (_) {/* fall through */}

//     // 2) Fallback endpoint (if older backend)
//     final uri2 = Uri.parse('${baseUrl}orders/');
//     try {
//       final r2 = await _client.post(uri2,
//           headers: _headers, body: jsonEncode(payload));
//       final body = _safeMap(r2.body);
//       return InvoiceResult.fromResponse(r2.statusCode, body);
//     } catch (e) {
//       return InvoiceResult(ok: false, message: 'Network error: $e');
//     }
//   }

//   dynamic _safeJson(String s) {
//     try {
//       return jsonDecode(s);
//     } catch (_) {
//       return {'raw': s};
//     }
//   }

//   Map<String, dynamic> _safeMap(String s) {
//     final j = _safeJson(s);
//     return (j is Map<String, dynamic>) ? j : <String, dynamic>{'raw': j};
//   }
// }

// import 'dart:convert';
// import 'dart:io';
// import 'package:flutter/foundation.dart' show compute;
// import 'package:http/http.dart' as http;
// import 'package:path_provider/path_provider.dart';

// /// ---------- Data models ----------
// class Product {
//   final int id;
//   final String name;
//   final String nameLower; // for faster filtering
//   final double price; // unit price
//   final String? unit; // e.g., kg, pcs

//   Product({
//     required this.id,
//     required this.name,
//     required this.nameLower,
//     required this.price,
//     this.unit,
//   });

//   factory Product.fromJson(Map<String, dynamic> j) {
//     final rawPrice = j['price'] ?? j['unit_price'] ?? j['mrp'] ?? 0;
//     final name = (j['name'] ?? j['title'] ?? '').toString();
//     return Product(
//       id: (j['id'] is int) ? j['id'] as int : int.tryParse('${j['id']}') ?? 0,
//       name: name,
//       nameLower: name.toLowerCase(),
//       price: (rawPrice is num)
//           ? rawPrice.toDouble()
//           : double.tryParse(rawPrice.toString()) ?? 0.0,
//       unit: j['unit']?.toString(),
//     );
//   }
// }

// class CartLine {
//   final Product product;
//   int qty;
//   double unitPrice;

//   CartLine({
//     required this.product,
//     this.qty = 1,
//     double? unitPrice,
//   }) : unitPrice = unitPrice ?? product.price;

//   double get lineTotal => unitPrice * qty;

//   Map<String, dynamic> toJson() => {
//         'product_id': product.id,
//         'name': product.name,
//         'qty': qty,
//         'unit_price': unitPrice,
//         // DO NOT send line_total; backend computes it.
//       };
// }

// class InvoiceResult {
//   final bool ok;

//   /// Normalized: prefer order_id, else fallback to invoice_id
//   final int? orderId;
//   final String? invoiceNumber;
//   final String? pdfUrl;
//   final String? message;

//   InvoiceResult({
//     required this.ok,
//     this.orderId,
//     this.invoiceNumber,
//     this.pdfUrl,
//     this.message,
//   });

//   factory InvoiceResult.fromResponse(int status, Map<String, dynamic> j) {
//     int? parseInt(dynamic v) =>
//         (v is int) ? v : int.tryParse(v?.toString() ?? '');

//     final ord = parseInt(j['order_id']);
//     final inv = parseInt(j['invoice_id']);
//     return InvoiceResult(
//       ok: status >= 200 && status < 300,
//       orderId: ord ?? inv,
//       invoiceNumber: j['invoice_number']?.toString(),
//       pdfUrl: j['pdf_url']?.toString(),
//       message: (j['detail'] ?? j['message'] ?? '').toString(),
//     );
//   }
// }

// /// ---------- Service ----------
// class BillingService {
//   final String baseUrl; // e.g. https://your-backend/api/
//   final String authToken; // DRF token
//   final http.Client _client;

//   BillingService({
//     required this.baseUrl,
//     required this.authToken,
//     http.Client? client,
//   }) : _client = client ?? http.Client();

//   Map<String, String> get _headers => {
//         'Content-Type': 'application/json',
//         'Authorization': 'Token $authToken',
//       };

//   /// In-memory cache for products
//   static List<Product>? _cache;
//   static Future<void>? _warming;

//   bool get hasCache => _cache != null && _cache!.isNotEmpty;

//   /// Load *all* products into memory
//   Future<void> warmProducts({bool force = false}) async {
//     if (hasCache && !force) return;

//     if (_warming != null && !force) {
//       await _warming;
//       return;
//     }

//     _warming = _doWarmProducts();
//     try {
//       await _warming;
//     } finally {
//       _warming = null;
//     }
//   }

//   static List<Product> _parseProductsBody(String body) {
//     final decoded = jsonDecode(body);
//     final out = <Product>[];
//     if (decoded is List) {
//       for (final e in decoded) {
//         if (e is Map<String, dynamic>) out.add(Product.fromJson(e));
//       }
//     } else if (decoded is Map && decoded['results'] is List) {
//       for (final e in (decoded['results'] as List)) {
//         if (e is Map<String, dynamic>) out.add(Product.fromJson(e));
//       }
//     }
//     return out;
//   }

//   Future<void> _doWarmProducts() async {
//     final all = <Product>[];
//     Uri? uri = Uri.parse('${baseUrl}products/');

//     for (var hop = 0; hop < 500 && uri != null; hop++) {
//       final resp = await _client.get(uri, headers: _headers);
//       if (resp.statusCode < 200 || resp.statusCode >= 300) break;

//       final batch = resp.body.length > 40 * 1024
//           ? await compute(_parseProductsBody, resp.body)
//           : _parseProductsBody(resp.body);
//       all.addAll(batch);

//       final decoded = jsonDecode(resp.body);
//       if (decoded is Map &&
//           decoded['next'] != null &&
//           decoded['next'].toString().isNotEmpty) {
//         uri = Uri.parse(decoded['next'].toString());
//       } else {
//         uri = null;
//       }
//     }

//     if (all.isNotEmpty) {
//       all.sort((a, b) => a.nameLower.compareTo(b.nameLower));
//       _cache = all;
//     } else if (!hasCache) {
//       _cache = <Product>[];
//     }
//   }

//   /// Local filter
//   List<Product> filterProducts(String query, {int limit = 30}) {
//     if (!hasCache || query.trim().isEmpty) return <Product>[];
//     final q = query.toLowerCase();

//     final starts = <Product>[];
//     final contains = <Product>[];

//     for (final p in _cache!) {
//       final n = p.nameLower;
//       if (n.startsWith(q)) {
//         starts.add(p);
//       } else if (n.contains(q)) {
//         contains.add(p);
//       }
//       if (starts.length >= limit) break;
//     }

//     if (starts.length >= limit) return starts.take(limit).toList();

//     final combined = List<Product>.from(starts);
//     for (final p in contains) {
//       if (combined.length >= limit) break;
//       combined.add(p);
//     }
//     return combined;
//   }

//   Future<List<Product>> suggest(String query, {int limit = 30}) async {
//     if (!hasCache) {
//       await warmProducts();
//     }
//     return filterProducts(query, limit: limit);
//   }

//   /// Create a manual (POS) invoice
//   Future<InvoiceResult> createManualInvoice({
//     required List<CartLine> lines,
//     String? customerName,
//     String? customerPhone,
//     String paymentMethod = 'cash',
//     bool paid = true,
//     Map<String, dynamic>? extra,
//   }) async {
//     final total =
//         lines.fold<double>(0.0, (sum, l) => sum + (l.unitPrice * l.qty));

//     final payload = {
//       'items': lines.map((l) => l.toJson()).toList(),
//       'customer_name': (customerName ?? '').trim(),
//       'customer_phone': (customerPhone ?? '').trim(),
//       'payment_method': paymentMethod.toLowerCase(),
//       'paid': paid,
//       'paid_amount': paid ? total : 0,
//       'is_manual': true,
//       if (extra != null) ...extra,
//     };

//     final uri1 = Uri.parse('${baseUrl}pos/invoices/');
//     try {
//       final r1 = await _client.post(uri1,
//           headers: _headers, body: jsonEncode(payload));
//       final body = _safeMap(r1.body);
//       if (r1.statusCode != 404) {
//         return InvoiceResult.fromResponse(r1.statusCode, body);
//       }
//     } catch (_) {/* fallback */}

//     final uri2 = Uri.parse('${baseUrl}orders/');
//     try {
//       final r2 = await _client.post(uri2,
//           headers: _headers, body: jsonEncode(payload));
//       final body = _safeMap(r2.body);
//       return InvoiceResult.fromResponse(r2.statusCode, body);
//     } catch (e) {
//       return InvoiceResult(ok: false, message: 'Network error: $e');
//     }
//   }

//   /// ---------- NEW: Download daily sales report as Excel ----------
//   Future<String?> downloadDailySalesReport({required DateTime date}) async {
//     final dateStr = date.toIso8601String().split('T').first;
//     final uri =
//         Uri.parse('${baseUrl}reports/daily-sales/?date=$dateStr&format=xlsx');

//     final resp = await _client.get(uri, headers: {
//       'Authorization': 'Token $authToken', // no Content-Type for file download
//     });

//     if (resp.statusCode == 200) {
//       final dir = await getApplicationDocumentsDirectory();
//       final file = File('${dir.path}/sales_$dateStr.xlsx');
//       await file.writeAsBytes(resp.bodyBytes, flush: true);
//       return file.path;
//     } else {
//       throw Exception("Failed to download report: ${resp.statusCode}");
//     }
//   }

//   dynamic _safeJson(String s) {
//     try {
//       return jsonDecode(s);
//     } catch (_) {
//       return {'raw': s};
//     }
//   }

//   Map<String, dynamic> _safeMap(String s) {
//     final j = _safeJson(s);
//     return (j is Map<String, dynamic>) ? j : <String, dynamic>{'raw': j};
//   }
// }

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show compute;
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// ---------- Data models ----------
class Product {
  final int id;
  final String name;
  final String nameLower; // for faster filtering
  final double price; // unit price
  final String? unit; // e.g., kg, pcs

  Product({
    required this.id,
    required this.name,
    required this.nameLower,
    required this.price,
    this.unit,
  });

  factory Product.fromJson(Map<String, dynamic> j) {
    final rawPrice = j['price'] ?? j['unit_price'] ?? j['mrp'] ?? 0;
    final name = (j['name'] ?? j['title'] ?? '').toString();
    return Product(
      id: (j['id'] is int) ? j['id'] as int : int.tryParse('${j['id']}') ?? 0,
      name: name,
      nameLower: name.toLowerCase(),
      price: (rawPrice is num)
          ? rawPrice.toDouble()
          : double.tryParse(rawPrice.toString()) ?? 0.0,
      unit: j['unit']?.toString(),
    );
  }
}

class CartLine {
  final Product product;
  int qty;
  double unitPrice;

  CartLine({
    required this.product,
    this.qty = 1,
    double? unitPrice,
  }) : unitPrice = unitPrice ?? product.price;

  double get lineTotal => unitPrice * qty;

  Map<String, dynamic> toJson() => {
        'product_id': product.id,
        'name': product.name,
        'qty': qty,
        'unit_price': unitPrice,
        // DO NOT send line_total; backend computes it.
      };
}

class InvoiceResult {
  final bool ok;

  /// Normalized: prefer order_id, else fallback to invoice_id (kept for compat if backend adds it)
  final int? orderId;
  final String? invoiceNumber;
  final String? pdfUrl;
  final String? message;

  InvoiceResult({
    required this.ok,
    this.orderId,
    this.invoiceNumber,
    this.pdfUrl,
    this.message,
  });

  factory InvoiceResult.fromResponse(int status, Map<String, dynamic> j) {
    int? parseInt(dynamic v) =>
        (v is int) ? v : int.tryParse(v?.toString() ?? '');

    final ord = parseInt(j['order_id']);
    final inv = parseInt(j['invoice_id']);
    return InvoiceResult(
      ok: status >= 200 && status < 300,
      orderId: ord ?? inv,
      invoiceNumber: j['invoice_number']?.toString(),
      pdfUrl: j['pdf_url']?.toString(),
      message: (j['detail'] ?? j['message'] ?? '').toString(),
    );
  }
}

/// ---------- Service ----------
class BillingService {
  final String baseUrl; // e.g. https://your-backend/api/
  final String authToken; // DRF token
  final http.Client _client;

  BillingService({
    required this.baseUrl,
    required this.authToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Token $authToken',
      };

  /// In-memory cache for products
  static List<Product>? _cache;
  static Future<void>? _warming;

  bool get hasCache => _cache != null && _cache!.isNotEmpty;

  /// Load *all* products into memory
  Future<void> warmProducts({bool force = false}) async {
    if (hasCache && !force) return;

    if (_warming != null && !force) {
      await _warming;
      return;
    }

    _warming = _doWarmProducts();
    try {
      await _warming;
    } finally {
      _warming = null;
    }
  }

  static List<Product> _parseProductsBody(String body) {
    final decoded = jsonDecode(body);
    final out = <Product>[];
    if (decoded is List) {
      for (final e in decoded) {
        if (e is Map<String, dynamic>) out.add(Product.fromJson(e));
      }
    } else if (decoded is Map && decoded['results'] is List) {
      for (final e in (decoded['results'] as List)) {
        if (e is Map<String, dynamic>) out.add(Product.fromJson(e));
      }
    }
    return out;
  }

  Future<void> _doWarmProducts() async {
    final all = <Product>[];
    Uri? uri = Uri.parse('${baseUrl}products/');

    for (var hop = 0; hop < 500 && uri != null; hop++) {
      final resp = await _client.get(uri, headers: _headers);
      if (resp.statusCode < 200 || resp.statusCode >= 300) break;

      final batch = resp.body.length > 40 * 1024
          ? await compute(_parseProductsBody, resp.body)
          : _parseProductsBody(resp.body);
      all.addAll(batch);

      final decoded = jsonDecode(resp.body);
      if (decoded is Map &&
          decoded['next'] != null &&
          decoded['next'].toString().isNotEmpty) {
        uri = Uri.parse(decoded['next'].toString());
      } else {
        uri = null;
      }
    }

    if (all.isNotEmpty) {
      all.sort((a, b) => a.nameLower.compareTo(b.nameLower));
      _cache = all;
    } else if (!hasCache) {
      _cache = <Product>[]; // avoid null checks later
    }
  }

  /// Local filter
  List<Product> filterProducts(String query, {int limit = 30}) {
    if (!hasCache || query.trim().isEmpty) return <Product>[];
    final q = query.toLowerCase();

    final starts = <Product>[];
    final contains = <Product>[];

    for (final p in _cache!) {
      final n = p.nameLower;
      if (n.startsWith(q)) {
        starts.add(p);
      } else if (n.contains(q)) {
        contains.add(p);
      }
      if (starts.length >= limit) break;
    }

    if (starts.length >= limit) return starts.take(limit).toList();

    final combined = List<Product>.from(starts);
    for (final p in contains) {
      if (combined.length >= limit) break;
      combined.add(p);
    }
    return combined;
  }

  Future<List<Product>> suggest(String query, {int limit = 30}) async {
    if (!hasCache) {
      await warmProducts();
    }
    return filterProducts(query, limit: limit);
  }

  /// Create a manual (POS) invoice
  Future<InvoiceResult> createManualInvoice({
    required List<CartLine> lines,
    String? customerName,
    String? customerPhone,
    String paymentMethod = 'cash',
    bool paid = true,
    Map<String, dynamic>? extra,
  }) async {
    final total =
        lines.fold<double>(0.0, (sum, l) => sum + (l.unitPrice * l.qty));

    final payload = {
      'items': lines.map((l) => l.toJson()).toList(),
      'customer_name': (customerName ?? '').trim(),
      'customer_phone': (customerPhone ?? '').trim(),
      'payment_method': paymentMethod.toLowerCase(),
      'paid': paid,
      'paid_amount': paid ? total : 0,
      'is_manual': true,
      if (extra != null) ...extra,
    };

    final uri1 = Uri.parse('${baseUrl}pos/invoices/');
    try {
      final r1 = await _client.post(uri1,
          headers: _headers, body: jsonEncode(payload));
      final body = _safeMap(r1.body);
      if (r1.statusCode != 404) {
        return InvoiceResult.fromResponse(r1.statusCode, body);
      }
    } catch (_) {/* fallback */}

    final uri2 = Uri.parse('${baseUrl}orders/');
    try {
      final r2 = await _client.post(uri2,
          headers: _headers, body: jsonEncode(payload));
      final body = _safeMap(r2.body);
      return InvoiceResult.fromResponse(r2.statusCode, body);
    } catch (e) {
      return InvoiceResult(ok: false, message: 'Network error: $e');
    }
  }

  /// ---------- Download + Save + Open daily sales XLSX ----------
  /// Returns the saved file path.
  Future<String> downloadDailySalesReport({required DateTime date}) async {
    final dateStr = date.toIso8601String().split('T').first;
    final uri =
        Uri.parse('${baseUrl}reports/daily-sales/?date=$dateStr&format=xlsx');

    // Android: try to get storage permission for Downloads folder
    if (Platform.isAndroid) {
      final ok = await _ensureStoragePermission();
      if (!ok) {
        // We still proceed but will save to app documents folder
      }
    }

    final resp = await _client.get(uri, headers: {
      'Authorization': 'Token $authToken', // no JSON content-type for file
      'Accept': '*/*',
    });

    if (resp.statusCode != 200) {
      throw Exception("Failed to download report: ${resp.statusCode}");
    }

    // Determine target directory
    String path;
    if (Platform.isAndroid) {
      final downloads = Directory('/storage/emulated/0/Download');
      if (await downloads.exists() &&
          (await Permission.storage.status).isGranted) {
        final file = File('${downloads.path}/sales_$dateStr.xlsx');
        await file.writeAsBytes(resp.bodyBytes, flush: true);
        path = file.path;
      } else {
        // Fallback to app docs
        final doc = await getApplicationDocumentsDirectory();
        final file = File('${doc.path}/sales_$dateStr.xlsx');
        await file.writeAsBytes(resp.bodyBytes, flush: true);
        path = file.path;
      }
    } else {
      // iOS/desktop: app documents
      final doc = await getApplicationDocumentsDirectory();
      final file = File('${doc.path}/sales_$dateStr.xlsx');
      await file.writeAsBytes(resp.bodyBytes, flush: true);
      path = file.path;
    }

    // Try opening the file with Excel/Sheets app
    await OpenFilex.open(path);
    return path;
  }

  Future<bool> _ensureStoragePermission() async {
    final status = await Permission.storage.request();
    return status.isGranted;
  }

  dynamic _safeJson(String s) {
    try {
      return jsonDecode(s);
    } catch (_) {
      return {'raw': s};
    }
  }

  Map<String, dynamic> _safeMap(String s) {
    final j = _safeJson(s);
    return (j is Map<String, dynamic>) ? j : <String, dynamic>{'raw': j};
  }
}
