// File: lib/widgets/auth_page_footer.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:logger/logger.dart';

import 'package:colors_notes/l10n/app_localizations.dart';
import '../screens/about_page.dart';
import '../screens/license_page.dart';
import 'app_version_display.dart';

final _loggerFooter = Logger(printer: PrettyPrinter(methodCount: 0));

class AuthPageFooter extends StatelessWidget {

  final String apkUrl = "https://www.stanworld.org/main/web/ColorsNotes-1.5.4.apk";
  // final String apkUrl = "https://colorsnotes-e9142.web.app/apk/ColorsNotes-1.5.4-unavaible.txt";

  const AuthPageFooter({super.key});

  Future<void> _launchUrl(BuildContext context, String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _loggerFooter.e("Could not launch URL: $url");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorLaunchingUrl)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final textButtonStyle = TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    final linkTextStyle = TextStyle(fontSize: 12, color: Colors.grey[600], decoration: TextDecoration.underline);
    final separatorTextStyle = TextStyle(fontSize: 12, color: Colors.grey[400]);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 2.0, // Reduced spacing for a tighter look
          runSpacing: 0.0,
          children: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AboutPage()));
              },
              style: textButtonStyle,
              child: Text(l10n.aboutLink, style: linkTextStyle),
            ),
            Text('|', style: separatorTextStyle),
            TextButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ColorsNotesLicensePage()));
              },
              style: textButtonStyle,
              child: Text(l10n.licenseLink, style: linkTextStyle),
            ),
            Text('|', style: separatorTextStyle),
            TextButton(
              onPressed: () => _launchUrl(context, apkUrl),
              style: textButtonStyle,
              child: Text(l10n.downloadForAndroidLink, style: linkTextStyle),
            ),
          ],
        ),
        const SizedBox(height: 10), // Space between links and version
        const AppVersionDisplay(),
      ],
    );
  }
}