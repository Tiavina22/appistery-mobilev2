import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';

class ForceUpdateDialog extends StatelessWidget {
  final String? versionName;
  final String? description;
  final String downloadUrl;
  final bool canDismiss;

  const ForceUpdateDialog({
    super.key,
    this.versionName,
    this.description,
    required this.downloadUrl,
    this.canDismiss = false,
  });

  Future<void> _launchDownloadUrl() async {
    try {
      final Uri url = Uri.parse(downloadUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $downloadUrl';
      }
    } catch (e) {
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => canDismiss, // Prevent dismissal if not allowed
      child: AlertDialog(
        title: Text(
          'update_required'.tr(),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Version info
              if (versionName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'new_version'.tr(args: [versionName!]),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1DB954),
                    ),
                  ),
                ),

              // Description
              if (description != null && description!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    description!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                  ),
                ),

              // Important notice
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'update_required_message'.tr(),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.red,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (canDismiss)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('later'.tr()),
            ),
          SizedBox(
            width: canDismiss ? null : double.infinity,
            child: ElevatedButton.icon(
              onPressed: _launchDownloadUrl,
              icon: const Icon(Icons.download),
              label: Text('download_update'.tr()),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1DB954),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Show force update dialog
void showForceUpdateDialog(
  BuildContext context, {
  required String downloadUrl,
  String? versionName,
  String? description,
  bool canDismiss = false,
}) {
  showDialog(
    context: context,
    barrierDismissible: canDismiss,
    builder: (context) => ForceUpdateDialog(
      versionName: versionName,
      description: description,
      downloadUrl: downloadUrl,
      canDismiss: canDismiss,
    ),
  );
}
