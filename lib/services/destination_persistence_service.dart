import 'package:shared_preferences/shared_preferences.dart';

class DestinationPersistenceService {
  DestinationPersistenceService({SharedPreferences? preferences})
      : _providedPreferences = preferences;

  final SharedPreferences? _providedPreferences;

  String manualDestinationKey({
    required String userId,
    required String eventId,
  }) {
    return 'manual_next_seichi_id_v1_${userId}_$eventId';
  }

  String recommendedRouteKey({
    required String userId,
    required String eventId,
  }) {
    return 'recommended_route_ids_v1_${userId}_$eventId';
  }

  Future<SharedPreferences> _preferences() async {
    return _providedPreferences ?? SharedPreferences.getInstance();
  }

  Future<String?> loadManualDestination({
    required String userId,
    required String eventId,
  }) async {
    final preferences = await _preferences();
    return preferences.getString(
      manualDestinationKey(userId: userId, eventId: eventId),
    );
  }

  Future<void> saveManualDestination({
    required String userId,
    required String eventId,
    String? seichiId,
  }) async {
    final preferences = await _preferences();
    final key = manualDestinationKey(userId: userId, eventId: eventId);

    if (seichiId == null || seichiId.isEmpty) {
      await preferences.remove(key);
      return;
    }

    await preferences.setString(key, seichiId);
  }

  Future<void> clearManualDestination({
    required String userId,
    required String eventId,
  }) async {
    final preferences = await _preferences();
    await preferences.remove(
      manualDestinationKey(userId: userId, eventId: eventId),
    );
  }

  Future<List<String>?> loadRecommendedRoute({
    required String userId,
    required String eventId,
  }) async {
    final preferences = await _preferences();
    return preferences.getStringList(
      recommendedRouteKey(userId: userId, eventId: eventId),
    );
  }

  Future<void> saveRecommendedRoute({
    required String userId,
    required String eventId,
    required List<String> seichiIds,
  }) async {
    final preferences = await _preferences();
    final key = recommendedRouteKey(userId: userId, eventId: eventId);

    if (seichiIds.isEmpty) {
      await preferences.remove(key);
      return;
    }

    await preferences.setStringList(key, seichiIds);
  }

  Future<void> clearRecommendedRoute({
    required String userId,
    required String eventId,
  }) async {
    final preferences = await _preferences();
    await preferences.remove(
      recommendedRouteKey(userId: userId, eventId: eventId),
    );
  }
}
