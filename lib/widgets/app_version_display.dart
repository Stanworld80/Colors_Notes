// File: lib/widgets/app_version_display.dart
// (This is the reusable widget to display the app version)

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
  const AppVersionDisplay({
    super.key,
    this.style,
    this.textAlign = TextAlign.center,
  });

  @override
  State<AppVersionDisplay> createState() => _AppVersionDisplayState();
}

class _AppVersionDisplayState extends State<AppVersionDisplay> {
  String _versionText = 'Loading...'; // Initial text while loading

  @override
  void initState() {
    super.initState();
    _loadVersionInfo();
  }

  /// Loads the package information and updates the version text.
  Future<void> _loadVersionInfo() async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      if (mounted) { // Check if the widget is still in the tree
        setState(() {
          _versionText = 'v${packageInfo.version} (Build ${packageInfo.buildNumber})';
        });
      }
    } catch (e) {
      // Log the error if a logger is available, or print for debugging
      // print('Failed to load version info: $e');
      if (mounted) { // Check if the widget is still in the tree
        setState(() {
          _versionText = 'Version unavailable';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use the provided style, or default to a subtle grey text style
    final textStyle = widget.style ??
        Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]);

    return Text(
      _versionText,
      style: textStyle,
      textAlign: widget.textAlign,
    );
  }
}