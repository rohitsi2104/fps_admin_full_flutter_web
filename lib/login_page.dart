// import 'package:flutter/material.dart';
// import 'api.dart';
// import 'auth_store.dart';

// class LoginPage extends StatefulWidget {
//   final Api api;
//   final AuthStore store;
//   final VoidCallback onLoggedIn;
//   const LoginPage({super.key, required this.api, required this.store, required this.onLoggedIn});

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
//     setState(() { _loading = true; _error = null; });
//     try {
//       final token = await widget.api.login(phone: _phoneCtrl.text.trim(), password: _passCtrl.text);
//       await widget.store.save(token);
//       widget.onLoggedIn();
//     } catch (e) {
//       setState(() { _error = e.toString(); });
//     } finally {
//       if (mounted) setState(() { _loading = false; });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Admin Login')),
//       body: Center(
//         child: ConstrainedBox(
//           constraints: const BoxConstraints(maxWidth: 420),
//           child: Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: Form(
//               key: _formKey,
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   TextFormField(
//                     controller: _phoneCtrl,
//                     decoration: const InputDecoration(labelText: 'Phone'),
//                     keyboardType: TextInputType.phone,
//                     validator: (v) => (v==null || v.trim().isEmpty) ? 'Enter phone' : null,
//                   ),
//                   const SizedBox(height: 12),
//                   TextFormField(
//                     controller: _passCtrl,
//                     decoration: const InputDecoration(labelText: 'Password'),
//                     obscureText: true,
//                     validator: (v) => (v==null || v.isEmpty) ? 'Enter password' : null,
//                   ),
//                   const SizedBox(height: 20),
//                   if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
//                   const SizedBox(height: 8),
//                   SizedBox(
//                     width: double.infinity,
//                     child: ElevatedButton.icon(
//                       onPressed: _loading ? null : _submit,
//                       icon: _loading ? const SizedBox(
//                         width: 16, height: 16,
//                         child: CircularProgressIndicator(strokeWidth: 2),
//                       ) : const Icon(Icons.login),
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

// import 'package:flutter/material.dart';
// import 'api.dart';
// import 'auth_store.dart';
// import 'config.dart'; // for kBaseUrl
// import 'services/push_service.dart'; // <-- add this

// class LoginPage extends StatefulWidget {
//   final Api api;
//   final AuthStore store;
//   final VoidCallback onLoggedIn;
//   const LoginPage(
//       {super.key,
//       required this.api,
//       required this.store,
//       required this.onLoggedIn});

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
//       final token = await widget.api.login(
//         phone: _phoneCtrl.text.trim(),
//         password: _passCtrl.text,
//       );

//       // Save auth token
//       await widget.store.save(token);

//       // 🔔 Request permission + register device token as ADMIN
//       try {
//         await PushService.ensurePermissions();
//         await PushService.registerDeviceWithBackend(
//           backendBaseUrl:
//               kBaseUrl, // e.g. https://fps-dayalbagh-backend.vercel.app/api
//           authToken: token,
//           isAdmin: true, // <-- important for shopkeeper app
//         );
//       } catch (_) {
//         // ignore – don’t block login
//       }

//       widget.onLoggedIn();
//     } catch (e) {
//       setState(() {
//         _error = e.toString();
//       });
//     } finally {
//       if (mounted)
//         setState(() {
//           _loading = false;
//         });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     // ... (rest of your widget tree unchanged)
//     // keep your existing code
//     return Scaffold(
//       appBar: AppBar(title: const Text('Admin Login')),
//       body: Center(
//         child: ConstrainedBox(
//           constraints: const BoxConstraints(maxWidth: 420),
//           child: Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: Form(
//               key: _formKey,
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   TextFormField(
//                     controller: _phoneCtrl,
//                     decoration: const InputDecoration(labelText: 'Phone'),
//                     keyboardType: TextInputType.phone,
//                     validator: (v) =>
//                         (v == null || v.trim().isEmpty) ? 'Enter phone' : null,
//                   ),
//                   const SizedBox(height: 12),
//                   TextFormField(
//                     controller: _passCtrl,
//                     decoration: const InputDecoration(labelText: 'Password'),
//                     obscureText: true,
//                     validator: (v) =>
//                         (v == null || v.isEmpty) ? 'Enter password' : null,
//                   ),
//                   const SizedBox(height: 20),
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
//                               child: CircularProgressIndicator(strokeWidth: 2))
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

// lib/login_page.dart
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
      // 1) Authenticate
      final token = await widget.api.login(
        phone: _phoneCtrl.text.trim(),
        password: _passCtrl.text,
      );

      // 2) Persist token
      await widget.store.save(token);

      // 3) Register FCM device for admin + subscribe to future token changes
      try {
        await PushService.ensurePermissions();
        await PushService.registerDeviceWithBackend(
          backendBaseUrl: kBaseUrl, // e.g. https://host/api
          authToken: token,
          isAdmin: true, // <-- admin build
        );
        PushService.subscribeTokenRefresh(
          backendBaseUrl: kBaseUrl,
          getAuthToken: () async => widget.store.token,
          isAdmin: true,
        );
      } catch (_) {
        // Don’t block login on push issues
      }

      // 4) Continue to app
      if (mounted) widget.onLoggedIn();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Login')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Phone'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Enter phone' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Enter password' : null,
                  ),
                  const SizedBox(height: 18),
                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _submit,
                      icon: _loading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
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
    );
  }
}
