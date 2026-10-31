import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../data/models/store_model.dart';
import '../data/repositories/settings_repository.dart';

class SettingsState {
  final StoreModel store;
  final int autoLockMinutes;
  final bool isLoading;
  final String? errorMessage;

  SettingsState({
    required this.store,
    this.autoLockMinutes = 5,
    this.isLoading = false,
    this.errorMessage,
  });

  SettingsState copyWith({
    StoreModel? store,
    int? autoLockMinutes,
    bool? isLoading,
    String? errorMessage,
  }) {
    return SettingsState(
      store: store ?? this.store,
      autoLockMinutes: autoLockMinutes ?? this.autoLockMinutes,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final SettingsRepository _repo;

  SettingsNotifier([SettingsRepository? repo])
      : _repo = repo ?? SettingsRepository(),
        super(SettingsState(
          store: StoreModel(
            id: 'store_main',
            name: 'Kedai Minuman',
            address: '',
            phone: '081775700114',
            receiptHeader: 'DRINKPOS LITE',
            receiptFooter: 'Terima Kasih!',
          ),
        )) {
    loadSettings();
  }

  Future<void> loadSettings() async {
    state = state.copyWith(isLoading: true);
    try {
      final store = await _repo.getStore();
      final autoLockVal = await _repo.getSetting('auto_lock_minutes');
      final autoLock = int.tryParse(autoLockVal ?? '5') ?? 5;

      state = state.copyWith(
        store: store,
        autoLockMinutes: autoLock,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
    }
  }

  Future<void> updateStore(StoreModel newStore, {String? userId}) async {
    state = state.copyWith(isLoading: true);
    try {
      await _repo.updateStore(newStore, operatorUserId: userId);
      final refreshed = await _repo.getStore();
      state = state.copyWith(store: refreshed, isLoading: false, errorMessage: null);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
      rethrow;
    }
  }

  Future<void> updateAutoLock(int minutes) async {
    await _repo.setSetting('auto_lock_minutes', minutes.toString());
    state = state.copyWith(autoLockMinutes: minutes);
  }
}

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) => SettingsRepository());

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return SettingsNotifier(repo);
});
