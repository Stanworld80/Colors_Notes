import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import 'main_screen.dart';
import 'sign_in_page.dart';

/// A widget that handles the authentication state of the user.
///
/// It listens to the user's authentication status from [AuthService] and
/// navigates to the appropriate screen:
/// - [MainScreen] if the user is authenticated.
/// - [SignInPage] if the user is not authenticated.
/// It also displays a loading indicator while checking the authentication state
/// or an error message if an error occurs.
class AuthGate extends StatelessWidget {
  /// Creates an [AuthGate] widget.
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // Retrieve the AuthService instance from the Provider.
    // listen: false is used because we are only interested in the service instance,
    // not in rebuilding when the service itself changes (the StreamBuilder handles UI updates).
    final authService = Provider.of<AuthService>(context, listen: false);

    return StreamBuilder<User?>(
      // Listen to the user authentication state stream from AuthService.
      stream: authService.userStream,
      builder: (context, snapshot) {
        // Display a loading indicator while waiting for the connection state.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        // Display an error message if the stream encounters an error.
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Erreur: ${snapshot.error}')), // Error message in French
          );
        }

        // If the snapshot has data, it means the user is authenticated.
        // Navigate to the MainScreen.
        if (snapshot.hasData) {
          return const MainScreen();
        } else {
          // If the snapshot has no data, the user is not authenticated.
          // Navigate to the SignInPage.
          return const SignInPage();
        }
      },
    );
  }
}
