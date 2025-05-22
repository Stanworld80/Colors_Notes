import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:colors_notes/l10n/app_localizations.dart';

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
  String? _licenseText;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorDetails = "";

  @override
  void initState() {
    super.initState();
    _loadLicense();
  }

  /// Asynchronously loads the license text from the 'LICENSE' asset file.
  ///
  /// Updates state with the content of the file upon successful loading or an error message if loading fails.
  Future<void> _loadLicense() async {
    try {
      final String licenseContent = await rootBundle.loadString('LICENSE');
      if (mounted) { // Check if the widget is still in the widget tree.
        setState(() {
          _licenseText = licenseContent;
          _isLoading = false;
          _hasError = false;
        });
      }
    } catch (e) {
      if (mounted) { // Check if the widget is still in the widget tree.
        setState(() {
          _errorDetails = e.toString();
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    Widget bodyChild;

    if (_isLoading) {
      bodyChild = Center(child: Text(l10n.loadingLicense));
    } else if (_hasError) {
      bodyChild = Text(
        l10n.errorLoadingLicense(_errorDetails),
        style: const TextStyle(color: Colors.red),
      );
    } else {
      bodyChild = Text(
        _licenseText ?? '', // Should not be null if not loading and no error
        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.licensePageTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: bodyChild,
      ),
    );
  }
}
