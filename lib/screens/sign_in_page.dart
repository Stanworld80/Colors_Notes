import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart'; // For displaying SVG images like the Google logo.
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:colors_notes/l10n/app_localizations.dart'; // For localized strings.

import '../services/auth_service.dart';
import '../widgets/auth_page_footer.dart'; // Common footer for authentication pages.

/// Logger instance for this page.
final _loggerPage = Logger(printer: PrettyPrinter(methodCount: 0, printTime: true));

/// A StatefulWidget screen for user sign-in.
///
/// This page provides options for users to sign in using their email and password,
/// or via Google Sign-In. It includes form validation and loading indicators
/// during authentication attempts.
class SignInPage extends StatefulWidget {
  /// Creates an instance of [SignInPage].
  const SignInPage({super.key});

  @override
  _SignInPageState createState() => _SignInPageState();
}

/// The state for the [SignInPage].
///
/// Manages the sign-in form, input controllers, loading states for different
/// sign-in methods, and password visibility.
class _SignInPageState extends State<SignInPage> {
  /// Global key for the sign-in form to manage validation and state.
  final _formKey = GlobalKey<FormState>();
  /// Controller for the email input field.
  final _emailController = TextEditingController();
  /// Controller for the password input field.
  final _passwordController = TextEditingController();
  /// Flag to indicate if email/password sign-in is in progress.
  bool _isLoading = false;
  /// Flag to indicate if Google Sign-In is in progress.
  bool _isLoadingGoogle = false;
  /// Flag to toggle password visibility.
  bool _obscurePassword = true;


  @override
  void dispose() {
    // Dispose controllers when the widget is removed from the widget tree.
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Attempts to sign in the user with their email and password.
  ///
  /// Validates the form. If valid, it calls the [AuthService] to authenticate.
  /// Navigation upon successful sign-in is handled by [AuthGate].
  /// Displays an error message on failure.
  Future<void> _signInWithEmail() async {
    final l10n = AppLocalizations.of(context)!; // Get l10n instance
    if (_formKey.currentState!.validate()) {
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }
      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        await authService.signInWithEmailAndPassword(
            _emailController.text.trim(),
            _passwordController.text.trim()
        );
        _loggerPage.i("Sign-in attempt successful for ${_emailController.text.trim()}"); // Log message in English
        // Navigation is handled by AuthGate after a successful authentication state change.
      } catch (e) {
        _loggerPage.e("Email sign-in error: ${e.toString()}"); // Log message in English
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.genericAuthErrorSnackbar), backgroundColor: Colors.redAccent) // MODIFIED
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  /// Attempts to sign in the user using Google Sign-In.
  ///
  /// Calls the [AuthService] to initiate the Google Sign-In flow.
  /// Navigation upon successful sign-in is handled by [AuthGate].
  /// Displays an error message on failure.
  Future<void> _signInWithGoogle() async {
    final l10n = AppLocalizations.of(context)!; // Get l10n instance
    if (mounted) {
      setState(() {
        _isLoadingGoogle = true;
      });
    }
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signInWithGoogle();
      _loggerPage.i("Google sign-in attempt successful."); // Log message in English
      // Navigation is handled by AuthGate after a successful authentication state change.
    } catch (e) {
      _loggerPage.e("Google sign-in error: ${e.toString()}"); // Log message in English
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.genericAuthErrorSnackbar), backgroundColor: Colors.redAccent) // MODIFIED
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingGoogle = false;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  l10n.appName, // Uses a localization key for "Colors & Notes"
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Theme.of(context).primaryColor),
                ),
                const SizedBox(height: 30),
                // Email Text Field
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: l10n.emailLabel, // Uses a localization key for "Email"
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty || !value.contains('@') || !value.contains('.')) {
                      return l10n.emailValidationError; // Uses a localization key for "Veuillez entrer une adresse e-mail valide."
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Password Text Field
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: l10n.passwordLabel, // Uses a localization key for "Mot de passe"
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                      onPressed: () {
                        if (mounted) {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        }
                      },
                    ),
                  ),
                  obscureText: _obscurePassword,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l10n.passwordValidationError; // Uses a localization key for "Veuillez entrer votre mot de passe."
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                // Email Sign-In Button or Loading Indicator
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                  onPressed: _signInWithEmail,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50), // Full width button
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(l10n.signInButton, style: const TextStyle(fontSize: 16)), // Uses a localization key for "Se connecter"
                ),
                // "Or" Separator
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Row(
                    children: <Widget>[
                      const Expanded(child: Divider(thickness: 1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0),
                        child: Text(
                            l10n.orSeparator, // Uses a localization key for "ou"
                            style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500)
                        ),
                      ),
                      const Expanded(child: Divider(thickness: 1)),
                    ],
                  ),
                ),
                // Google Sign-In Button or Loading Indicator
                _isLoadingGoogle
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                  onPressed: _signInWithGoogle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black.withOpacity(0.70), // Text color for Google button
                    minimumSize: const Size(double.infinity, 50), // Full width button
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        side: BorderSide(color: Colors.grey.shade400) // Border for Google button
                    ),
                    elevation: 1.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Google logo SVG asset.
                      SvgPicture.asset('assets/signin-assets/Web/svg/light/web_light_sq_na.svg'),
                      const SizedBox(width: 12),
                      Text(
                          l10n.signInWithGoogleButton, // Uses a localization key for "Se connecter avec Google"
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30), // Spacing before navigation links
                // Link to Registration Page
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/register');
                  },
                  child: Text(l10n.noAccountYetSignUp), // Uses a localization key for "Pas encore de compte ? S'inscrire"
                ),
                const SizedBox(height: 24), // Spacing before footer
                const AuthPageFooter(), // Common footer for authentication pages
              ],
            ),
          ),
        ),
      ),
    );
  }
}