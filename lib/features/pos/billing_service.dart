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
//         // IMPORTANT: don't send line_total; backend doesn't expect it
//       };
// }

// class InvoiceResult {
//   final bool ok;
//   final int? invoiceId;
//   final String? invoiceNumber;
//   final String? status;
//   final String? total;
//   final String? paidAmount;
//   final String? message;

//   InvoiceResult({
//     required this.ok,
//     this.invoiceId,
//     this.invoiceNumber,
//     this.status,
//     this.total,
//     this.paidAmount,
//     this.message,
//   });

//   factory InvoiceResult.fromResponse(int statusCode, Map<String, dynamic> j) {
//     return InvoiceResult(
//       ok: statusCode >= 200 && statusCode < 300,
//       invoiceId: (j['invoice_id'] is int)
//           ? j['invoice_id']
//           : int.tryParse('${j['invoice_id'] ?? ''}'),
//       invoiceNumber: j['invoice_number']?.toString(),
//       status: j['status']?.toString(),
//       total: j['total']?.toString(),
//       paidAmount: j['paid_amount']?.toString(),
//       message: (j['detail'] ?? j['message'] ?? '').toString(),
//     );
//   }
// }

// /// ---------- Service ----------
// class BillingService {
//   final String baseUrl; // e.g. https://fps-dayalbagh-backend.vercel.app/api/
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

//   Future<void> _doWarmProducts() async {
//     final all = <Product>[];
//     Uri? uri = Uri.parse('${baseUrl}products/');

//     for (var hop = 0; hop < 200 && uri != null; hop++) {
//       final resp = await _client.get(uri, headers: _headers);
//       if (resp.statusCode < 200 || resp.statusCode >= 300) break;

//       final body = _safeJson(resp.body);
//       if (body is List) {
//         all.addAll(body.map<Product>((e) => Product.fromJson(e)));
//         uri = null;
//       } else if (body is Map) {
//         if (body['results'] is List) {
//           all.addAll((body['results'] as List)
//               .map<Product>((e) => Product.fromJson(e)));
//         }
//         final next = (body['next'] ?? '').toString();
//         uri = next.isNotEmpty ? Uri.parse(next) : null;
//       } else {
//         break;
//       }
//     }

//     all.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
//     _cache = all;
//   }

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

//   Future<List<Product>> suggest(String query, {int limit = 30}) async {
//     if (!hasCache) await warmProducts();
//     return filterProducts(query, limit: limit);
//   }

//   /// Create a manual (POS) invoice against /api/pos/invoices/
//   Future<InvoiceResult> createManualInvoice({
//     required List<CartLine> lines,
//     String? customerName,
//     String? customerPhone,
//     String paymentMethod = 'cash', // send lowercase to match backend choices
//     bool paid = true,
//     Map<String, dynamic>? extra,
//   }) async {
//     // compute full total if you want to capture immediately
//     final total = lines.fold<double>(0.0, (s, l) => s + l.lineTotal);

//     final payload = {
//       'items': lines.map((l) => l.toJson()).toList(),
//       'customer_name': (customerName ?? '').trim(),
//       'customer_phone': (customerPhone ?? '').trim(),
//       'payment_method': (paymentMethod).toLowerCase(),
//       'paid': paid,
//       'paid_amount':
//           paid ? total : 0, // backend will also auto-fill if 0 + paid=true
//       if (extra != null) ...extra,
//     };

//     final uri = Uri.parse('${baseUrl}pos/invoices/');
//     try {
//       final r =
//           await _client.post(uri, headers: _headers, body: jsonEncode(payload));
//       final body = _safeMap(r.body);
//       return InvoiceResult.fromResponse(r.statusCode, body);
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
import 'dart:convert';
import 'package:flutter/foundation.dart' show compute;
import 'package:http/http.dart' as http;

