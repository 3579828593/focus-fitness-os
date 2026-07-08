import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../main.dart';
import 'session_repository.dart';
import 'workout_repository.dart';

/// ============================================================
/// Repository 层全局 Providers
/// UI 层通过 ref.read(sessionRepositoryProvider) 访问
/// ============================================================

/// SessionRepository Provider
final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  final db = ref.read(databaseProvider);
  final api = ref.read(nodeRedApiProvider);
  return SessionRepository(db, api);
});

/// WorkoutRepository Provider
final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  final db = ref.read(databaseProvider);
  return WorkoutRepository(db);
});
