import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:soa_starter/services/auth_service.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({Key? key}) : super(key: key);

  @override
  _SignInPageState createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _errorMessage;

  // Instance de notre AuthService (avec GoogleSignIn)
  final AuthService _authService = AuthService();

  // Méthode pour se connecter avec l'email et le mot de passe
  Future<void> _signInWithEmail() async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      // Naviguer vers la page d'accueil après la connexion
      Navigator.pushReplacementNamed(context, '/logged_homepage');
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message; // Gérer l'erreur
      });
    }
  }

  // Méthode pour se connecter avec Google
  Future<void> _signInWithGoogle() async {
    try {
      await _authService.signInWithGoogle();
      // Si l'authentification réussit, on redirige l'utilisateur
      Navigator.pushReplacementNamed(context, '/logged_homepage');
    } catch (e) {
      setState(() {
        _errorMessage = 'Google Sign-In failed. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign In')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 15.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              // Champ email
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              // Champ mot de passe
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
              ),
              const SizedBox(height: 20),
              // Bouton de connexion par email et mot de passe
              ElevatedButton(
                onPressed: _signInWithEmail,
                child: const Text('Sign In with Email'),
              ),
              const SizedBox(height: 20),
              // Bouton de connexion via Google
              ElevatedButton.icon(
                onPressed: _signInWithGoogle,
                icon: const Icon(Icons.account_circle),
                label: const Text('Sign In with Google'),
              ),
              const SizedBox(height: 20),
              // Lien vers la page d'inscription
              TextButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/register');
                },
                child: const Text("Don't have an account? Register here."),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
