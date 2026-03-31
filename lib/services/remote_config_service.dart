import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

class RemoteConfigService {
  RemoteConfigService(this._remoteConfig);

  static const String scoringEnabledKey = 'surveyor_scoring_enabled';
  static const String appIsActiveKey = 'isActive';

  final FirebaseRemoteConfig _remoteConfig;

  Future<void> initialize() async {
    await _remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: kDebugMode
            ? const Duration(minutes: 5)
            : const Duration(hours: 1),
      ),
    );

    await _remoteConfig.setDefaults({
      scoringEnabledKey: false,
      appIsActiveKey: true,
    });

    await _remoteConfig.fetchAndActivate();
  }

  bool get scoringEnabled => _remoteConfig.getBool(scoringEnabledKey);

  bool get isActive => _remoteConfig.getBool(appIsActiveKey);
}
