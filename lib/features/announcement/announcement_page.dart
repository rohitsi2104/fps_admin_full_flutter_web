import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/api_provider.dart';

/// Admin editor for the live message shown on the client app's home screen.
class AnnouncementPage extends ConsumerStatefulWidget {
  const AnnouncementPage({super.key});

  @override
  ConsumerState<AnnouncementPage> createState() => _AnnouncementPageState();
}

class _AnnouncementPageState extends ConsumerState<AnnouncementPage> {
  final _formKey = GlobalKey<FormState>();
  final _msgCtrl = TextEditingController();

  bool _isActive = true;
  bool _notify = true; // push to client devices on save
  bool _loading = false; // initial fetch
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
      final a = await ref.read(apiProvider).getAnnouncement();
      if (!mounted) return;
      _msgCtrl.text = a.message;
      _isActive = a.isActive;
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await ref.read(apiProvider).setAnnouncement(
            message: _msgCtrl.text.trim(),
            isActive: _isActive,
            notify: _notify && _isActive,
          );
      if (!mounted) return;
      final msg = (_notify && _isActive)
          ? 'Home message updated · notified ${result.notified} '
              '${result.notified == 1 ? 'device' : 'devices'}'
          : 'Home message updated';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _saving = false);
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home message'),
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
                            Text(
                              'Live message on customer home screen',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Shown as a card at the top of the app. Turn off to hide the card without deleting the text.',
                              style: TextStyle(
                                  color: cs.onSurfaceVariant, fontSize: 13),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _msgCtrl,
                              minLines: 3,
                              maxLines: 6,
                              maxLength: 500,
                              decoration: const InputDecoration(
                                labelText: 'Message',
                                alignLabelWithHint: true,
                                border: OutlineInputBorder(),
                                hintText:
                                    'e.g. Store closed on Sunday for inventory.',
                              ),
                              validator: (v) {
                                if (_isActive &&
                                    (v == null || v.trim().isEmpty)) {
                                  return 'Enter a message or turn the card off';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 4),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _isActive,
                              onChanged: _saving
                                  ? null
                                  : (v) => setState(() => _isActive = v),
                              title: const Text('Show on home screen'),
                            ),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              controlAffinity:
                                  ListTileControlAffinity.leading,
                              value: _notify && _isActive,
                              onChanged: (_saving || !_isActive)
                                  ? null
                                  : (v) => setState(() => _notify = v ?? false),
                              title: const Text('Notify users'),
                              subtitle: Text(
                                _isActive
                                    ? 'Send a push notification to all customers on save'
                                    : 'Turn the card on to notify users',
                                style: TextStyle(
                                    color: cs.onSurfaceVariant, fontSize: 12),
                              ),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 8),
                              Text(_error!,
                                  style:
                                      TextStyle(color: cs.error, fontSize: 13)),
                            ],
                            const SizedBox(height: 16),
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
