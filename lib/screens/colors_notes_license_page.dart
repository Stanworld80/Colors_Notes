import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

/// A StatefulWidget that displays the application's license information.
///
/// This page attempts to load and display the content of a 'LICENSE' file
/// expected to be in the root of the application's assets.
class ColorsNotesLicensePage extends StatefulWidget {
  /// Creates an instance of [ColorsNotesLicensePage].
  const ColorsNotesLicensePage({super.key});

  @override
  _ColorsNotesLicensePageState createState() => _ColorsNotesLicensePageState();
}

/// The state for the [ColorsNotesLicensePage].
///
/// Handles the loading of the license text from an asset file and
/// manages the display of this text or an error message if loading fails.
class _ColorsNotesLicensePageState extends State<ColorsNotesLicensePage> {
  /// Holds the text of the license or an error/loading message.
  /// Initialized to "Chargement de la licence..." (Loading license...).
  String _licenseText = "Chargement de la licence...";

  @override
  void initState() {
    super.initState();
    _loadLicense();
  }

  /// Asynchronously loads the license text from the 'LICENSE' asset file.
  ///
  /// Updates [_licenseText] with the content of the file upon successful loading.
  /// If loading fails (e.g., file not found or not declared in assets),
  /// [_licenseText] is updated with an error message.
  Future<void> _loadLicense() async {
    try {
      final String licenseContent = await rootBundle.loadString('LICENSE');
      if (mounted) { // Check if the widget is still in the widget tree.
        setState(() {
          _licenseText = licenseContent;
        });
      }
    } catch (e) {
      if (mounted) { // Check if the widget is still in the widget tree.
        setState(() {
          // Error message in French, as per original code.
          _licenseText =
          "Erreur lors du chargement de la licence.\n\nVérifiez que le fichier LICENSE existe à la racine du projet et est déclaré dans les assets de pubspec.yaml si nécessaire.\n\nErreur: $e";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Licence d\'Utilisation')), // AppBar title in French.
      body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          // Display the loaded license text or error/loading message.
          // Uses a monospace font for better readability of license text.
          child: Text(
              _licenseText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace')
          )
      ),
    );
  }
}
