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

/// The state for the [AppVersionDisplay] widget.
///
/// Manages the loading of package information and the display of the version string.
class _AppVersionDisplayState extends State<AppVersionDisplay> {
  /// The text to display, showing the version and build number or a loading/error message.
  String _versionText = 'Loading...'; // Initial text while loading version information.

  @override
  void initState() {
    super.initState();
    _loadVersionInfo();
  }

  /// Asynchronously loads package information (version and build number).
  ///
  /// Updates the [_versionText] state with the formatted version string upon
  /// successful loading, or an error message if loading fails.
  Future<void> _loadVersionInfo() async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      if (mounted) { // Check if the widget is still in the widget tree.
        setState(() {
          _versionText = 'v${packageInfo.version} (Build ${packageInfo.buildNumber})';
        });
      }
    } catch (e) {
      // In a real application, you might want to log this error.
      // For example: _logger.e('Failed to load version info: $e');
      if (mounted) { // Check if the widget is still in the widget tree.
        setState(() {
          _versionText = 'Version unavailable';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine the text style: use the provided style or a default one.
    final textStyle = widget.style ??
        Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]);

    return Text(
      _versionText,
      style: textStyle,
      textAlign: widget.textAlign,
    );
  }
}
