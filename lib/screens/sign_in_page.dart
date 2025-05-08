import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';

import '../services/auth_service.dart';
import '../screens/about_page.dart';
import '../screens/license_page.dart';

final _loggerPage = Logger(printer: PrettyPrinter(methodCount: 0, printTime: true));

class SignInPage extends StatefulWidget {
  SignInPage({Key? key}) : super(key: key);

  @override
  _SignInPageState createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isLoadingGoogle = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithEmail() async {
    if (_formKey.currentState!.validate()) {
      setState(() { _isLoading = true; });
      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        await authService.signInWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
        _loggerPage.i("Tentative de connexion réussie pour ${_emailController.text.trim()}");
        // AuthGate gère la navigation
      } catch (e) {
        _loggerPage.e("Erreur connexion email: ${e.toString()}");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
          );
        }
      } finally {
        if (mounted) {
          setState(() { _isLoading = false; });
        }
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() { _isLoadingGoogle = true; });
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signInWithGoogle();
      _loggerPage.i("Tentative de connexion Google réussie.");
      // AuthGate gère la navigation
    } catch (e) {
      _loggerPage.e("Erreur connexion Google: ${e.toString()}");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isLoadingGoogle = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Se connecter')),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text("Colors & Notes", style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Theme.of(context).primaryColor)),
                SizedBox(height: 30),
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty || !value.contains('@')) {
                      return 'Veuillez entrer une adresse e-mail valide.';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(labelText: 'Mot de passe', border: OutlineInputBorder()),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez entrer votre mot de passe.';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 24),
                _isLoading
                    ? CircularProgressIndicator()
                    : ElevatedButton(
                  onPressed: _signInWithEmail,
                  child: Text('Se connecter'),
                  style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50)),
                ),
                SizedBox(height: 12),
                _isLoadingGoogle
                    ? CircularProgressIndicator()
                    : ElevatedButton.icon(
                  icon: Icon(Icons.login), // Icône originale
                  label: Text('Se connecter avec Google'),
                  onPressed: _signInWithGoogle,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      minimumSize: Size(double.infinity, 50)
                  ),
                ),
                SizedBox(height: 20),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/register');
                  },
                  child: Text('Pas encore de compte ? S\'inscrire'),
                ),
                SizedBox(height: 30), // Espace avant les liens discrets
                  // --- Liens discrets ajoutés ici ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => AboutPage()));
                        },
                        child: Text(
                          'À Propos',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600], // Couleur discrète
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size(0, 0), // Taille minimale pour réduire le padding autour
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap, // Réduit la zone de clic
                        ),
                      ),
                      SizedBox(width: 10), // Espace entre les liens
                      Text(
                        '|', // Séparateur
                        style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                      ),
                      SizedBox(width: 10), // Espace entre les liens
                      TextButton(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => ColorsNotesLicensePage()));
                        },
                        child: Text(
                          'Licence',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600], // Couleur discrète
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size(0, 0), // Taille minimale
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap, // Réduit la zone de clic
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
