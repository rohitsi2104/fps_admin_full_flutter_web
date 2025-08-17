// // lib/main.dart
// import 'dart:async';
// import 'dart:convert';

// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;

// import 'api.dart';
// import 'auth_store.dart';
// import 'config.dart';
// import 'login_page.dart';
// import 'orders_list_page.dart';

// // POS + Billing (NEW paths)
// import 'pos/billing_service.dart';
// import 'pos/pos_screen.dart';

// // Firebase / FCM
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'firebase_options.dart';

// // Local notifications
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// /// ---------- Local notifications setup ----------
// final FlutterLocalNotificationsPlugin _local =
//     FlutterLocalNotificationsPlugin();

// const AndroidNotificationChannel _androidChannel = AndroidNotificationChannel(
//   'high_importance_channel',
//   'High Importance Notifications',
//   description: 'Notifies admins/shopkeepers about new orders',
//   importance: Importance.high,
//   playSound: true,
// );

// /// ---------- FCM background handler (separate isolate) ----------
// @pragma('vm:entry-point')
// Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//   if (Firebase.apps.isEmpty) {
//     await Firebase.initializeApp(
//       options: DefaultFirebaseOptions.currentPlatform,
//     );
//   }
// }

// Future<void> _ensureFirebaseInitialized() async {
//   if (Firebase.apps.isEmpty) {
//     await Firebase.initializeApp(
//       options: DefaultFirebaseOptions.currentPlatform,
//     );
//   }
// }

// /// Register this device's FCM token with your Django backend
// Future<void> _registerDeviceTokenWithBackend({
//   required String baseUrl,
//   required String authToken,
//   required String fcmToken,
//   bool isAdmin = true,
// }) async {
//   final uri = Uri.parse('$baseUrl/api/me/devices/');
//   final body = jsonEncode({
//     'token': fcmToken,
//     'platform': 'android', // or 'ios'
//     'is_admin': isAdmin,
//   });

//   final resp = await http.post(
//     uri,
//     headers: {
//       'Content-Type': 'application/json',
//       'Authorization': 'Token $authToken',
//     },
//     body: body,
//   );

//   if (resp.statusCode >= 400) {
//     debugPrint('Device register failed: ${resp.statusCode} ${resp.body}');
//   }
// }

// /// Show a local notification while app is in foreground
// Future<void> _showForegroundNotification({
//   required String title,
//   required String body,
//   Map<String, dynamic>? data,
// }) async {
//   final notificationDetails = NotificationDetails(
//     android: AndroidNotificationDetails(
//       _androidChannel.id,
//       _androidChannel.name,
//       channelDescription: _androidChannel.description,
//       importance: Importance.high,
//       priority: Priority.high,
//       icon: '@mipmap/ic_launcher',
//     ),
//     iOS: const DarwinNotificationDetails(
//       presentAlert: true,
//       presentSound: true,
//     ),
//   );

//   final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
//   await _local.show(
//     id,
//     title,
//     body,
//     notificationDetails,
//     payload: data == null ? null : jsonEncode(data),
//   );
// }

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();

//   // Firebase core
//   await _ensureFirebaseInitialized();

//   // Background handler
//   FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

//   // Local notifications init
//   const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
//   const iosSettings = DarwinInitializationSettings();
//   const initSettings =
//       InitializationSettings(android: androidSettings, iOS: iosSettings);
//   await _local.initialize(initSettings);

//   final androidImpl = _local.resolvePlatformSpecificImplementation<
//       AndroidFlutterLocalNotificationsPlugin>();
//   if (androidImpl != null) {
//     await androidImpl.createNotificationChannel(_androidChannel);
//     await androidImpl.requestNotificationsPermission(); // Android 13+
//   }

//   // iOS foreground presentation options
//   await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
//     alert: true,
//     badge: true,
//     sound: true,
//   );

//   runZonedGuarded(() {
//     runApp(const Bootstrap());
//   }, (e, st) {
//     debugPrint('Uncaught error: $e\n$st');
//   });
// }

// class Bootstrap extends StatefulWidget {
//   const Bootstrap({super.key});
//   @override
//   State<Bootstrap> createState() => _BootstrapState();
// }

// class _BootstrapState extends State<Bootstrap> {
//   late final AuthStore _store = AuthStore();
//   Api? _api;
//   BillingService? _billing; // <-- built with a concrete token
//   bool _loading = true;
//   Object? _initError;

//   StreamSubscription<RemoteMessage>? _onMessageSub;
//   StreamSubscription<String>? _tokenRefreshSub;

//   @override
//   void initState() {
//     super.initState();
//     _initAsync();
//   }

