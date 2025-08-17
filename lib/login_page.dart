// import 'package:flutter/material.dart';

// import 'api.dart';
// import 'auth_store.dart';
// import 'config.dart'; // kBaseUrl
// import 'services/push_service.dart';

// class LoginPage extends StatefulWidget {
//   final Api api;
//   final AuthStore store;
//   final VoidCallback onLoggedIn;

//   const LoginPage({
//     super.key,
//     required this.api,
//     required this.store,
//     required this.onLoggedIn,
//   });

//   @override
//   State<LoginPage> createState() => _LoginPageState();
// }

// class _LoginPageState extends State<LoginPage> {
//   final _formKey = GlobalKey<FormState>();
//   final _phoneCtrl = TextEditingController();
//   final _passCtrl = TextEditingController();

//   bool _loading = false;
//   String? _error;

//   Future<void> _submit() async {
//     if (!_formKey.currentState!.validate()) return;

//     setState(() {
//       _loading = true;
//       _error = null;
//     });

//     try {
//       // 1) Authenticate
//       final token = await widget.api.login(
//         phone: _phoneCtrl.text.trim(),
//         password: _passCtrl.text,
//       );

//       // 2) Persist token
//       await widget.store.save(token);

//       // 3) Register FCM device (admin) + subscribe to future token changes
//       try {
//         await PushService.ensurePermissions();
//         await PushService.registerDeviceWithBackend(
//           backendBaseUrl: kBaseUrl, // e.g. https://host/api
//           authToken: token,
//           isAdmin: true, // <-- admin build
//         );
//         PushService.subscribeTokenRefresh(
//           backendBaseUrl: kBaseUrl,
//           getAuthToken: () async => widget.store.token,
//           isAdmin: true,
//         );
//       } catch (_) {
//         // Don’t block login on push issues
//       }

//       // 4) Continue to app
//       if (!mounted) return;
//       widget.onLoggedIn();
//     } catch (e) {
//       if (!mounted) return;
//       setState(() => _error = e.toString());
//     } finally {
//       if (!mounted) return;
//       setState(() => _loading = false);
//     }
//   }

//   @override
//   void dispose() {
//     _phoneCtrl.dispose();
//     _passCtrl.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Admin Login')),
//       body: Center(
//         child: ConstrainedBox(
//           constraints: const BoxConstraints(maxWidth: 420),
//           child: Padding(
//             padding: const EdgeInsets.all(16),
//             child: Form(
//               key: _formKey,
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   TextFormField(
//                     controller: _phoneCtrl,
//                     keyboardType: TextInputType.phone,
//                     decoration: const InputDecoration(labelText: 'Phone'),
//                     validator: (v) =>
//                         (v == null || v.trim().isEmpty) ? 'Enter phone' : null,
//                   ),
//                   const SizedBox(height: 12),
//                   TextFormField(
//                     controller: _passCtrl,
//                     obscureText: true,
//                     decoration: const InputDecoration(labelText: 'Password'),
//                     validator: (v) =>
//                         (v == null || v.isEmpty) ? 'Enter password' : null,
//                   ),
//                   const SizedBox(height: 18),
//                   if (_error != null)
//                     Text(_error!, style: const TextStyle(color: Colors.red)),
//                   const SizedBox(height: 8),
//                   SizedBox(
//                     width: double.infinity,
//                     child: ElevatedButton.icon(
//                       onPressed: _loading ? null : _submit,
//                       icon: _loading
//                           ? const SizedBox(
//                               width: 16,
//                               height: 16,
//                               child: CircularProgressIndicator(strokeWidth: 2),
//                             )
//                           : const Icon(Icons.login),
//                       label: const Text('Login'),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
import 'package:flutter/material.dart';

import 'api.dart';
import 'auth_store.dart';
import 'config.dart'; // kBaseUrl
import 'services/push_service.dart';

class LoginPage extends StatefulWidget {
  final Api api;
  final AuthStore store;
  final VoidCallback onLoggedIn;

  const LoginPage({
    super.key,
    required this.api,
    required this.store,
    required this.onLoggedIn,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = await widget.api.login(
        phone: _phoneCtrl.text.trim(),
        password: _passCtrl.text,
      );

      await widget.store.save(token);

      try {
        await PushService.ensurePermissions();
        await PushService.registerDeviceWithBackend(
          backendBaseUrl: kBaseUrl,
          authToken: token,
          isAdmin: true,
        );
        PushService.subscribeTokenRefresh(
          backendBaseUrl: kBaseUrl,
          getAuthToken: () async => widget.store.token,
          isAdmin: true,
        );
      } catch (_) {}

      if (!mounted) return;
      widget.onLoggedIn();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Login')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Welcome back',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone',
                          prefixIcon: Icon(Icons.phone),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Enter phone'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Enter password' : null,
                      ),
                      const SizedBox(height: 18),
                      if (_error != null)
                        Text(_error!,
                            style: TextStyle(color: cs.error, fontSize: 13)),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _loading ? null : _submit,
                          icon: _loading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.login),
                          label: const Text('Login'),
                        ),
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
