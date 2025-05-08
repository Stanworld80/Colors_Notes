// lib/widgets/loading_indicator.dart
import 'package:flutter/material.dart';

/// A simple widget that displays a centered circular progress indicator,
/// often used as an overlay during loading operations.
class LoadingIndicator extends StatelessWidget {
  /// Creates a loading indicator widget.
  const LoadingIndicator({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      // Semi-transparent background to dim the underlying content
      color: Colors.black.withOpacity(0.1),
      // Center the progress indicator
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
