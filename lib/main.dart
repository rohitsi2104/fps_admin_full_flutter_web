// import 'dart:async';
// import 'package:flutter/material.dart';

// import 'api.dart';
// import 'auth_store.dart';
// import 'config.dart';
// import 'login_page.dart';
// import 'orders_list_page.dart';

// void main() {
//   // Render immediately; do async setup inside the widget.
//   runZonedGuarded(() {
//     runApp(const Bootstrap());
//   }, (e, st) {
//     // Optionally log errors
//   });
// }

// class Bootstrap extends StatefulWidget {
//   const Bootstrap({super.key}); // ✅ satisfies use_key_in_widget_constructors
//   @override
//   State<Bootstrap> createState() => _BootstrapState();
// }

// class _BootstrapState extends State<Bootstrap> {
//   late final AuthStore _store = AuthStore();
//   Api? _api;
//   bool _loading = true;
//   Object? _initError;

//   @override
//   void initState() {
//     super.initState();
//     _initAsync();
//   }

//   Future<void> _initAsync() async {
//     try {
//       await _store.load(); // load saved token
//       _api = Api(baseUrl: kBaseUrl, token: _store.token);
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

//     if (_initError != null || _api == null) {
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

//     final loggedIn = _store.token != null;
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       theme: theme,
//       home: loggedIn
//           ? OrdersListPage(api: _api!)
//           : LoginPage(
//               api: _api!,
//               store: _store,
//               onLoggedIn: () => setState(() {}),
//             ),
//     );
//   }
// }

// lib/main.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api.dart';
import 'auth_store.dart';
import 'config.dart';
import 'login_page.dart';
import 'orders_list_page.dart';

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

/// ---------- FCM background handler (separate isolate) ----------
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase in background isolate if needed
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  }

  // If your server sends a `notification` payload, Android will display it.
  // If your server sends only data, and you want a local notification here as well,
  // you can optionally init and show one — often not required for admin use.
  // (Foreground notifications are handled in-app below.)
}

Future<void> _ensureFirebaseInitialized() async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
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
    'platform': 'android', // or 'ios' if you ship iOS
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
    // You can surface an error toast/snackbar as needed, but don't crash.
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

  // Use a unique id so multiple notifications can stack
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

  // Firebase core
  await _ensureFirebaseInitialized();

  // Background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Local notifications: Android channel & initialization
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings();
  const initSettings =
      InitializationSettings(android: androidSettings, iOS: iosSettings);
  await _local.initialize(initSettings);

  final androidImpl = _local.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  if (androidImpl != null) {
    await androidImpl.createNotificationChannel(_androidChannel);
    // Android 13+ permission:
    await androidImpl.requestNotificationsPermission();
  }

  // iOS foreground presentation options
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  runZonedGuarded(() {
    runApp(const Bootstrap());
  }, (e, st) {
    // Optionally log errors
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
      await _store.load(); // load saved token (admin auth)
      _api = Api(baseUrl: kBaseUrl, token: _store.token);

      // Only register device once user is logged in (has token)
      if (_store.token != null && _store.token!.isNotEmpty) {
        // Get current FCM token
        final fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null && fcmToken.isNotEmpty) {
          await _registerDeviceTokenWithBackend(
            baseUrl: kBaseUrl,
            authToken: _store.token!,
            fcmToken: fcmToken,
            isAdmin: true,
          );
        }

        // Re-register on token refresh
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

        // Foreground messages → show local notification
        _onMessageSub =
            FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
          final title = message.notification?.title ??
              (message.data['title'] ?? 'New update');
          final body = message.notification?.body ??
              (message.data['body'] ?? 'You have a message');
          await _showForegroundNotification(
            title: title,
            body: body,
            data: message.data,
          );
        });

        // When user taps a notification → app opened
        FirebaseMessaging.onMessageOpenedApp.listen((message) {
          // You can deep-link or refresh orders here
          // For now we just navigate to the orders list if logged in:
          if (_store.token != null && _store.token!.isNotEmpty && mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => OrdersListPage(api: _api!)),
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
    final theme = ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green);

    if (_loading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_initError != null || _api == null) {
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
          ? OrdersListPage(api: _api!)
          : LoginPage(
              api: _api!,
              store: _store,
              onLoggedIn: () async {
                // After login, (re)register push token
                final fcmToken = await FirebaseMessaging.instance.getToken();
                if (fcmToken != null && fcmToken.isNotEmpty) {
                  await _registerDeviceTokenWithBackend(
                    baseUrl: kBaseUrl,
                    authToken: _store.token!,
                    fcmToken: fcmToken,
                    isAdmin: true,
                  );
                }
                if (mounted) setState(() {});
              },
            ),
    );
  }
}
