// import 'dart:io';
// import 'dart:typed_data';

// import 'package:file_picker/file_picker.dart';
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:open_filex/open_filex.dart';
// import 'package:path_provider/path_provider.dart';

// import '../api.dart';

// class StockPage extends StatefulWidget {
//   final Api api;
//   const StockPage({super.key, required this.api});

//   @override
//   State<StockPage> createState() => _StockPageState();
// }

// class _StockPageState extends State<StockPage> {
//   final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

//   bool _busy = false;
//   DateTimeRange? _range;
//   SalesReport? _report;

//   @override
//   void initState() {
//     super.initState();
//     // default range: last 7 days
//     final now = DateTime.now();
//     _range =
//         DateTimeRange(start: now.subtract(const Duration(days: 6)), end: now);
//   }

//   Future<void> _downloadStock() async {
//     setState(() => _busy = true);
//     try {
//       final sf = await widget.api.exportStockXlsx();

//       // Save to a temp app directory the user can open
//       final dir = await getTemporaryDirectory();
//       final path = '${dir.path}/${sf.filename}';
//       final file = File(path);
//       await file.writeAsBytes(sf.bytes, flush: true);

//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Saved: ${sf.filename}'),
//           action: SnackBarAction(
//             label: 'OPEN',
//             onPressed: () => OpenFilex.open(path),
//           ),
//         ),
//       );
//     } catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Export failed: $e')),
//       );
//     } finally {
//       if (mounted) setState(() => _busy = false);
//     }
//   }

//   Future<void> _uploadStock() async {
//     try {
//       final res = await FilePicker.platform.pickFiles(
//         type: FileType.custom,
//         allowedExtensions: const ['xlsx'],
//         withData: true,
//       );
//       if (res == null || res.files.isEmpty) return;

//       final f = res.files.first;
//       final Uint8List? bytes = f.bytes;
//       if (bytes == null) {
//         if (!mounted) return;
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Could not read file bytes')),
//         );
//         return;
//       }

//       setState(() => _busy = true);
//       await ref.read(apiProvider).uploadStockXlsx(bytes: bytes, filename: f.name);

//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Stock updated from ${f.name}')),
//       );
//     } catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Upload failed: $e')),
//       );
//     } finally {
//       if (mounted) setState(() => _busy = false);
//     }
//   }

//   Future<void> _quickAdjustDialog() async {
//     final idCtrl = TextEditingController();
//     final stockCtrl = TextEditingController();
//     final priceCtrl = TextEditingController();

//     final ok = await showDialog<bool>(
//       context: context,
//       builder: (ctx) => AlertDialog(
//         title: const Text('Quick Adjust Product'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             TextField(
//               controller: idCtrl,
//               keyboardType: TextInputType.number,
//               decoration: const InputDecoration(
//                 labelText: 'Product ID',
//               ),
//             ),
//             const SizedBox(height: 8),
//             TextField(
//               controller: stockCtrl,
//               keyboardType: TextInputType.number,
//               decoration: const InputDecoration(
//                 labelText: 'New stock (optional)',
//               ),
//             ),
//             const SizedBox(height: 8),
//             TextField(
//               controller: priceCtrl,
//               keyboardType:
//                   const TextInputType.numberWithOptions(decimal: true),
//               decoration: const InputDecoration(
//                 labelText: 'New price (optional)',
//               ),
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//               onPressed: () => Navigator.pop(ctx, false),
//               child: const Text('Cancel')),
//           FilledButton(
//               onPressed: () => Navigator.pop(ctx, true),
//               child: const Text('Update')),
//         ],
//       ),
//     );

//     if (ok != true) return;

//     final id = int.tryParse(idCtrl.text.trim());
//     final stock = stockCtrl.text.trim().isEmpty
//         ? null
//         : int.tryParse(stockCtrl.text.trim());
//     final price = priceCtrl.text.trim().isEmpty
//         ? null
//         : double.tryParse(priceCtrl.text.trim());

//     if (id == null) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Enter a valid Product ID')),
//       );
//       return;
//     }
//     if (stock == null && price == null) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Enter stock and/or price to update')),
//       );
//       return;
//     }

