import 'dart:io';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:package_info_plus/package_info_plus.dart';

// Toggles "start with Windows/Linux" the same way TDM uses a registry key.
class AutostartService {
  Future<void> init() async {
    final info = await PackageInfo.fromPlatform();
    launchAtStartup.setup(
      appName: info.appName,
      appPath: Platform.resolvedExecutable,
    );
  }

  Future<bool> isEnabled() => launchAtStartup.isEnabled();
  Future<void> enable() => launchAtStartup.enable();
  Future<void> disable() => launchAtStartup.disable();
}
