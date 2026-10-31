import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';

class UserRepository {
  final ApiService api;
  final CacheService cache;

  UserRepository(this.api, this.cache);

  Future<UserProfile> getProfile() async {
    final cached = await cache.getProfile();

    if (cached != null) {
      return UserProfile.fromJson(cached);
    }

    final profile = await api.getProfile();
    await cache.saveProfile(profile.toJson());

    return profile;
  }

  Future<UserProfile> refreshProfile() async {
    final profile = await api.getProfile();
    await cache.saveProfile(profile.toJson());
    return profile;
  }
}