//     setState(() => _busy = true);
//     try {
//       await widget.api
//           .quickAdjustProduct(productId: id, stock: stock, price: price);
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Product updated')),
//       );
//     } catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Update failed: $e')),
//       );
//     } finally {
//       if (mounted) setState(() => _busy = false);
//     }
//   }

//   Future<void> _pickRange() async {
//     final r = await showDateRangePicker(
//       context: context,
//       firstDate: DateTime(2020, 1, 1),
//       lastDate: DateTime.now().add(const Duration(days: 1)),
//       initialDateRange: _range,
//     );
//     if (r != null) setState(() => _range = r);
//   }

//   Future<void> _loadReport() async {
//     final r = _range;
//     if (r == null) return;
//     setState(() => _busy = true);
//     try {
//       final rep = await widget.api.salesReport(from: r.start, to: r.end);
//       if (!mounted) return;
//       setState(() => _report = rep);
//     } catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Report failed: $e')),
//       );
//     } finally {
//       if (mounted) setState(() => _busy = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;
//     final r = _range;

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Stock & Reports'),
//         actions: [
//           if (_busy)
//             const Padding(
//               padding: EdgeInsets.only(right: 12),
//               child: Center(
//                   child: SizedBox(
//                       width: 18,
//                       height: 18,
//                       child: CircularProgressIndicator(strokeWidth: 2))),
//             ),
//         ],
//       ),
//       body: ListView(
//         padding: const EdgeInsets.all(12),
//         children: [
//           // Export
//           Card(
//             shape:
//                 RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//             child: ListTile(
//               leading: CircleAvatar(
//                   backgroundColor: cs.primaryContainer,
//                   child: const Icon(Icons.download)),
//               title: const Text('Download current stock (XLSX)'),
//               subtitle: const Text('Export products with quantities & prices'),
//               trailing: FilledButton.icon(
//                 onPressed: _busy ? null : _downloadStock,
//                 icon: const Icon(Icons.download_rounded),
//                 label: const Text('Export'),
//               ),
//             ),
//           ),
//           const SizedBox(height: 12),

//           // Upload
//           Card(
//             shape:
//                 RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//             child: ListTile(
//               leading: CircleAvatar(
//                   backgroundColor: cs.secondaryContainer,
//                   child: const Icon(Icons.upload_file)),
//               title: const Text('Upload stock (XLSX)'),
//               subtitle: const Text('Update quantities/prices in bulk'),
//               trailing: FilledButton.icon(
//                 onPressed: _busy ? null : _uploadStock,
//                 icon: const Icon(Icons.upload),
//                 label: const Text('Upload'),
//               ),
//             ),
//           ),
//           const SizedBox(height: 12),

//           // Quick adjust
//           Card(
//             shape:
//                 RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//             child: ListTile(
//               leading: CircleAvatar(
//                   backgroundColor: cs.tertiaryContainer,
//                   child: const Icon(Icons.tune)),
//               title: const Text('Quick adjust one product'),
//               subtitle: const Text('Change stock and/or price by Product ID'),
//               trailing: OutlinedButton.icon(
//                 onPressed: _busy ? null : _quickAdjustDialog,
//                 icon: const Icon(Icons.edit),
//                 label: const Text('Adjust'),
//               ),
//             ),
//           ),
//           const SizedBox(height: 12),

//           // Sales report
//           Card(
//             shape:
//                 RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//             child: Padding(
//               padding: const EdgeInsets.all(12.0),
//               child: Column(
//                 children: [
//                   Row(
//                     children: [
//                       Expanded(
//                         child: Text(
//                           r == null
//                               ? 'Pick date range'
//                               : 'Range: ${DateFormat('dd MMM').format(r.start)} — ${DateFormat('dd MMM').format(r.end)}',
//                           style: const TextStyle(fontWeight: FontWeight.w600),
//                         ),
//                       ),
//                       OutlinedButton.icon(
//                         onPressed: _busy ? null : _pickRange,
//                         icon: const Icon(Icons.date_range),
//                         label: const Text('Pick'),
//                       ),
//                       const SizedBox(width: 8),
//                       FilledButton.icon(
//                         onPressed: (_busy || r == null) ? null : _loadReport,
//                         icon: const Icon(Icons.bar_chart),
//                         label: const Text('Load'),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 12),
//                   if (_report != null) _buildReport(_report!),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildReport(SalesReport rep) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Wrap(
//           spacing: 12,
//           runSpacing: 12,
//           children: [
//             _statTile('Orders', rep.totalOrders.toString()),
//             _statTile('Items', rep.totalItems.toString()),
//             _statTile('Revenue', _money.format(rep.totalRevenue)),
//           ],
//         ),
//         const SizedBox(height: 12),
//         const Align(
//           alignment: Alignment.centerLeft,
//           child: Text('Top Sellers',
//               style: TextStyle(fontWeight: FontWeight.w700)),
//         ),
//         const SizedBox(height: 6),
//         ...rep.top.map((t) => ListTile(
//               dense: true,
//               leading: CircleAvatar(
//                 child: Text(
//                   t.qty.toString(),
//                   style: const TextStyle(fontWeight: FontWeight.w700),
//                 ),
//               ),
//               title: Text(t.name),
//               trailing: Text(_money.format(t.revenue)),
//               subtitle: Text('Product #${t.productId}'),
//             )),
//       ],
//     );
//   }

