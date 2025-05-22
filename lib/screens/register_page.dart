// lib/screens/register_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:colors_notes/l10n/app_localizations.dart'; // AJOUTÉ

import '../services/auth_service.dart';
import '../widgets/auth_page_footer.dart';

final _loggerPage = Logger(printer: PrettyPrinter(methodCount: 0, printTime: true));

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _displayNameController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  String? _validatePassword(String? value, AppLocalizations l10n) { // AJOUTÉ l10n
    if (value == null || value.isEmpty) {
      return l10n.registerPagePasswordValidatorEmpty; // MODIFIÉ
    }
    if (value.length < 8) {
      return l10n.registerPagePasswordValidatorLength; // MODIFIÉ
    }
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return l10n.registerPagePasswordValidatorUppercase; // MODIFIÉ
    }
    if (!value.contains(RegExp(r'[a-z]'))) {
      return l10n.registerPagePasswordValidatorLowercase; // MODIFIÉ
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      return l10n.registerPagePasswordValidatorDigit; // MODIFIÉ
    }
    if (!value.contains(RegExp(r'[+\-*_#=@%:$]'))) {
      return l10n.registerPagePasswordValidatorSpecialChar; // MODIFIÉ
    }
    return null;
  }

  Future<void> _signUp() async {
    final l10n = AppLocalizations.of(context)!; // AJOUTÉ
    if (_formKey.currentState!.validate()) {
      if (_passwordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.registerPageConfirmPasswordValidatorMismatch), backgroundColor: Colors.orangeAccent) // MODIFIÉ
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
        final navigator = Navigator.of(context);

        await authService.signUpWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text.trim(),
          _displayNameController.text.trim(),
        );

        _loggerPage.i('Inscription réussie pour ${_emailController.text.trim()}');

        if (mounted) {
          navigator.pushNamedAndRemoveUntil('/', (Route<dynamic> route) => false);
        }
      } catch (e) {
        if (mounted) {
          _loggerPage.e('Error during sign-up on RegisterPage: ${e.toString()}'); // MODIFIED log to English
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!; // AJOUTÉ

    return Scaffold(
      appBar: AppBar(title: Text(l10n.registerPageTitle)), // MODIFIÉ
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                    l10n.registerPageHeading, // MODIFIÉ
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Theme.of(context).primaryColor)
                ),
                const SizedBox(height: 30),
                TextFormField(
                  controller: _displayNameController,
                  decoration: InputDecoration(
                      labelText: l10n.registerPageDisplayNameLabel, // MODIFIÉ
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.person_outline)
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) { // MODIFIÉ pour trim()
                      return l10n.registerPageDisplayNameValidatorEmpty; // MODIFIÉ
                    }
                    if (value.trim().length < 3) { // MODIFIÉ pour trim()
                      return l10n.registerPageDisplayNameValidatorTooShort; // MODIFIÉ
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                      labelText: l10n.emailLabel,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.email_outlined)
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty || !value.contains('@') || !value.contains('.')) {
                      return l10n.emailValidationError;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: l10n.passwordLabel,
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
                  validator: (value) => _validatePassword(value, l10n), // MODIFIÉ
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: l10n.registerPageConfirmPasswordLabel, // MODIFIÉ
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
                      return l10n.registerPageConfirmPasswordValidatorEmpty; // MODIFIÉ
                    }
                    if (value != _passwordController.text) {
                      return l10n.registerPageConfirmPasswordValidatorMismatch; // MODIFIÉ
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                  onPressed: _signUp,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(l10n.registerPageSignUpButton, style: const TextStyle(fontSize: 16)), // MODIFIÉ
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    } else {
                      Navigator.pushReplacementNamed(context, '/signin');
                    }
                  },
                  child: Text(l10n.registerPageAlreadyHaveAccountLink), // MODIFIÉ
                ),
                const SizedBox(height: 30),
                const AuthPageFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
