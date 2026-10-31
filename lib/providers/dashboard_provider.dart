import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../data/models/report_model.dart';
import '../data/repositories/report_repository.dart';

class DashboardState {
  final DashboardMetrics metrics;
  final bool isLoading;
  final String? errorMessage;

  DashboardState({
    required this.metrics,
    this.isLoading = false,
    this.errorMessage,
  });

  DashboardState copyWith({
    DashboardMetrics? metrics,
    bool? isLoading,
    String? errorMessage,
  }) {
    return DashboardState(
      metrics: metrics ?? this.metrics,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class DashboardNotifier extends StateNotifier<DashboardState> {
  final ReportRepository _repo;

  DashboardNotifier([ReportRepository? repo])
      : _repo = repo ?? ReportRepository(),
        super(DashboardState(metrics: DashboardMetrics())) {
    loadMetrics();
  }

  Future<void> loadMetrics() async {
    state = state.copyWith(isLoading: true);
    try {
      final metrics = await _repo.getDashboardMetrics();
      state = state.copyWith(metrics: metrics, isLoading: false);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
    }
  }
}

final reportRepositoryProvider = Provider<ReportRepository>((ref) => ReportRepository());

final dashboardProvider = StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  final repo = ref.watch(reportRepositoryProvider);
  return DashboardNotifier(repo);
});
