import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';

import '../services/auth_service.dart';
import 'about_page.dart';
import 'license_page.dart';

final _loggerPage = Logger(printer: PrettyPrinter(methodCount: 0, printTime: true));

class RegisterPage extends StatefulWidget {
  RegisterPage({Key? key}) : super(key: key);

  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final authService = Provider.of<AuthService>(context, listen: false);

        await authService.signUpWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text.trim(),
          _displayNameController.text.trim(),
        );

        if (mounted) {
          _loggerPage.i('Inscription réussie pour ${_emailController.text.trim()}');
          // AuthGate gère la navigation
        }

      } catch (e) {
        if (mounted) {
          _loggerPage.e('Erreur lors de l\'inscription sur RegisterPage: ${e.toString()}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
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
      appBar: AppBar(title: Text('Créer un compte')),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text("Rejoignez Colors & Notes", style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Theme.of(context).primaryColor)),
                SizedBox(height: 30),
                TextFormField(
                  controller: _displayNameController,
                  decoration: InputDecoration(labelText: 'Nom d\'affichage', border: OutlineInputBorder()),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez entrer votre nom d\'affichage.';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
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
                    if (value == null || value.isEmpty || value.length < 6) {
                      return 'Le mot de passe doit contenir au moins 6 caractères.';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 24),
                _isLoading
                    ? CircularProgressIndicator()
                    : ElevatedButton(
                  onPressed: _signUp,
                  child: Text('S\'inscrire'),
                  style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50)),
                ),
                SizedBox(height: 20),
                TextButton(
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    } else {
                      Navigator.pushReplacementNamed(context, '/signin');
                    }
                  },
                  child: Text('Déjà un compte ? Se connecter'),
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
