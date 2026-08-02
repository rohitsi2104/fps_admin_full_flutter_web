import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/api_provider.dart';

/// Admin editor for the "accepting orders" toggle + pause message shown to
/// customers when the store isn't taking orders (maintenance mode).
class StoreStatusPage extends ConsumerStatefulWidget {
  const StoreStatusPage({super.key});

  @override
  ConsumerState<StoreStatusPage> createState() => _StoreStatusPageState();
}

class _StoreStatusPageState extends ConsumerState<StoreStatusPage> {
  final _formKey = GlobalKey<FormState>();
  final _msgCtrl = TextEditingController();

  bool _accepting = true;
  bool _loading = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await ref.read(apiProvider).getStoreStatus();
      if (!mounted) return;
      _msgCtrl.text = s.pauseMessage;
      _accepting = s.acceptingOrders;
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(apiProvider).setStoreStatus(
            acceptingOrders: _accepting,
            pauseMessage: _msgCtrl.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_accepting
              ? 'Store is now accepting orders'
              : 'Store is PAUSED — customers cannot place orders'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final paused = !_accepting;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order acceptance'),
        actions: [
          IconButton(
            tooltip: 'Reload',
            onPressed: _loading || _saving ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Current-state banner
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: paused
                                    ? cs.errorContainer
                                    : cs.primaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    paused
                                        ? Icons.pause_circle_filled
                                        : Icons.check_circle,
                                    color: paused
                                        ? cs.onErrorContainer
                                        : cs.onPrimaryContainer,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      paused
                                          ? 'Not accepting orders'
                                          : 'Accepting orders',
                                      style: TextStyle(
                                        color: paused
                                            ? cs.onErrorContainer
                                            : cs.onPrimaryContainer,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _accepting,
                              onChanged: _saving
                                  ? null
                                  : (v) => setState(() => _accepting = v),
                              title: const Text('Accept new online orders'),
                              subtitle: Text(
                                _accepting
                                    ? 'Customers can place orders as normal'
                                    : 'Customers see a pause message and cannot check out',
                                style: TextStyle(
                                    color: cs.onSurfaceVariant, fontSize: 12),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _msgCtrl,
                              minLines: 2,
                              maxLines: 5,
                              maxLength: 300,
                              decoration: const InputDecoration(
                                labelText: 'Message shown to customers when paused',
                                alignLabelWithHint: true,
                                border: OutlineInputBorder(),
                                hintText:
                                    'e.g. Closed for stock intake. Back at 5 PM.',
                              ),
                              validator: (v) {
                                if (!_accepting &&
                                    (v == null || v.trim().isEmpty)) {
                                  return 'Enter a message so customers know why';
                                }
                                return null;
                              },
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 8),
                              Text(_error!,
                                  style:
                                      TextStyle(color: cs.error, fontSize: 13)),
                            ],
                            const SizedBox(height: 8),
                            FilledButton.icon(
                              onPressed: _saving ? null : _save,
                              icon: _saving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.save),
                              label: const Text('Save'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
