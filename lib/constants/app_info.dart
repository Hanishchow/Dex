import 'package:flutter/foundation.dart';
import 'package:mornye/utils/desktop_platform.dart';

class AppInfo {
  static const String version = '5.2.6';
  static const String buildNumber = '165';

  static const String gitCommit = String.fromEnvironment('GIT_COMMIT');
  static String get shortGitCommit =>
      gitCommit.length > 8 ? gitCommit.substring(0, 8) : gitCommit;

  /// The version shown to people; desktop builds are still in beta.
  static String get displayVersion => versionLabel();

  @visibleForTesting
  static String versionLabel({bool debug = kDebugMode, bool? desktop}) {
    if (debug) return 'Internal';
    return desktop ?? isDesktopPlatform ? '$version (beta)' : version;
  }

  static const String appName = 'Dex';
  static const String license = 'LGPL-3.0-only';
  static const String copyright =
      'Based on Mornye · © 2026 Zarz Eleutherius and contributors';

  static const String mobileAuthor = 'zarzet';

  /// Dex's own repository as "owner/name". While empty, Dex shows no issue
  /// links and does not check for updates.
  static const String dexRepo = 'Hanishchow/Dex';
  static bool get hasRepo => dexRepo.isNotEmpty;

  /// The project Dex is built on. Kept for credit and licence reasons: Dex is
  /// a modified version of it, under the same LGPL-3.0-only licence.
  static const String upstreamName = 'Mornye';
  static const String upstreamRepo = 'mornyeapp/Mornye';
  static const String upstreamUrl = 'https://github.com/$upstreamRepo';

  static const String githubRepo = dexRepo;
  static const String githubUrl = hasRepoUrl
      ? 'https://github.com/$dexRepo'
      : '';
  static const bool hasRepoUrl = dexRepo != '';

  /// Whether to show the original developer's donation page and monthly goal
  /// in Settings. Off: those accounts and goals are not Dex's.
  static const bool showUpstreamDonations = false;

  /// Whether to show the original developer's remote announcement pop-ups
  /// (their promotions and donation appeals). Off for Dex.
  static const bool showUpstreamAnnouncements = false;

  /// Where "project" links go: Dex's repository, or the upstream project's
  /// page when Dex has none yet.
  static String get projectUrl => hasRepo ? githubUrl : upstreamUrl;

  /// Desktop packages are published to the same repository.
  static const String desktopGithubRepo = dexRepo;
  // The server keeps the endpoint name from before the rename.
  static const String remoteConfigApiUrl =
      'https://api.zarz.moe/v1/spotiflac-mobile/config';

  static const String kofiUrl = 'https://ko-fi.com/zarzet';
  static const String githubSponsorsUrl = 'https://github.com/sponsors/zarzet/';
}
