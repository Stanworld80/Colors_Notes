import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
  /// The application version string, including version and build number.
  /// Defaults to "Chargement..." (Loading...) until the actual version is fetched.
  String _appVersion = "Chargement...";

  @override
  void initState() {
    super.initState();
    _loadVersionInfo();
  }

  /// Loads the application's version and build number using [PackageInfo].
  ///
  /// Updates the [_appVersion] state variable once the information is retrieved.
  Future<void> _loadVersionInfo() async {
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    if (mounted) { // Check if the widget is still in the tree.
      setState(() {
        _appVersion = "Version ${packageInfo.version} (Build ${packageInfo.buildNumber})";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('À Propos de Colors & Notes')), // AppBar title in French
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Colors & Notes', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 10),
            Text( // Text in French
              "version : $_appVersion",
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 20),
            Text( // Text in French
                '"Color your day."',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontStyle: FontStyle.italic)
            ),
            const SizedBox(height: 15),
            Text( // Text in French
              'Cette application vous permet d\'organiser vos notes et pensées quotidiennes en les associant à des couleurs personnalisées, regroupées dans des palettes uniques pour chaque journal.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            Text( // Text in French
                'Développé avec Flutter & Firebase.',
                style: Theme.of(context).textTheme.bodyMedium
            ),
            const SizedBox(height: 10),
            Text( // Text in French
                'Auteur : Stanislas Mathieu Eric Selle',
                style: Theme.of(context).textTheme.bodyMedium
            ),
            const SizedBox(height: 10),
            Text( // Text in French
                'Copyright © 2025',
                style: Theme.of(context).textTheme.bodySmall
            ),
            const SizedBox(height: 20),
            Text( // Text in French
                'Pour plus d\'informations, consultez le dépôt GitHub ou la page de licence.',
                style: Theme.of(context).textTheme.bodyMedium
            ),
            // Add more information if desired
          ],
        ),
      ),
    );
  }
}
