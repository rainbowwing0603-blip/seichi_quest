import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'app_logger.dart';

class SessionService {
  SessionService({supabase.SupabaseClient? client})
      : _client = client ?? supabase.Supabase.instance.client;

  final supabase.SupabaseClient _client;

  Future<void> ensureCloudUser() async {
    final existingUser = _client.auth.currentUser;

    if (existingUser != null) {
      appDebugPrint(
        '[AUTH] existing user: ${existingUser.id}, '
        'anonymous=${existingUser.isAnonymous}',
      );
      return;
    }

    appDebugPrint('[AUTH] no current user. Starting anonymous sign-in...');

    try {
      final response = await _client.auth.signInAnonymously();
      final user = response.user;

      if (user != null) {
        appDebugPrint(
          '[AUTH] anonymous sign-in success: ${user.id}, '
          'anonymous=${user.isAnonymous}',
        );
      } else {
        appDebugPrint('[AUTH] anonymous sign-in returned null user');
      }
    } on supabase.AuthException catch (error) {
      appDebugPrint(
        '[AUTH] anonymous sign-in failed: '
        'code=${error.statusCode}, message=${error.message}',
      );
    } catch (error) {
      appDebugPrint('[AUTH] anonymous sign-in failed: $error');
    }
  }
}
