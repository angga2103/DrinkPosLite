import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../data/models/shift_model.dart';
import '../data/repositories/shift_repository.dart';

class ShiftState {
  final ShiftModel? currentShift;
  final bool isLoading;
  final String? errorMessage;

  ShiftState({
    this.currentShift,
    this.isLoading = false,
    this.errorMessage,
  });

  bool get hasActiveShift => currentShift != null && currentShift!.isOpen;

  ShiftState copyWith({
    ShiftModel? currentShift,
    bool? isLoading,
    String? errorMessage,
    bool clearShift = false,
  }) {
    return ShiftState(
      currentShift: clearShift ? null : (currentShift ?? this.currentShift),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class ShiftNotifier extends StateNotifier<ShiftState> {
  final ShiftRepository _repo;

  ShiftNotifier([ShiftRepository? repo])
      : _repo = repo ?? ShiftRepository(),
        super(ShiftState()) {
    loadCurrentShift();
  }

  Future<void> loadCurrentShift() async {
    state = state.copyWith(isLoading: true);
    try {
      final shift = await _repo.getCurrentOpenShift();
      state = state.copyWith(currentShift: shift, isLoading: false);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
    }
  }

  Future<bool> openShift({
    required String userId,
    required String userName,
    required double initialCash,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final shift = await _repo.openShift(
        userId: userId,
        userName: userName,
        initialCash: initialCash,
      );
      state = state.copyWith(currentShift: shift, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
      return false;
    }
  }

  Future<bool> closeShift({
    required double actualCash,
    String? differenceNote,
    required String userId,
    String? userName,
  }) async {
    if (state.currentShift == null) return false;
    state = state.copyWith(isLoading: true);
    try {
      await _repo.closeShift(
        shiftId: state.currentShift!.id,
        actualCash: actualCash,
        differenceNote: differenceNote,
        userId: userId,
        userName: userName,
      );
      state = state.copyWith(clearShift: true, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
      return false;
    }
  }
}

final shiftRepositoryProvider = Provider<ShiftRepository>((ref) => ShiftRepository());

final shiftProvider = StateNotifierProvider<ShiftNotifier, ShiftState>((ref) {
  final repo = ref.watch(shiftRepositoryProvider);
  return ShiftNotifier(repo);
});
