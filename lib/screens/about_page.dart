import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:colors_notes/l10n/app_localizations.dart';

/// A screen that displays information about the "Colors & Notes" application.
///
/// This includes the application name, version, build number, a short description,
/// developer information, and copyright details.
class AboutPage extends StatefulWidget {
  /// Creates an [AboutPage] widget.
  const AboutPage({super.key});

  @override
  _AboutPageState createState() => _AboutPageState();
}

/// The state for the [AboutPage] widget.
///
/// Handles loading and displaying the application's version information.
class _AboutPageState extends State<AboutPage> {
  String _version = "";
  String _buildNumber = "";
  bool _isLoadingVersion = true;

  @override
  void initState() {
    super.initState();
    _loadVersionInfo();
  }

  /// Loads the application's version and build number using [PackageInfo].
  ///
  /// Updates the state variables once the information is retrieved.
  Future<void> _loadVersionInfo() async {
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    if (mounted) { // Check if the widget is still in the tree.
      setState(() {
        _version = packageInfo.version;
        _buildNumber = packageInfo.buildNumber;
        _isLoadingVersion = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final String displayVersion = _isLoadingVersion
        ? l10n.versionLoading
        : l10n.versionBuildFormat(_version, _buildNumber);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutColorsNotesTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.appName, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 10),
            Text(
              displayVersion,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 20),
            Text(
                l10n.appSlogan,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontStyle: FontStyle.italic)
            ),
            const SizedBox(height: 15),
            Text(
              l10n.appDescription,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            Text(
                l10n.developedWith,
                style: Theme.of(context).textTheme.bodyMedium
            ),
            const SizedBox(height: 10),
            Text(
                l10n.authorInfo,
                style: Theme.of(context).textTheme.bodyMedium
            ),
            const SizedBox(height: 10),
            Text(
                l10n.copyrightText,
                style: Theme.of(context).textTheme.bodySmall
            ),
            const SizedBox(height: 20),
            Text(
                l10n.moreInfoText,
                style: Theme.of(context).textTheme.bodyMedium
            ),
            // Add more information if desired
          ],
        ),
      ),
    );
  }
}
