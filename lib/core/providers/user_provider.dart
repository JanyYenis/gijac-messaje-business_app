import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import '../repositories/user_repository.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';

// Proveedores de dependencias
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());
final cacheServiceProvider = Provider<CacheService>((ref) => CacheService());

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(
    ref.read(apiServiceProvider),
    ref.read(cacheServiceProvider),
  );
});

// Estado del usuario
enum ProfileStatus { initial, loading, success, error }

class UserState {
  final UserProfile? user;
  final ProfileStatus status;
  final String? errorMessage;

  const UserState({
    this.user,
    this.status = ProfileStatus.initial,
    this.errorMessage,
  });

  UserState copyWith({
    UserProfile? user,
    ProfileStatus? status,
    String? errorMessage,
  }) {
    return UserState(
      user: user ?? this.user,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// Notifier
class UserNotifier extends StateNotifier<UserState> {
  final UserRepository _repository;

  UserNotifier(this._repository) : super(const UserState());

  /// Muestra al instante lo guardado en el teléfono y, si había caché, lo pone al día con el servidor sin bloquear la pantalla
  Future<void> loadProfile() async {
    var teniaCache = false;
    try {
      state = state.copyWith(status: ProfileStatus.loading);
      teniaCache = (await CacheService().getProfile()) != null;
      final user = await _repository.getProfile();
      state = UserState(user: user, status: ProfileStatus.success);
    } catch (e) {
      state = UserState(status: ProfileStatus.error, errorMessage: e.toString());
    }
    if (teniaCache) unawaited(refreshProfile());
  }

  /// Consulta el servidor (ignora la caché) para ver los cambios hechos desde la web. true si se pudo.
  Future<bool> refreshProfile() async {
    try {
      final user = await _repository.refreshProfile();
      state = UserState(user: user, status: ProfileStatus.success);
      return true;
    } catch (e) {
      // Si ya había un perfil en pantalla se conserva; solo se marca error si no había nada
      if (state.user == null) {
        state = UserState(status: ProfileStatus.error, errorMessage: e.toString());
      }
      return false;
    }
  }

  /// Guarda el perfil ya actualizado por el servidor (tras editar datos o cambiar la foto)
  Future<void> setUser(UserProfile user) async {
    await CacheService().saveProfile(user.toJson());
    state = UserState(user: user, status: ProfileStatus.success);
  }

  void clearSession() {
    state = const UserState();
  }
}

// Provider principal
final userProvider = StateNotifierProvider<UserNotifier, UserState>((ref) {
  return UserNotifier(ref.read(userRepositoryProvider));
});