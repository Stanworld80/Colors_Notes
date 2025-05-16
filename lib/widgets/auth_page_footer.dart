import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:logger/logger.dart';

import 'package:colors_notes/l10n/app_localizations.dart'; // For localized strings.
import '../screens/about_page.dart';
import '../screens/colors_notes_license_page.dart'; // Assuming this is the correct name for your custom license page.
import 'app_version_display.dart'; // The reusable widget to display app version.

/// Logger instance for this footer widget.
final _loggerFooter = Logger(printer: PrettyPrinter(methodCount: 0));

/// A footer widget typically used on authentication pages (SignIn, Register).
///
/// It displays links to the "About" page, "License" page, a link to download
/// the Android APK, and the application version using [AppVersionDisplay].
class AuthPageFooter extends StatelessWidget {
  /// The URL for downloading the Android APK.
  final String apkUrl = "https://www.stanworld.org/main/web/ColorsNotes-1.5.4.apk";
  // final String apkUrl = "https://colorsnotes-e9142.web.app/apk/ColorsNotes-1.5.4-unavaible.txt"; // Alternate URL, commented out.

  /// Creates an [AuthPageFooter] widget.
  const AuthPageFooter({super.key});

  /// Attempts to launch the given [url] in an external application.
  ///
  /// If launching fails, it logs an error and shows a [SnackBar]
  /// with an error message.
  ///
  /// [context] The build context for showing [SnackBar].
  /// [url] The URL string to launch.
  Future<void> _launchUrl(BuildContext context, String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _loggerFooter.e("Could not launch URL: $url");
      if (context.mounted) { // Check if the widget is still in the tree.
        ScaffoldMessenger.of(context).showSnackBar(
          // Uses localized string for the error message.
          SnackBar(content: Text(AppLocalizations.of(context)!.errorLaunchingUrl)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Access localized strings.
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    // Define a common style for the TextButtons in the footer for a compact look.
    final textButtonStyle = TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      minimumSize: Size.zero, // Remove default minimum size.
      tapTargetSize: MaterialTapTargetSize.shrinkWrap, // Minimize tap target size.
    );
    // Define a common text style for the links.
    final linkTextStyle = TextStyle(fontSize: 12, color: Colors.grey[600], decoration: TextDecoration.underline);
    // Define a text style for the separators between links.
    final separatorTextStyle = TextStyle(fontSize: 12, color: Colors.grey[400]);

    return Column(
      mainAxisSize: MainAxisSize.min, // Column should take minimum vertical space.
      children: [
        // A Wrap widget to display links in a row, wrapping if necessary.
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 2.0, // Reduced horizontal spacing between items.
          runSpacing: 0.0, // No vertical spacing if items wrap to the next line.
          children: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AboutPage()));
              },
              style: textButtonStyle,
              child: Text(l10n.aboutLink, style: linkTextStyle), // Localized "About" link.
            ),
            Text('|', style: separatorTextStyle), // Separator.
            TextButton(
              onPressed: () {
                // Navigate to the custom license page.
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ColorsNotesLicensePage()));
              },
              style: textButtonStyle,
              child: Text(l10n.licenseLink, style: linkTextStyle), // Localized "License" link.
            ),
            Text('|', style: separatorTextStyle), // Separator.
            TextButton(
              onPressed: () => _launchUrl(context, apkUrl),
              style: textButtonStyle,
              child: Text(l10n.downloadForAndroidLink, style: linkTextStyle), // Localized "Download for Android" link.
            ),
          ],
        ),
        const SizedBox(height: 10), // Space between the links and the app version display.
        const AppVersionDisplay(), // The reusable widget to display the app version.
      ],
    );
  }
}
