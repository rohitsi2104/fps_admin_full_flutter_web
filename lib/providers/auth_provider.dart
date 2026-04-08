import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/auth_store.dart';

enum AuthStatus { loading, loggedIn, loggedOut }

class AuthState {
  final AuthStatus status;
  final String? token;

  const AuthState({required this.status, this.token});

  bool get isLoggedIn => status == AuthStatus.loggedIn;
}

class AuthNotifier extends Notifier<AuthState> {
  late final AuthStore _store;

  @override
  AuthState build() {
    _store = ref.watch(authStoreProvider);
    _init();
    return const AuthState(status: AuthStatus.loading);
  }

  Future<void> _init() async {
    await _store.load();
    if (_store.token != null && _store.token!.isNotEmpty) {
      state = AuthState(status: AuthStatus.loggedIn, token: _store.token);
    } else {
      state = const AuthState(status: AuthStatus.loggedOut);
    }
  }

  Future<void> login(String token) async {
    await _store.save(token);
    state = AuthState(status: AuthStatus.loggedIn, token: token);
  }

  Future<void> logout() async {
    await _store.clear();
    state = const AuthState(status: AuthStatus.loggedOut);
  }
}

final authStoreProvider = Provider<AuthStore>((ref) {
  return AuthStore();
});

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
