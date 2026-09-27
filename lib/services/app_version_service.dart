import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class AppReleasePolicy {
  const AppReleasePolicy({
    required this.latestBuild,
    required this.minimumBuild,
    required this.latestVersion,
    required this.storeUrl,
    required this.updateMessage,
  });

  final int latestBuild;
  final int minimumBuild;
  final String latestVersion;
  final String storeUrl;
  final String? updateMessage;

  bool isUpdateAvailable(int currentBuild) => currentBuild < latestBuild;
  bool isUpdateRequired(int currentBuild) => currentBuild < minimumBuild;
}

class AppVersionStatus {
  const AppVersionStatus({
    required this.currentBuild,
    required this.currentVersion,
    required this.policy,
  });

  final int currentBuild;
  final String currentVersion;
  final AppReleasePolicy? policy;

  bool get updateAvailable => policy?.isUpdateAvailable(currentBuild) ?? false;
  bool get updateRequired => policy?.isUpdateRequired(currentBuild) ?? false;
}

class AppVersionService {
  AppVersionService({supabase.SupabaseClient? client})
      : _client = client ?? supabase.Supabase.instance.client;

  final supabase.SupabaseClient _client;

  Future<AppVersionStatus> loadStatus() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
    final platform = Platform.isIOS ? 'ios' : 'android';

    try {
      final row = await _client
          .from('app_release_policies')
          .select(
            'latest_build, minimum_build, latest_version, store_url, update_message',
          )
          .eq('platform', platform)
          .eq('is_active', true)
          .maybeSingle();

      if (row == null) {
        return AppVersionStatus(
          currentBuild: currentBuild,
          currentVersion: packageInfo.version,
          policy: null,
        );
      }

      return AppVersionStatus(
        currentBuild: currentBuild,
        currentVersion: packageInfo.version,
        policy: AppReleasePolicy(
          latestBuild: row['latest_build'] as int,
          minimumBuild: row['minimum_build'] as int,
          latestVersion: row['latest_version'] as String,
          storeUrl: row['store_url'] as String,
          updateMessage: row['update_message'] as String?,
        ),
      );
    } catch (_) {
      // Fail open. A temporary network/backend failure must not lock users out.
      return AppVersionStatus(
        currentBuild: currentBuild,
        currentVersion: packageInfo.version,
        policy: null,
      );
    }
  }
}
