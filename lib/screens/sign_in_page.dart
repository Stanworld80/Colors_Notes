import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:url_launcher/url_launcher.dart'; // Importez url_launcher
import 'package:package_info_plus/package_info_plus.dart';

import '../services/auth_service.dart';
import 'about_page.dart';
import 'license_page.dart';
import 'package:colors_notes/l10n/app_localizations.dart';

final _loggerPage = Logger(printer: PrettyPrinter(methodCount: 0, printTime: true));

class SignInPage extends StatefulWidget {
  const SignInPage({Key? key}) : super(key: key);

  @override
  _SignInPageState createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isLoadingGoogle = false;
  bool _obscurePassword = true;

 final String _apkUrl = "https://www.stanworld.org/main/web/ColorsNotes-1.5.4.apk";
 // final String _apkUrl = "https://colorsnotes-e9142.web.app/apk/ColorsNotes-1.5.4-unavaible.txt";

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithEmail() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        await authService.signInWithEmailAndPassword(_emailController.text.trim(), _passwordController.text.trim());
        _loggerPage.i("Tentative de connexion réussie pour ${_emailController.text.trim()}");
        // La navigation est gérée par AuthGate après un changement d'état d'authentification réussi
      } catch (e) {
        _loggerPage.e("Erreur connexion email: ${e.toString()}");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent));
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

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoadingGoogle = true;
    });
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signInWithGoogle();
      _loggerPage.i("Tentative de connexion Google réussie.");
      // La navigation est gérée par AuthGate
    } catch (e) {
      _loggerPage.e("Erreur connexion Google: ${e.toString()}");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingGoogle = false;
        });
      }
    }
  }

  Future<void> _launchAPKUrl() async {
    if (await canLaunchUrl(Uri.parse(_apkUrl))) {
      await launchUrl(Uri.parse(_apkUrl), mode: LaunchMode.externalApplication);
    } else {
      _loggerPage.e("Impossible de lancer l'URL: $_apkUrl");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Impossible d'ouvrir le lien de téléchargement.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Accès aux traductions
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.signInPageTitle), // Exemple d'utilisation d'une clé de traduction
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                    l10n.appName, // Clé pour "Colors & Notes"
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Theme.of(context).primaryColor)
                ),
                const SizedBox(height: 30),
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                      labelText: l10n.emailLabel, // Clé pour "Email"
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.email_outlined)
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty || !value.contains('@') || !value.contains('.')) {
                      return l10n.emailValidationError; // Clé pour "Veuillez entrer une adresse e-mail valide."
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: l10n.passwordLabel, // Clé pour "Mot de passe"
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  obscureText: _obscurePassword,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l10n.passwordValidationError; // Clé pour "Veuillez entrer votre mot de passe."
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                  onPressed: _signInWithEmail,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(l10n.signInButton, style: const TextStyle(fontSize: 16)), // Clé pour "Se connecter"
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Row(
                    children: <Widget>[
                      const Expanded(child: Divider(thickness: 1)), // Épaisseur réduite
                      Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0),
                          child: Text(l10n.orSeparator, style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500)) // Clé pour "ou"
                      ),
                      const Expanded(child: Divider(thickness: 1)), // Épaisseur réduite
                    ],
                  ),
                ),
                // SizedBox(height: 20), // Ajusté pour un meilleur espacement
                _isLoadingGoogle
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                  onPressed: _signInWithGoogle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black.withOpacity(0.70),
                    minimumSize: const Size(double.infinity, 50),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0), side: BorderSide(color: Colors.grey.shade400)),
                    elevation: 1.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset('assets/signin-assets/Web/svg/light/web_light_sq_na.svg'),
                      const SizedBox(width: 12),
                      Text(l10n.signInWithGoogleButton, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)), // Clé pour "Se connecter avec Google"
                    ],
                  ),
                ),
                const SizedBox(height: 30), // Espacement avant les liens
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/register');
                  },
                  child: Text(l10n.noAccountYetSignUp), // Clé pour "Pas encore de compte ? S'inscrire"
                ),
                const SizedBox(height: 20), // Espacement ajusté
                Wrap( // Utilisation de Wrap pour une meilleure gestion sur petits écrans
                  alignment: WrapAlignment.center,
                  spacing: 4.0, // Espace horizontal entre les éléments
                  runSpacing: 0.0, // Espace vertical entre les lignes (si Wrap passe à la ligne)
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const AboutPage()));
                      },
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      child: Text("A Propos", style: TextStyle(fontSize: 12, color: Colors.grey[600], decoration: TextDecoration.underline)), // Clé pour "À Propos"
                    ),
                    Text('|', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                    TextButton(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const ColorsNotesLicensePage()));
                      },
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      child: Text("License", style: TextStyle(fontSize: 12, color: Colors.grey[600], decoration: TextDecoration.underline)), // Clé pour "Licence"
                    ),

                    Text('|', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                    TextButton(
                      onPressed: _launchAPKUrl,
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      child: Text(
                          "Télécharger l'application Android",
                          style: TextStyle(fontSize: 12, color: Colors.grey[600], decoration: TextDecoration.underline)
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}