//   @override
//   void dispose() {
//     _onMessageSub?.cancel();
//     _tokenRefreshSub?.cancel();
//     super.dispose();
//   }

//   Future<void> _initAsync() async {
//     try {
//       await _store.load(); // load saved token (admin auth)
//       _api = Api(baseUrl: kBaseUrl, token: _store.token);

//       // Build BillingService with whatever token we currently have
//       _billing = BillingService(
//         baseUrl: kBaseUrl,
//         authToken: _store.token ?? '',
//       );

//       // Only register device once user is logged in (has token)
//       if (_store.token != null && _store.token!.isNotEmpty) {
//         // Get current FCM token
//         final fcmToken = await FirebaseMessaging.instance.getToken();
//         if (fcmToken != null && fcmToken.isNotEmpty) {
//           await _registerDeviceTokenWithBackend(
//             baseUrl: kBaseUrl,
//             authToken: _store.token!,
//             fcmToken: fcmToken,
//             isAdmin: true,
//           );
//         }

//         // Re-register on token refresh
//         _tokenRefreshSub =
//             FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
//           if (_store.token != null && _store.token!.isNotEmpty) {
//             await _registerDeviceTokenWithBackend(
//               baseUrl: kBaseUrl,
//               authToken: _store.token!,
//               fcmToken: newToken,
//               isAdmin: true,
//             );
//           }
//         });

//         // Foreground messages → local notification
//         _onMessageSub =
//             FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
//           final title = message.notification?.title ??
//               (message.data['title'] ?? 'Update');
//           final body =
//               message.notification?.body ?? (message.data['body'] ?? 'Message');
//           await _showForegroundNotification(
//             title: title,
//             body: body,
//             data: message.data,
//           );
//         });

//         // Notification tap → open chooser
//         FirebaseMessaging.onMessageOpenedApp.listen((message) {
//           if (_store.token != null && _store.token!.isNotEmpty && mounted) {
//             Navigator.of(context).push(
//               MaterialPageRoute(
//                 builder: (_) => ModeChooserPage(api: _api!, billing: _billing!),
//               ),
//             );
//           }
//         });
//       }
//     } catch (e) {
//       _initError = e;
//     } finally {
//       if (mounted) setState(() => _loading = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final theme = ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green);

//     if (_loading) {
//       return MaterialApp(
//         debugShowCheckedModeBanner: false,
//         theme: theme,
//         home: const Scaffold(
//           body: Center(child: CircularProgressIndicator()),
//         ),
//       );
//     }

//     if (_initError != null || _api == null || _billing == null) {
//       return MaterialApp(
//         debugShowCheckedModeBanner: false,
//         theme: theme,
//         home: Scaffold(
//           body: Center(
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 const Icon(Icons.error_outline, size: 48),
//                 const SizedBox(height: 12),
//                 Text('Startup failed: $_initError'),
//                 const SizedBox(height: 12),
//                 ElevatedButton(
//                   onPressed: () {
//                     setState(() {
//                       _loading = true;
//                       _initError = null;
//                     });
//                     _initAsync();
//                   },
//                   child: const Text('Retry'),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       );
//     }

//     final loggedIn = _store.token != null && _store.token!.isNotEmpty;
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       theme: theme,
//       home: loggedIn
//           ? ModeChooserPage(api: _api!, billing: _billing!)
//           : LoginPage(
//               api: _api!,
//               store: _store,
//               onLoggedIn: () async {
//                 // After login, (re)register push token and rebuild billing with new token
//                 final fcmToken = await FirebaseMessaging.instance.getToken();
//                 if (fcmToken != null && fcmToken.isNotEmpty) {
//                   await _registerDeviceTokenWithBackend(
//                     baseUrl: kBaseUrl,
//                     authToken: _store.token!,
//                     fcmToken: fcmToken,
//                     isAdmin: true,
//                   );
//                 }
//                 setState(() {
//                   _billing = BillingService(
//                     baseUrl: kBaseUrl,
//                     authToken: _store.token ?? '',
//                   );
//                 });
//               },
//             ),
//     );
//   }
// }