//   Widget _statTile(String label, String value) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(10),
//         color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
//       ),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Text(value,
//               style:
//                   const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
//           const SizedBox(height: 2),
//           Text(label),
//         ],
//       ),
//     );
//   }
// }
// lib/stock/stock_page.dart
// import 'dart:io';
// import 'dart:typed_data';

// import 'package:file_picker/file_picker.dart';
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:open_filex/open_filex.dart';
// import 'package:path_provider/path_provider.dart';

// import '../api.dart';

// class StockPage extends StatefulWidget {
//   final Api api;
//   const StockPage({super.key, required this.api});

//   @override
//   State<StockPage> createState() => _StockPageState();
// }

// class _StockPageState extends State<StockPage> {
//   final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

//   bool _busy = false;
//   DateTimeRange? _range;
//   SalesReport? _report;

//   @override
//   void initState() {
//     super.initState();
//     final now = DateTime.now();
//     _range = DateTimeRange(
//       start: DateTime(now.year, now.month, now.day)
//           .subtract(const Duration(days: 6)),
//       end: now,
//     );
//   }

//   Future<void> _downloadStock() async {
//     setState(() => _busy = true);
//     try {
//       final sf = await widget.api.downloadStockXlsx();

//       final dir = await getTemporaryDirectory();
//       final path = '${dir.path}/${sf.filename}';
//       final file = File(path);
//       await file.writeAsBytes(sf.bytes, flush: true);

//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Saved: ${sf.filename}'),
//           action: SnackBarAction(
//             label: 'OPEN',
//             onPressed: () => OpenFilex.open(path),
//           ),
//         ),
//       );
//     } catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Export failed: $e')),
//       );
//     } finally {
//       if (mounted) setState(() => _busy = false);
//     }
//   }

//   Future<void> _uploadStock() async {
//     try {
//       final res = await FilePicker.platform.pickFiles(
//         type: FileType.custom,
//         allowedExtensions: const ['xlsx'],
//         withData: true,
//       );
//       if (res == null || res.files.isEmpty) return;

//       final f = res.files.first;
//       Uint8List? bytes = f.bytes;

//       // Fallback to read from path if bytes are null (Android sometimes)
//       if (bytes == null && f.path != null) {
//         bytes = await File(f.path!).readAsBytes();
//       }

//       if (bytes == null) {
//         if (!mounted) return;
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Could not read file bytes')),
//         );
//         return;
//       }

//       setState(() => _busy = true);
//       await ref.read(apiProvider).uploadStockXlsx(bytes: bytes, filename: f.name);

//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Stock updated from ${f.name}')),
//       );
//     } catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Upload failed: $e')),
//       );
//     } finally {
//       if (mounted) setState(() => _busy = false);
//     }
//   }

//   Future<void> _quickAdjustDialog() async {
//     final idCtrl = TextEditingController();
//     final stockCtrl = TextEditingController();
//     final priceCtrl = TextEditingController();

