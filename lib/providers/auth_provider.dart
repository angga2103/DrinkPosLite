import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../data/models/user_model.dart';
import '../data/repositories/auth_repository.dart';

class AuthState {
  final UserModel? currentUser;
  final bool isLocked;
  final bool isLoading;
  final String? errorMessage;
  final List<UserModel> availableUsers;

  AuthState({
    this.currentUser,
    this.isLocked = true,
    this.isLoading = false,
    this.errorMessage,
    this.availableUsers = const [],
  });

  bool get isAuthenticated => currentUser != null && !isLocked;

  AuthState copyWith({
    UserModel? currentUser,
    bool? isLocked,
    bool? isLoading,
    String? errorMessage,
    List<UserModel>? availableUsers,
    bool clearError = false,
  }) {
    return AuthState(
      currentUser: currentUser ?? this.currentUser,
      isLocked: isLocked ?? this.isLocked,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      availableUsers: availableUsers ?? this.availableUsers,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;
  Timer? _inactivityTimer;
  int _autoLockMinutes = 5;

  AuthNotifier([AuthRepository? repo])
      : _repo = repo ?? AuthRepository(),
        super(AuthState()) {
    loadUsers();
  }

  void setAutoLockMinutes(int minutes) {
    _autoLockMinutes = minutes;
    resetInactivityTimer();
  }

  void resetInactivityTimer() {
    _inactivityTimer?.cancel();
    if (state.currentUser != null && !state.isLocked && _autoLockMinutes > 0) {
      _inactivityTimer = Timer(Duration(minutes: _autoLockMinutes), () {
        lockApp();
      });
    }
  }

  void lockApp() {
    state = state.copyWith(isLocked: true);
  }

  Future<void> loadUsers() async {
    state = state.copyWith(isLoading: true);
    try {
      final users = await _repo.getActiveUsers();
      state = state.copyWith(availableUsers: users, isLoading: false);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
    }
  }

  Future<bool> login(String userId, String pin) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repo.loginWithPin(userId: userId, enteredPin: pin);

    if (result.success && result.user != null) {
      state = state.copyWith(
        currentUser: result.user,
        isLocked: false,
        isLoading: false,
        clearError: true,
      );
      resetInactivityTimer();
      await loadUsers(); // refresh lock status
      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: result.errorMessage,
      );
      await loadUsers();
      return false;
    }
  }

  void logout() {
    _inactivityTimer?.cancel();
    state = AuthState(
      currentUser: null,
      isLocked: true,
      availableUsers: state.availableUsers,
    );
  }

  Future<bool> unlockUser(String userId) async {
    if (state.currentUser == null || !state.currentUser!.isOwner) return false;
    final res = await _repo.unlockUser(userId: userId, ownerUserId: state.currentUser!.id);
    if (res) {
      await loadUsers();
    }
    return res;
  }

  Future<bool> resetPin(String userId, String newPin) async {
    if (state.currentUser == null || !state.currentUser!.isOwner) return false;
    final res = await _repo.resetUserPin(
      targetUserId: userId,
      newPin: newPin,
      requestedByUserId: state.currentUser!.id,
    );
    if (res) {
      await loadUsers();
    }
    return res;
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthNotifier(repo);
});