/// ---------- Data models ----------
class Product {
  final int id;
  final String name;
  final String nameLower; // precomputed for faster filtering
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
        // IMPORTANT: don't send line_total; backend doesn't expect it
      };
}

class InvoiceResult {
  final bool ok;
  final int? invoiceId;
  final String? invoiceNumber;
  final String? status;
  final String? total;
  final String? paidAmount;
  final String? message;

  InvoiceResult({
    required this.ok,
    this.invoiceId,
    this.invoiceNumber,
    this.status,
    this.total,
    this.paidAmount,
    this.message,
  });

  factory InvoiceResult.fromResponse(int statusCode, Map<String, dynamic> j) {
    return InvoiceResult(
      ok: statusCode >= 200 && statusCode < 300,
      invoiceId: (j['invoice_id'] is int)
          ? j['invoice_id']
          : int.tryParse('${j['invoice_id'] ?? ''}'),
      invoiceNumber: j['invoice_number']?.toString(),
      status: j['status']?.toString(),
      total: j['total']?.toString(),
      paidAmount: j['paid_amount']?.toString(),
      message: (j['detail'] ?? j['message'] ?? '').toString(),
    );
  }
}

/// ---------- Service ----------
class BillingService {
  final String baseUrl; // e.g. https://host/api/
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

  // Parse JSON on a background isolate if it looks large.
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

    for (var hop = 0; hop < 200 && uri != null; hop++) {
      final resp = await _client.get(uri, headers: _headers);
      if (resp.statusCode < 200 || resp.statusCode >= 300) break;

      // If response is big, parse off the UI thread.
      List<Product> batch;
      if (resp.body.length > 40 * 1024) {
        batch = await compute(_parseProductsBody, resp.body);
      } else {
        batch = _parseProductsBody(resp.body);
      }
      all.addAll(batch);

      // pagination
      final decoded = jsonDecode(resp.body);
      if (decoded is Map &&
          decoded['next'] != null &&
          decoded['next'].toString().isNotEmpty) {
        uri = Uri.parse(decoded['next'].toString());
      } else {
        uri = null;
      }
    }

    all.sort((a, b) => a.nameLower.compareTo(b.nameLower));
    _cache = all;
  }

  List<Product> filterProducts(String query, {int limit = 30}) {
    if (!hasCache || query.trim().isEmpty) return <Product>[];
    final q = query.toLowerCase();

    final starts = <Product>[];
    final contains = <Product>[];

    // minimize allocations by using precomputed nameLower
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

    // top-up with contains
    final combined = List<Product>.from(starts);
    for (final p in contains) {
      if (combined.length >= limit) break;
      combined.add(p);
    }
    return combined;
  }

  Future<List<Product>> suggest(String query, {int limit = 30}) async {
    if (!hasCache) await warmProducts();
    return filterProducts(query, limit: limit);
  }

  /// Create a manual (POS) invoice against /api/pos/invoices/
  Future<InvoiceResult> createManualInvoice({
    required List<CartLine> lines,
    String? customerName,
    String? customerPhone,
    String paymentMethod = 'cash', // lowercase to match backend
    bool paid = true,
    Map<String, dynamic>? extra,
  }) async {
    final total = lines.fold<double>(0.0, (s, l) => s + l.lineTotal);

    final payload = {
      'items': lines.map((l) => l.toJson()).toList(),
      'customer_name': (customerName ?? '').trim(),
      'customer_phone': (customerPhone ?? '').trim(),
      'payment_method': paymentMethod.toLowerCase(),
      'paid': paid,
      'paid_amount': paid ? total : 0,
      if (extra != null) ...extra,
    };

    final uri = Uri.parse('${baseUrl}pos/invoices/');
    try {
      final r =
          await _client.post(uri, headers: _headers, body: jsonEncode(payload));
      final body = _safeMap(r.body);
      return InvoiceResult.fromResponse(r.statusCode, body);
    } catch (e) {
      return InvoiceResult(ok: false, message: 'Network error: $e');
    }
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