//     final ok = await showDialog<bool>(
//       context: context,
//       builder: (ctx) => AlertDialog(
//         title: const Text('Quick Adjust Product'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             TextField(
//               controller: idCtrl,
//               keyboardType: TextInputType.number,
//               decoration: const InputDecoration(labelText: 'Product ID'),
//             ),
//             const SizedBox(height: 8),
//             TextField(
//               controller: stockCtrl,
//               keyboardType: TextInputType.number,
//               decoration:
//                   const InputDecoration(labelText: 'New stock (optional)'),
//             ),
//             const SizedBox(height: 8),
//             TextField(
//               controller: priceCtrl,
//               keyboardType:
//                   const TextInputType.numberWithOptions(decimal: true),
//               decoration:
//                   const InputDecoration(labelText: 'New price (optional)'),
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//               onPressed: () => Navigator.pop(ctx, false),
//               child: const Text('Cancel')),
//           FilledButton(
//               onPressed: () => Navigator.pop(ctx, true),
//               child: const Text('Update')),
//         ],
//       ),
//     );

//     if (ok != true) return;

//     final id = int.tryParse(idCtrl.text.trim());
//     final stock = stockCtrl.text.trim().isEmpty
//         ? null
//         : int.tryParse(stockCtrl.text.trim());
//     final price = priceCtrl.text.trim().isEmpty
//         ? null
//         : double.tryParse(priceCtrl.text.trim());

//     if (id == null) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Enter a valid Product ID')),
//       );
//       return;
//     }
//     if (stock == null && price == null) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Enter stock and/or price to update')),
//       );
//       return;
//     }

//     setState(() => _busy = true);
//     try {
//       await widget.api
//           .updateProductSingle(productId: id, stock: stock, price: price);
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Product updated')),
//       );
//     } catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Update failed: $e')),
//       );
//     } finally {
//       if (mounted) setState(() => _busy = false);
//     }
//   }

//   Future<void> _pickRange() async {
//     final r = await showDateRangePicker(
//       context: context,
//       firstDate: DateTime(2020, 1, 1),
//       lastDate: DateTime.now().add(const Duration(days: 1)),
//       initialDateRange: _range,
//     );
//     if (r != null) setState(() => _range = r);
//   }

//   Future<void> _loadReport() async {
//     final r = _range;
//     if (r == null) return;
//     setState(() => _busy = true);
//     try {
//       final rep = await widget.api.salesReport(from: r.start, to: r.end);
//       if (!mounted) return;
//       setState(() => _report = rep);
//     } catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Report failed: $e')),
//       );
//     } finally {
//       if (mounted) setState(() => _busy = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;
//     final r = _range;

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Stock & Reports'),
//         actions: [
//           if (_busy)
//             const Padding(
//               padding: EdgeInsets.only(right: 12),
//               child: Center(
//                 child: SizedBox(
//                     width: 18,
//                     height: 18,
//                     child: CircularProgressIndicator(strokeWidth: 2)),
//               ),
//             ),
//         ],
//       ),
//       body: ListView(
//         padding: const EdgeInsets.all(12),
//         children: [
//           // Export
//           Card(
//             shape:
//                 RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//             child: ListTile(
//               leading: CircleAvatar(
//                   backgroundColor: cs.primaryContainer,
//                   child: const Icon(Icons.download)),
//               title: const Text('Download current stock (XLSX)'),
//               subtitle: const Text('Export products with quantities & prices'),
//               trailing: FilledButton.icon(
//                 onPressed: _busy ? null : _downloadStock,
//                 icon: const Icon(Icons.download_rounded),
//                 label: const Text('Export'),
//               ),
//             ),
//           ),
//           const SizedBox(height: 12),

//           // Upload
//           Card(
//             shape:
//                 RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//             child: ListTile(
//               leading: CircleAvatar(
//                   backgroundColor: cs.secondaryContainer,
//                   child: const Icon(Icons.upload_file)),
//               title: const Text('Upload stock (XLSX)'),
//               subtitle: const Text('Update quantities/prices in bulk'),
//               trailing: FilledButton.icon(
//                 onPressed: _busy ? null : _uploadStock,
//                 icon: const Icon(Icons.upload),
//                 label: const Text('Upload'),
//               ),
//             ),
//           ),
//           const SizedBox(height: 12),