// /// Landing with two big actions
// class ModeChooserPage extends StatelessWidget {
//   final Api api;
//   final BillingService billing;
//   const ModeChooserPage({super.key, required this.api, required this.billing});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('FPS Admin • Choose Mode')),
//       body: Padding(
//         padding: const EdgeInsets.all(16),
//         child: LayoutBuilder(
//           builder: (context, constraints) {
//             final isWide = constraints.maxWidth > 700;
//             final children = [
//               _ModeTile(
//                 icon: Icons.point_of_sale_rounded,
//                 title: 'Manual Billing',
//                 subtitle: 'Generate in-store bills',
//                 color: Colors.indigo,
//                 onTap: () {
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(
//                       builder: (_) => PosScreen(service: billing),
//                     ),
//                   );
//                 },
//               ),
//               _ModeTile(
//                 icon: Icons.receipt_long_rounded,
//                 title: 'Online Billing',
//                 subtitle: 'Manage online orders',
//                 color: Colors.green,
//                 onTap: () {
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(
//                       builder: (_) => OrdersListPage(api: api),
//                     ),
//                   );
//                 },
//               ),
//             ];

//             return isWide
//                 ? Row(
//                     children: [
//                       Expanded(child: children[0]),
//                       const SizedBox(width: 16),
//                       Expanded(child: children[1]),
//                     ],
//                   )
//                 : ListView.separated(
//                     itemCount: children.length,
//                     separatorBuilder: (_, __) => const SizedBox(height: 16),
//                     itemBuilder: (_, i) => children[i],
//                   );
//           },
//         ),
//       ),
//     );
//   }
// }

// class _ModeTile extends StatelessWidget {
//   final IconData icon;
//   final String title;
//   final String subtitle;
//   final Color color;
//   final VoidCallback onTap;

//   const _ModeTile({
//     required this.icon,
//     required this.title,
//     required this.subtitle,
//     required this.color,
//     required this.onTap,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Card(
//       elevation: 1.5,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       child: InkWell(
//         borderRadius: BorderRadius.circular(16),
//         onTap: onTap,
//         child: Padding(
//           padding: const EdgeInsets.all(18),
//           child: Row(
//             children: [
//               CircleAvatar(
//                 radius: 28,
//                 backgroundColor: color.withValues(alpha: 0.10),
//                 child: Icon(icon, size: 30, color: color),
//               ),
//               const SizedBox(width: 16),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(title,
//                         style: const TextStyle(
//                             fontSize: 18, fontWeight: FontWeight.w700)),
//                     const SizedBox(height: 6),
//                     Text(
//                       subtitle,
//                       style: TextStyle(
//                         color: Colors.black.withValues(alpha: 0.60),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               const Icon(Icons.chevron_right),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api.dart';
import 'auth_store.dart';
import 'config.dart';
import 'login_page.dart';
import 'orders_list_page.dart';

// POS + Billing
import 'pos/billing_service.dart';
import 'pos/pos_screen.dart';

// Firebase / FCM
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';

// Local notifications
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// ---------- Local notifications setup ----------
final FlutterLocalNotificationsPlugin _local =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel _androidChannel = AndroidNotificationChannel(
  'high_importance_channel',
  'High Importance Notifications',
  description: 'Notifies admins/shopkeepers about new orders',
  importance: Importance.high,
  playSound: true,
);

/// ---------- FCM background handler ----------
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}

Future<void> _ensureFirebaseInitialized() async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}

/// Register this device's FCM token with your Django backend
Future<void> _registerDeviceTokenWithBackend({
  required String baseUrl,
  required String authToken,
  required String fcmToken,
  bool isAdmin = true,
}) async {
  final uri = Uri.parse('$baseUrl/api/me/devices/');
  final body = jsonEncode({
    'token': fcmToken,
    'platform': 'android', // or 'ios'
    'is_admin': isAdmin,
  });

  final resp = await http.post(
    uri,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Token $authToken',
    },
    body: body,
  );

  if (resp.statusCode >= 400) {
    debugPrint('Device register failed: ${resp.statusCode} ${resp.body}');
  }
}

/// Show a local notification while app is in foreground
Future<void> _showForegroundNotification({
  required String title,
  required String body,
  Map<String, dynamic>? data,
}) async {
  final notificationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      _androidChannel.id,
      _androidChannel.name,
      channelDescription: _androidChannel.description,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    ),
    iOS: const DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
    ),
  );

  final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  await _local.show(
    id,
    title,
    body,
    notificationDetails,
    payload: data == null ? null : jsonEncode(data),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _ensureFirebaseInitialized();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings();
  const initSettings =
      InitializationSettings(android: androidSettings, iOS: iosSettings);
  await _local.initialize(initSettings);

  final androidImpl = _local.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  if (androidImpl != null) {
    await androidImpl.createNotificationChannel(_androidChannel);
    await androidImpl.requestNotificationsPermission();
  }

  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  runZonedGuarded(() {
    runApp(const Bootstrap());
  }, (e, st) {
    debugPrint('Uncaught error: $e\n$st');
  });
}

