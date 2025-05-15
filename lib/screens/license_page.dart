import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

class ColorsNotesLicensePage extends StatefulWidget {
  const ColorsNotesLicensePage({Key? key}) : super(key: key);

  @override
  _ColorsNotesLicensePageState createState() => _ColorsNotesLicensePageState();
}

class _ColorsNotesLicensePageState extends State<ColorsNotesLicensePage> {
  String _licenseText = "Chargement de la licence...";

  @override
  void initState() {
    super.initState();
    _loadLicense();
  }

  Future<void> _loadLicense() async {
    try {
      final String licenseContent = await rootBundle.loadString('LICENSE');
      if (mounted) {
        setState(() {
          _licenseText = licenseContent;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _licenseText =
              "Erreur lors du chargement de la licence.\n\nVérifiez que le fichier LICENSE existe à la racine du projet et est déclaré dans les assets de pubspec.yaml si nécessaire.\n\nErreur: $e";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Licence d\'Utilisation')),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16.0), child: Text(_licenseText, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'))),
    );
  }
}
