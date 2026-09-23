import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class ProfileSummary {
  const ProfileSummary({
    required this.displayName,
    required this.avatarKey,
  });

  final String? displayName;
  final String? avatarKey;
}

class ProfileService {
  ProfileService({supabase.SupabaseClient? client})
      : _client = client ?? supabase.Supabase.instance.client;

  final supabase.SupabaseClient _client;

  Future<ProfileSummary?> loadCurrentProfile() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      return null;
    }

    final data = await _client
        .from('profiles')
        .select('display_name, avatar_key')
        .eq('id', user.id)
        .maybeSingle();

    final displayName = data?['display_name']?.toString().trim();
    final avatarKey = data?['avatar_key']?.toString().trim();

    return ProfileSummary(
      displayName:
          displayName == null || displayName.isEmpty ? null : displayName,
      avatarKey: avatarKey == null || avatarKey.isEmpty ? null : avatarKey,
    );
  }
}
