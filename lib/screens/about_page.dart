// lib/screens/about_page.dart
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({Key? key}) : super(key: key);

  @override
  _AboutPageState createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _appVersion = "Chargement...";

  @override
  void initState() {
    super.initState();
    _loadVersionInfo();
  }

  Future<void> _loadVersionInfo() async {
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = "Version ${packageInfo.version} (Build ${packageInfo.buildNumber})";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('À Propos de Colors & Notes')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Colors & Notes', style: Theme.of(context).textTheme.headlineMedium),
            SizedBox(height: 10),
            Text("version : $_appVersion",
              style: Theme.of(context).textTheme.titleSmall,
            ),
            SizedBox(height: 20),
            Text('"Color your day."', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontStyle: FontStyle.italic)),
            SizedBox(height: 15),
            Text(
              'Cette application vous permet d\'organiser vos notes et pensées quotidiennes en les associant à des couleurs personnalisées, regroupées dans des palettes uniques pour chaque journal.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            SizedBox(height: 20),
            Text('Développé avec Flutter & Firebase.', style: Theme.of(context).textTheme.bodyMedium),
            SizedBox(height: 10),
            Text('Auteur : Stanislas Mathieu Eric Selle', style: Theme.of(context).textTheme.bodyMedium),
            SizedBox(height: 10),
            Text('Copyright © 2025', style: Theme.of(context).textTheme.bodySmall),
            SizedBox(height: 20),
            Text('Pour plus d\'informations, consultez le dépôt GitHub ou la page de licence.', style: Theme.of(context).textTheme.bodyMedium),
            // Ajoutez d'autres informations si vous le souhaitez
          ],
        ),
      ),
    );
  }
}
