import 'package:flutter/material.dart';
import 'package:soa_starter/services/auth_service.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  _AuthGate createState() => _AuthGate();
}

class _AuthGate extends State<AuthGate> {
  String? _errorMessage;

  // Instance de notre AuthService (avec GoogleSignIn)
  final AuthService _authService = AuthService();

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
      appBar: AppBar(title: const Text('Welcome')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [ if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 15.0),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
            const Text(
              'Please sign in or register',
              style: TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/signin');
              },
              child: const Text('Sign In'),

            ),
            const SizedBox(height: 20),
            // Bouton de connexion via Google
            ElevatedButton.icon(
              onPressed: _signInWithGoogle,
              icon: const Icon(Icons.account_circle),
              label: const Text('Sign In with Google'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/register');
              },
              child: const Text('Register'),
            ),
          ],
        ),
      ),
    );
  }
}
