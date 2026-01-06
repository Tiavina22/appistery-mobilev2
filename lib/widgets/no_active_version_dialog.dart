import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';

class NoActiveVersionDialog extends StatelessWidget {
  final String? downloadUrl;

  const NoActiveVersionDialog({Key? key, this.downloadUrl}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent back button
      child: Scaffold(
        backgroundColor: Colors.black87,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 80,
                    color: Colors.amber,
                  ),
                  SizedBox(height: 24),
                  Text(
                    'maintenance_mode'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber, width: 1),
                    ),
                    child: Text(
                      'no_active_version_message'.tr(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.amber[100],
                        height: 1.5,
                      ),
                    ),
                  ),
                  SizedBox(height: 32),
                  Text(
                    'please_contact_support'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () async {
                      // Open download URL if available
                      if (downloadUrl != null && downloadUrl!.isNotEmpty) {
                        if (await canLaunchUrl(Uri.parse(downloadUrl!))) {
                          await launchUrl(
                            Uri.parse(downloadUrl!),
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      } else {
                        // Retry version check if no URL
                        Navigator.of(context).pop();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      padding: EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      downloadUrl != null && downloadUrl!.isNotEmpty
                          ? 'download_update'.tr()
                          : 'retry'.tr(),
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
