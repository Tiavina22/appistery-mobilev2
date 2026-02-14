import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/version_provider.dart';
import 'force_update_dialog.dart';
import 'no_active_version_dialog.dart';
import '../screens/home_screen.dart';

class HomeWithVersionCheck extends StatefulWidget {
  const HomeWithVersionCheck({super.key});

  @override
  State<HomeWithVersionCheck> createState() => _HomeWithVersionCheckState();
}

class _HomeWithVersionCheckState extends State<HomeWithVersionCheck> {
  bool _dialogShown = false;

  @override
  void initState() {
    super.initState();
    // Afficher le dialog après le premier render
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkVersionAndShowDialog();
    });
  }

  void _checkVersionAndShowDialog() {
    if (_dialogShown) return;

    final versionProvider = Provider.of<VersionProvider>(
      context,
      listen: false,
    );

    // Check if no active version is available - block the app
    if (versionProvider.noActiveVersion) {
      _dialogShown = true;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) =>
              NoActiveVersionDialog(downloadUrl: versionProvider.downloadUrl),
        ),
      );
      return;
    }

    if (versionProvider.isUpdateRequired &&
        versionProvider.downloadUrl != null) {
      _dialogShown = true;

      // If version is expired, prevent app closure
      final canDismiss = !versionProvider.isVersionExpired;

      showForceUpdateDialog(
        context,
        downloadUrl: versionProvider.downloadUrl!,
        versionName: versionProvider.versionName,
        description: versionProvider.description,
        canDismiss: canDismiss,
      );
    } else {
    }
  }

  @override
  Widget build(BuildContext context) {
    return const HomeScreen();
  }
}