class Bootstrap extends StatefulWidget {
  const Bootstrap({super.key});
  @override
  State<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<Bootstrap> {
  late final AuthStore _store = AuthStore();
  Api? _api;
  BillingService? _billing;
  bool _loading = true;
  Object? _initError;

  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<String>? _tokenRefreshSub;

  @override
  void initState() {
    super.initState();
    _initAsync();
  }

  @override
  void dispose() {
    _onMessageSub?.cancel();
    _tokenRefreshSub?.cancel();
    super.dispose();
  }

  Future<void> _initAsync() async {
    try {
      await _store.load();
      _api = Api(baseUrl: kBaseUrl, token: _store.token);
      _billing =
          BillingService(baseUrl: kBaseUrl, authToken: _store.token ?? '');

      if (_store.token != null && _store.token!.isNotEmpty) {
        final fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null && fcmToken.isNotEmpty) {
          await _registerDeviceTokenWithBackend(
            baseUrl: kBaseUrl,
            authToken: _store.token!,
            fcmToken: fcmToken,
            isAdmin: true,
          );
        }

        _tokenRefreshSub =
            FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
          if (_store.token != null && _store.token!.isNotEmpty) {
            await _registerDeviceTokenWithBackend(
              baseUrl: kBaseUrl,
              authToken: _store.token!,
              fcmToken: newToken,
              isAdmin: true,
            );
          }
        });

        _onMessageSub =
            FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
          final title = message.notification?.title ??
              (message.data['title'] ?? 'Update');
          final body =
              message.notification?.body ?? (message.data['body'] ?? 'Message');
          await _showForegroundNotification(
            title: title,
            body: body,
            data: message.data,
          );
        });

        FirebaseMessaging.onMessageOpenedApp.listen((message) {
          if (_store.token != null && _store.token!.isNotEmpty && mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ModeChooserPage(api: _api!, billing: _billing!),
              ),
            );
          }
        });
      }
    } catch (e) {
      _initError = e;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = _appTheme();

    if (_loading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_initError != null || _api == null || _billing == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 12),
                Text('Startup failed: $_initError'),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _loading = true;
                      _initError = null;
                    });
                    _initAsync();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final loggedIn = _store.token != null && _store.token!.isNotEmpty;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: loggedIn
          ? ModeChooserPage(api: _api!, billing: _billing!)
          : LoginPage(
              api: _api!,
              store: _store,
              onLoggedIn: () async {
                final fcmToken = await FirebaseMessaging.instance.getToken();
                if (fcmToken != null && fcmToken.isNotEmpty) {
                  await _registerDeviceTokenWithBackend(
                    baseUrl: kBaseUrl,
                    authToken: _store.token!,
                    fcmToken: fcmToken,
                    isAdmin: true,
                  );
                }
                setState(() {
                  _billing = BillingService(
                    baseUrl: kBaseUrl,
                    authToken: _store.token ?? '',
                  );
                });
              },
            ),
    );
  }

  ThemeData _appTheme() {
    // soothing aqua/teal seed
    const seed = Color(0xFF06B6D4); // cyan-500 vibes
    final cs =
        ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light);

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0.5,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.primary, width: 1.4),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        surfaceTintColor: cs.surfaceTint,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: cs.inverseSurface,
        contentTextStyle: TextStyle(color: cs.onInverseSurface),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        ),
      ),
    );
  }
}

/// Landing with two big actions
class ModeChooserPage extends StatelessWidget {
  final Api api;
  final BillingService billing;
  const ModeChooserPage({super.key, required this.api, required this.billing});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget tile({
      required IconData icon,
      required String title,
      required String subtitle,
      required Color color,
      required VoidCallback onTap,
    }) {
      return Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: color.withValues(alpha: 0.10),
                  child: Icon(icon, size: 30, color: color),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('FPS Admin • Choose Mode')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;
            final children = [
              tile(
                icon: Icons.point_of_sale_rounded,
                title: 'Manual Billing',
                subtitle: 'Generate in-store bills',
                color: cs.primary,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PosScreen(service: billing),
                    ),
                  );
                },
              ),
              tile(
                icon: Icons.receipt_long_rounded,
                title: 'Online Billing',
                subtitle: 'Manage online orders',
                color: cs.secondary,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OrdersListPage(api: api),
                    ),
                  );
                },
              ),
            ];

            return isWide
                ? Row(
                    children: [
                      Expanded(child: children[0]),
                      const SizedBox(width: 16),
                      Expanded(child: children[1]),
                    ],
                  )
                : ListView.separated(
                    itemCount: children.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (_, i) => children[i],
                  );
          },
        ),
      ),
    );
  }
}