//           // Quick adjust
//           Card(
//             shape:
//                 RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//             child: ListTile(
//               leading: CircleAvatar(
//                   backgroundColor: cs.tertiaryContainer,
//                   child: const Icon(Icons.tune)),
//               title: const Text('Quick adjust one product'),
//               subtitle: const Text('Change stock and/or price by Product ID'),
//               trailing: OutlinedButton.icon(
//                 onPressed: _busy ? null : _quickAdjustDialog,
//                 icon: const Icon(Icons.edit),
//                 label: const Text('Adjust'),
//               ),
//             ),
//           ),
//           const SizedBox(height: 12),

//           // Sales report
//           Card(
//             shape:
//                 RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//             child: Padding(
//               padding: const EdgeInsets.all(12.0),
//               child: Column(
//                 children: [
//                   Row(
//                     children: [
//                       Expanded(
//                         child: Text(
//                           r == null
//                               ? 'Pick date range'
//                               : 'Range: ${DateFormat('dd MMM').format(r.start)} — ${DateFormat('dd MMM').format(r.end)}',
//                           style: const TextStyle(fontWeight: FontWeight.w600),
//                         ),
//                       ),
//                       OutlinedButton.icon(
//                         onPressed: _busy ? null : _pickRange,
//                         icon: const Icon(Icons.date_range),
//                         label: const Text('Pick'),
//                       ),
//                       const SizedBox(width: 8),
//                       FilledButton.icon(
//                         onPressed: (_busy || r == null) ? null : _loadReport,
//                         icon: const Icon(Icons.bar_chart),
//                         label: const Text('Load'),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 12),
//                   if (_report != null) _buildReport(_report!),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildReport(SalesReport rep) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Wrap(
//           spacing: 12,
//           runSpacing: 12,
//           children: [
//             _statTile('Orders', rep.totalOrders.toString()),
//             _statTile('Items', rep.totalItems.toString()),
//             _statTile('Revenue', _money.format(rep.totalRevenue)),
//           ],
//         ),
//         const SizedBox(height: 12),
//         const Align(
//           alignment: Alignment.centerLeft,
//           child: Text('Top Sellers',
//               style: TextStyle(fontWeight: FontWeight.w700)),
//         ),
//         const SizedBox(height: 6),
//         ...rep.top.map(
//           (t) => ListTile(
//             dense: true,
//             leading: CircleAvatar(
//               child: Text(t.qty.toString(),
//                   style: const TextStyle(fontWeight: FontWeight.w700)),
//             ),
//             title: Text(t.name),
//             trailing: Text(_money.format(t.revenue)),
//             subtitle: Text('Product #${t.productId}'),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _statTile(String label, String value) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(10),
//         color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
//       ),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Text(value,
//               style:
//                   const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
//           const SizedBox(height: 2),
//           Text(label),
//         ],
//       ),
//     );
//   }
// }

// lib/stock/stock_page.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/api.dart';
import '../../providers/api_provider.dart';
import '../../shared/app_ui.dart';
import '../announcement/announcement_page.dart';
import '../store/store_status_page.dart';

class StockPage extends ConsumerStatefulWidget {
  const StockPage({super.key});

  @override
  ConsumerState<StockPage> createState() => _StockPageState();
}

class _StockPageState extends ConsumerState<StockPage> {
  final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  bool _busy = false;
  DateTime _day = DateTime.now();
  DailySales? _report;

