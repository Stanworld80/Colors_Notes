import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';

import '../services/auth_service.dart';
import '../widgets/auth_page_footer.dart';

/// Logger instance for this page.
final _loggerPage = Logger(printer: PrettyPrinter(methodCount: 0, printTime: true));

/// A StatefulWidget screen for user registration.
///
/// This page provides a form for users to sign up with their display name,
/// email, and password. It includes password validation and confirmation.
class RegisterPage extends StatefulWidget {
  /// Creates an instance of [RegisterPage].
  const RegisterPage({super.key});

  @override
  _RegisterPageState createState() => _RegisterPageState();
}

/// The state for the [RegisterPage].
///
/// Manages the registration form, input controllers, loading state,
/// and password visibility toggles.
class _RegisterPageState extends State<RegisterPage> {
  /// Global key for the registration form to manage validation and state.
  final _formKey = GlobalKey<FormState>();
  /// Controller for the email input field.
  final _emailController = TextEditingController();
  /// Controller for the password input field.
  final _passwordController = TextEditingController();
  /// Controller for the confirm password input field.
  final _confirmPasswordController = TextEditingController();
  /// Controller for the display name input field.
  final _displayNameController = TextEditingController();
  /// Flag to indicate if the registration process is ongoing.
  bool _isLoading = false;
  /// Flag to toggle password visibility for the main password field.
  bool _obscurePassword = true;
  /// Flag to toggle password visibility for the confirm password field.
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    // Dispose controllers when the widget is removed from the widget tree.
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  /// Validates the password string based on predefined criteria.
  ///
  /// Criteria include minimum length, presence of uppercase, lowercase,
  /// numeric, and special characters.
  ///
  /// [value] The password string to validate.
  /// Returns a validation error message string if invalid, or `null` if valid.
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Veuillez entrer un mot de passe.'; // UI Text in French
    }
    if (value.length < 8) {
      return 'Le mot de passe doit contenir au moins 8 caractères.'; // UI Text in French
    }
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Le mot de passe doit contenir au moins une majuscule.'; // UI Text in French
    }
    if (!value.contains(RegExp(r'[a-z]'))) {
      return 'Le mot de passe doit contenir au moins une minuscule.'; // UI Text in French
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Le mot de passe doit contenir au moins un chiffre.'; // UI Text in French
    }
    // Regex for special characters.
    if (!value.contains(RegExp(r'[+\-*_#=@%:$]'))) {
      return 'Le mot de passe doit contenir au moins un caractère spécial (+-*_#=@%:\$).'; // UI Text in French
    }
    return null; // Password is valid
  }

  /// Attempts to sign up the user with the provided credentials.
  ///
  /// Validates the form. If valid, it calls the [AuthService] to register
  /// the user. On success, navigates to the home screen. On failure,
  /// displays an error message.
  Future<void> _signUp() async {
    if (_formKey.currentState!.validate()) {
      // Check if passwords match before proceeding.
      if (_passwordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Les mots de passe ne correspondent pas.'), backgroundColor: Colors.orangeAccent) // UI Text in French
        );
        return;
      }

      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }

      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        final navigator = Navigator.of(context); // Store navigator before async gap.

        await authService.signUpWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text.trim(),
          _displayNameController.text.trim(),
        );

        _loggerPage.i('Inscription réussie pour ${_emailController.text.trim()}'); // Log message in French

        if (mounted) {
          // Navigate to the home screen and remove all previous routes.
          navigator.pushNamedAndRemoveUntil('/', (Route<dynamic> route) => false);
        }
      } catch (e) {
        if (mounted) {
          _loggerPage.e('Erreur lors de l\'inscription sur RegisterPage: ${e.toString()}'); // Log message in French
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent)
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer un compte')), // UI Text in French
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                    "Rejoignez Colors & Notes", // UI Text in French
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Theme.of(context).primaryColor)
                ),
                const SizedBox(height: 30),
                // Display Name Field
                TextFormField(
                  controller: _displayNameController,
                  decoration: const InputDecoration(
                      labelText: 'Nom d\'affichage', // UI Text in French
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline)
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez entrer votre nom d\'affichage.'; // UI Text in French
                    }
                    if (value.length < 3) {
                      return 'Le nom d\'affichage doit comporter au moins 3 caractères.'; // UI Text in French
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Email Field
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                      labelText: 'Email', // UI Text in French
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email_outlined)
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty || !value.contains('@') || !value.contains('.')) {
                      return 'Veuillez entrer une adresse e-mail valide.'; // UI Text in French
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Password Field
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe', // UI Text in French
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
                  validator: _validatePassword, // Custom password validation method
                ),
                const SizedBox(height: 16),
                // Confirm Password Field
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Confirmer le mot de passe', // UI Text in French
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                      onPressed: () {
                        if (mounted) {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        }
                      },
                    ),
                  ),
                  obscureText: _obscureConfirmPassword,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez confirmer votre mot de passe.'; // UI Text in French
                    }
                    if (value != _passwordController.text) {
                      return 'Les mots de passe ne correspondent pas.'; // UI Text in French
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                // Sign Up Button or Loading Indicator
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                  onPressed: _signUp,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50), // Full width button
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('S\'inscrire et se connecter', style: TextStyle(fontSize: 16)), // UI Text in French
                ),
                const SizedBox(height: 20),
                // Link to Sign In Page
                TextButton(
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context); // Go back if possible (e.g., from sign-in page)
                    } else {
                      // Otherwise, replace current route with sign-in (e.g., if this is the initial route)
                      Navigator.pushReplacementNamed(context, '/signin');
                    }
                  },
                  child: const Text('Déjà un compte ? Se connecter'), // UI Text in French
                ),
                const SizedBox(height: 30),
                const AuthPageFooter(), // Common footer for authentication pages
              ],
            ),
          ),
        ),
      ),
    );
  }
}
