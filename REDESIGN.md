# FPS Admin App — Redesign Plan

## Current State (Problems)

- **No state management** — everything is `StatefulWidget` with local state passed as constructor args. Logging in requires manual `setState` ripple all the way up.
- **No routing** — raw `Navigator.push` with constructor injection. Deep links and auth guards are impossible.
- **God widget** — `main.dart` owns the API, BillingService, AuthStore, FCM setup, and root navigation all at once.
- **No service layer** — API calls are made directly from widgets.
- **Flat folder structure** — all files in `lib/` with no grouping.

---

## Target Architecture

### 1. State Management → Riverpod

Use `flutter_riverpod` (or `provider` if simpler is preferred).

```
lib/
  providers/
    auth_provider.dart        # AuthState: loading | loggedIn | loggedOut
    api_provider.dart         # Api instance derived from auth token
    billing_provider.dart     # BillingService instance
    orders_provider.dart      # AsyncNotifier for orders list + polling
    products_provider.dart    # AsyncNotifier for product catalog
```

**Why Riverpod:**
- Eliminates constructor drilling of `Api`, `BillingService`, `AuthStore`
- `AsyncNotifier` replaces manual Timer + setState polling pattern
- Auto-dispose stops timers/subscriptions when page is not active (fixes #9 permanently)
- No `BuildContext` needed to read providers — safe in async code (fixes #4 class of bugs)

---

### 2. Routing → GoRouter

```dart
final router = GoRouter(
  redirect: (ctx, state) => authState.isLoggedIn ? null : '/login',
  routes: [
    GoRoute(path: '/login', builder: (_,__) => LoginPage()),
    GoRoute(path: '/', builder: (_,__) => DashboardPage()),
    GoRoute(path: '/orders', builder: (_,__) => OrdersListPage()),
    GoRoute(path: '/orders/:id', builder: (_,s) => OrderDetailPage(id: s.pathParameters['id']!)),
    GoRoute(path: '/products', builder: (_,__) => ProductListPage()),
    GoRoute(path: '/stock', builder: (_,__) => StockPage()),
    GoRoute(path: '/pos', builder: (_,__) => PosScreen()),
  ],
);
```

**Why GoRouter:**
- Auth redirect in one place — no scattered `Navigator.push` guards
- Back button / deep link support for free
- Named routes prevent typos

---

### 3. Folder Structure

```
lib/
  constants.dart              # OrderStatus, etc. (already done)
  config.dart                 # kBaseUrl via --dart-define (already done)
  main.dart                   # Thin: ProviderScope + MaterialApp.router
  firebase_options.dart       # (untouched)

  core/
    auth_store.dart
    api.dart
    router.dart

  providers/
    auth_provider.dart
    orders_provider.dart
    products_provider.dart

  services/
    push_service.dart         # (already exists)
    billing_service.dart      # moved from pos/

  features/
    auth/
      login_page.dart
    dashboard/
      dashboard_page.dart     # replaces ModeChooserPage
    orders/
      orders_list_page.dart
      order_detail_page.dart
    products/
      product_list_page.dart
    stock/
      stock_page.dart
      bulk_update_page.dart
    pos/
      pos_screen.dart
```

---

### 4. Polling → AsyncNotifier with auto-dispose

Replace every `Timer.periodic` + `setState` pattern with:

```dart
@riverpod
class OrdersNotifier extends _$OrdersNotifier {
  Timer? _timer;

  @override
  Future<List<Order>> build() async {
    ref.onDispose(() => _timer?.cancel());  // auto-cancels when page leaves
    final orders = await ref.read(apiProvider).listOrders();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => ref.invalidateSelf());
    return orders;
  }
}
```

**Benefits:** No `mounted` checks needed. Timer auto-cancels on disposal. Backgrounding is handled by Riverpod lifecycle.

---

### 5. main.dart — Thin Shell

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _setupFirebase();
  await _setupLocalNotifications();
  runApp(
    ProviderScope(
      child: FpsAdminApp(),
    ),
  );
}

class FpsAdminApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      routerConfig: ref.watch(routerProvider),
      theme: _buildTheme(),
    );
  }
}
```

---

### 6. Dashboard Redesign

Replace the 4-tile `ModeChooserPage` with a proper dashboard:

- **Bottom Navigation Bar** with 4 tabs: Orders | Products | Stock | POS
- Each tab maintains its own scroll position (already possible with `AutomaticKeepAliveClientMixin`)
- Orders tab shows a badge with pending order count
- Pull-to-refresh on all tabs

---

### 7. Theme — Consistent Design System

Currently: `colorSchemeSeed: Colors.teal` with scattered hardcoded colors (`Colors.indigo`, `Colors.green`, `Colors.orange`).

Move to a single `AppTheme` class:

```dart
class AppTheme {
  static const seed = Color(0xFF008080); // FPS brand teal
  static ThemeData light() => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: seed),
    // all component themes defined here
  );
}
```

Remove all inline `Color(0xFF...)` hardcoded values from widgets — use `colorScheme.*` tokens.

---

## Migration Steps (Recommended Order)

| Step | Task | Effort |
|------|------|--------|
| 1 | Add `flutter_riverpod` + `go_router` to pubspec.yaml | 30 min |
| 2 | Create `providers/auth_provider.dart` wrapping AuthStore | 1 hr |
| 3 | Create `providers/orders_provider.dart` replacing Timer polling | 1 hr |
| 4 | Wire GoRouter with auth redirect | 1 hr |
| 5 | Replace `ModeChooserPage` with `BottomNavigationBar` dashboard | 2 hr |
| 6 | Migrate `OrdersListPage` to read from `ordersProvider` | 1 hr |
| 7 | Migrate `ProductListPage` to read from `productsProvider` | 1 hr |
| 8 | Migrate POS, Stock pages | 2 hr |
| 9 | Consolidate theme into `AppTheme` class | 1 hr |
| 10 | Reorganize into features/ folder structure | 1 hr |

**Total estimate: ~11 hours of focused work**

---

## What NOT to Change

- Firebase config (`firebase_options.dart`) — leave as-is
- Backend API contract — the `Api` class stays the same
- `constants.dart` — already clean after current fixes
- `config.dart` — already fixed with `--dart-define`