  Future<void> _downloadStock() async {
    setState(() => _busy = true);
    try {
      final sf = await ref.read(apiProvider).downloadStockXlsx();

      // Save into a writable temp (user can open)
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/${sf.filename}';
      final file = File(path);
      await file.writeAsBytes(sf.bytes, flush: true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved: ${sf.filename}'),
          action: SnackBarAction(
            label: 'OPEN',
            onPressed: () => OpenFilex.open(path),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _uploadStock() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
        withData: true,
      );
      if (res == null || res.files.isEmpty) return;

      final f = res.files.first;
      Uint8List? bytes = f.bytes;

      // If bytes null (rare on Android), read from path.
      if (bytes == null && f.path != null) {
        bytes = await File(f.path!).readAsBytes();
      }

      if (bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read file bytes')),
        );
        return;
      }

      setState(() => _busy = true);
      await ref.read(apiProvider).uploadStockXlsx(bytes: bytes, filename: f.name);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stock updated from ${f.name}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _quickAdjustDialog() async {
    ProductLite? chosen;
    final stockCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    Uint8List? newImageBytes;
    String? newImagePath;
    String? newImageName;
    bool uploadingImage = false;

    await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Adjust Product'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Product',
                    hintText: 'Tap to choose',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: chosen == null
                        ? null
                        : Tooltip(
                            message:
                                'ID ${chosen!.id} • Stock ${chosen!.stock} • ₹${chosen!.price}',
                            child: const Icon(Icons.info_outline),
                          ),
                  ),
                  onTap: () async {
                    final p = await showModalBottomSheet<ProductLite>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const _ProductSearchSheet(),
                    );
                    if (p != null) {
                      setD(() {
                        chosen = p;
                        stockCtrl.text = p.stock.toString();
                        priceCtrl.text = p.price.toString();
                        newImageBytes = null;
                        newImagePath = null;
                        newImageName = null;
                      });
                    }
                  },
                ),
                if (chosen != null) ...[
                  const SizedBox(height: 16),
                  const Text('Product Image',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: uploadingImage
                        ? null
                        : () async {
                            try {
                              final res =
                                  await FilePicker.platform.pickFiles(
                                type: FileType.image,
                                withData: true,
                              );
                              if (res != null && res.files.isNotEmpty) {
                                final f = res.files.first;
                                setD(() {
                                  newImageBytes = f.bytes;
                                  newImagePath = f.path;
                                  newImageName = f.name;
                                });
                              }
                            } catch (e) {
                              if (!ctx.mounted) return;
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          },
                    child: Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey.shade50,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (newImageBytes != null)
                            Image.memory(newImageBytes!, fit: BoxFit.contain)
                          else if (chosen?.imageUrl != null)
                            CachedNetworkImage(
                              imageUrl: chosen!.imageUrl!,
                              fit: BoxFit.contain,
                              memCacheWidth: 600,
                            )
                          else
                            const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo_outlined, size: 32),
                                Text('Tap to upload'),
                              ],
                            ),
                          if (uploadingImage)
                            Container(
                              color: Colors.white70,
                              child: const CircularProgressIndicator(),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (newImageName != null && !uploadingImage)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text('Selected: $newImageName', style: const TextStyle(fontSize: 10, color: Colors.blue)),
                    ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  TextField(
                    controller: stockCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Stock Quantity'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: priceCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Price (₹)'),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL'),
            ),
            if (chosen != null)
              ElevatedButton(
                onPressed: uploadingImage
                    ? null
                    : () async {
                        final s = int.tryParse(stockCtrl.text);
                        final p = double.tryParse(priceCtrl.text);
                        if (s == null || p == null) return;

                        setD(() => uploadingImage = true);
                        try {
                          await ref.read(apiProvider).updateProductFull(
                            productId: chosen!.id,
                            stock: s,
                            price: p,
                            imageBytes: newImageBytes,
                            imagePath: newImagePath,
                            imageName: newImageName,
                          );
                          if (!mounted) return;
                          final messenger = ScaffoldMessenger.of(context);
                          if (ctx.mounted) Navigator.pop(ctx, true);
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Product updated')),
                          );
                        } catch (e) {
                          setD(() => uploadingImage = false);
                          if (!ctx.mounted) return;
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Update failed: $e')),
                          );
                        }
                      },
                child: const Text('SAVE'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(2023, 1, 1),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDate: _day,
    );
    if (d != null) setState(() => _day = d);
  }

  Future<void> _loadReport() async {
    setState(() => _busy = true);
    try {
      final rep = await ref.read(apiProvider).dailySalesJson(_day);
      if (!mounted) return;
      setState(() => _report = rep);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Report failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock & Reports'),
        actions: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(
                child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Live home-screen message
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: CircleAvatar(
                  backgroundColor: cs.primaryContainer,
                  child: const Icon(Icons.campaign_outlined)),
              title: const Text('Home message'),
              subtitle:
                  const Text('Live message shown on the customer home screen'),
              trailing: OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AnnouncementPage(),
                          ),
                        ),
                icon: const Icon(Icons.edit),
                label: const Text('Edit'),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Order acceptance (maintenance toggle)
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: CircleAvatar(
                  backgroundColor: cs.tertiaryContainer,
                  child: const Icon(Icons.storefront_outlined)),
              title: const Text('Order acceptance'),
              subtitle: const Text(
                  'Pause new customer orders (maintenance / closed time)'),
              trailing: OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const StoreStatusPage(),
                          ),
                        ),
                icon: const Icon(Icons.tune),
                label: const Text('Manage'),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Export
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: CircleAvatar(
                  backgroundColor: cs.primaryContainer,
                  child: const Icon(Icons.download)),
              title: const Text('Download current stock (XLSX)'),
              subtitle: const Text('Export products with quantities & prices'),
              trailing: FilledButton.icon(
                onPressed: _busy ? null : _downloadStock,
                icon: const Icon(Icons.download_rounded),
                label: const Text('Export'),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Upload
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: CircleAvatar(
                  backgroundColor: cs.secondaryContainer,
                  child: const Icon(Icons.upload_file)),
              title: const Text('Upload stock (XLSX)'),
              subtitle: const Text('Update quantities/prices in bulk'),
              trailing: FilledButton.icon(
                onPressed: _busy ? null : _uploadStock,
                icon: const Icon(Icons.upload),
                label: const Text('Upload'),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Quick adjust with product picker
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: CircleAvatar(
                  backgroundColor: cs.tertiaryContainer,
                  child: const Icon(Icons.tune)),
              title: const Text('Quick adjust one product'),
              subtitle: const Text('Search by name, change stock and/or price'),
              trailing: OutlinedButton.icon(
                onPressed: _busy ? null : _quickAdjustDialog,
                icon: const Icon(Icons.edit),
                label: const Text('Adjust'),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Daily sales
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  // Wrap so the action buttons drop below the date on narrow
                  // widths / large text scales instead of overflowing the row.
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      AppText(
                        'Day: ${DateFormat('dd MMM yyyy').format(_day)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _busy ? null : _pickDay,
                            icon: const Icon(Icons.date_range),
                            label: const Text('Pick Day'),
                          ),
                          FilledButton.icon(
                            onPressed: _busy ? null : _loadReport,
                            icon: const Icon(Icons.bar_chart),
                            label: const Text('Load'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_report != null) _buildReport(_report!),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReport(DailySales rep) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _statTile('Orders', rep.orders.toString()),
            _statTile('Units', rep.unitsSold.toString()),
            _statTile('Revenue', _money.format(rep.revenue)),
          ],
        ),
        const SizedBox(height: 12),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('Top Sellers',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 6),
        ...rep.byProduct.map(
          (t) => AppListCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            elevation: 0,
            leading: CircleAvatar(
              child: AppText(
                t.quantity.toString(),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            title: AppText(t.name),
            subtitle: AppText('Product #${t.productId} • ${t.category ?? "-"}'),
            trailing: [AppText(_money.format(t.amount))],
          ),
        ),
      ],
    );
  }

  Widget _statTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        // use withValues to avoid deprecation warning
        color: Theme.of(context)
            .colorScheme
            .primaryContainer
            .withValues(alpha: 0.35),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label),
        ],
      ),
    );
  }
}

