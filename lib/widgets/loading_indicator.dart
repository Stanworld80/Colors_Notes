import 'package:flutter/material.dart';

/// A simple widget that displays a centered circular progress indicator,
/// often used as an overlay during loading operations.
///
/// This widget creates a semi-transparent background to dim the underlying
/// content and centers a [CircularProgressIndicator].
class LoadingIndicator extends StatelessWidget {
  /// Creates a [LoadingIndicator] widget.
  ///
  /// The [key] is optional and is passed to the superclass.
  const LoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      // Apply a semi-transparent black color to the background.
      // This creates a dimming effect over the content below the indicator.
      color: Colors.black.withOpacity(0.1),
      // Center the CircularProgressIndicator within the container.
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}
