import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:colors_notes/l10n/app_localizations.dart';

/// A widget that asynchronously loads and displays the application's
/// version and build number.
class AppVersionDisplay extends StatefulWidget {
  /// The text style to be applied to the version string.
  ///
  /// If null, a default style from the current theme's `bodySmall`
  /// with a grey color will be used.
  final TextStyle? style;

  /// How the text should be aligned horizontally.
  ///
  /// Defaults to [TextAlign.center].
  final TextAlign textAlign;

  /// Creates an [AppVersionDisplay] widget.
  const AppVersionDisplay({super.key, this.style, this.textAlign = TextAlign.center});

  @override
  State<AppVersionDisplay> createState() => _AppVersionDisplayState();
}

/// The state for the [AppVersionDisplay] widget.
///
/// Manages the loading of package information and the display of the version string.
class _AppVersionDisplayState extends State<AppVersionDisplay> {
  String _version = "";
  String _buildNumber = "";
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadVersionInfo();
  }

  /// Asynchronously loads package information (version and build number).
  ///
  /// Updates state variables upon successful loading or error.
  Future<void> _loadVersionInfo() async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _version = packageInfo.version;
          _buildNumber = packageInfo.buildNumber;
          _isLoading = false;
        });
      }
    } catch (e) {
      // In a real application, you might want to log this error.
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const env = String.fromEnvironment('APP_ENV', defaultValue: '???');
    String appEnv = "";
    if (appEnv != "prod") {
      appEnv = " ($env)";
    }

    String displayText;

    if (_isLoading) {
      displayText = "${l10n.versionLoading}$appEnv";
    } else if (_hasError) {
      displayText = "${l10n.versionUnavailable}$appEnv";
    } else {
      displayText = "${l10n.versionBuildFormat(_version, _buildNumber)}$appEnv";
    }

    final textStyle = widget.style ?? Theme
        .of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: Colors.grey[600]);

    return Text(displayText, style: textStyle, textAlign: widget.textAlign);
  }
}