/// Bottom sheet to search products (name) and choose one.
class _ProductSearchSheet extends ConsumerStatefulWidget {
  const _ProductSearchSheet();

  @override
  ConsumerState<_ProductSearchSheet> createState() => _ProductSearchSheetState();
}

class _ProductSearchSheetState extends ConsumerState<_ProductSearchSheet> {
  final _q = TextEditingController();
  List<ProductLite> _results = [];
  bool _loading = false;
  Timer? _deb;

  @override
  void dispose() {
    _q.dispose();
    _deb?.cancel();
    super.dispose();
  }

  void _search(String s) {
    _deb?.cancel();
    _deb = Timer(const Duration(milliseconds: 250), () async {
      if (!mounted) return;
      setState(() => _loading = true);
      try {
        final r = await ref.read(apiProvider).searchProducts(s, limit: 30);
        if (!mounted) return;
        setState(() => _results = r);
      } catch (_) {
        if (!mounted) return;
        setState(() => _results = []);
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  controller: _q,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Search products',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: _search,
                ),
              ),
              const SizedBox(height: 8),
              if (_loading) const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (_, i) {
                    final p = _results[i];
                    return ListTile(
                      title: AppText(p.name),
                      subtitle:
                          AppText('ID ${p.id} • Stock ${p.stock} • ₹${p.price}'),
                      onTap: () => Navigator.pop(context, p),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
