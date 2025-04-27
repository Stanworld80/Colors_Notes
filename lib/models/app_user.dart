import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String id; // Correspond à l'UID de Firebase Auth
  final String email;
  final String role; // 'Utilisateur' ou 'Administrateur'

  AppUser({
    required this.id,
    required this.email,
    this.role = 'Utilisateur', // Rôle par défaut
  });

  // Méthode pour convertir un AppUser en Map pour Firestore
  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'role': role,
      // L'ID n'est généralement pas stocké DANS le document lui-même
      // mais utilisé comme ID du document.
    };
  }

  // Méthode factory pour créer un AppUser depuis un DocumentSnapshot Firestore
  factory AppUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    Map<String, dynamic> data = doc.data()!;
    return AppUser(
      id: doc.id, // Récupère l'ID du document
      email: data['email'] ?? '',
      role: data['role'] ?? 'Utilisateur',
    );
  }
}