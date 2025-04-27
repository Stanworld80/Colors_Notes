import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Pour User si besoin
// Importer vos modèles créés à l'étape 2
import '../models/app_user.dart';
import '../models/agenda.dart';
import '../models/note.dart';
import '../models/palette.dart'; // Si vous avez un modèle Palette séparé
import '../models/color_data.dart';

class FirestoreService {
  // Instance de Firestore
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- Gestion des Utilisateurs ---

  /// Crée ou met à jour le document utilisateur dans Firestore après l'inscription/connexion
  Future<void> createUserDocument(User user) async {
    // Utilise l'UID de l'utilisateur comme ID du document
    final userRef = _db.collection('users').doc(user.uid);

    // Vérifie si l'utilisateur existe déjà pour ne pas écraser le rôle si modifié
    final docSnapshot = await userRef.get();

    if (!docSnapshot.exists) {
      // Crée l'AppUser seulement si le document n'existe pas
      AppUser newUser = AppUser(
        id: user.uid,
        email: user.email ?? 'no-email@example.com', // Fournir une valeur par défaut
        role: 'Utilisateur', // Rôle par défaut à la création
      );
      await userRef.set(newUser.toJson());
      print("User document created for ${user.uid}");
    } else {
      print("User document already exists for ${user.uid}");
      // Optionnel : mettre à jour l'email s'il a changé ?
      // await userRef.update({'email': user.email});
    }
  }

  /// Récupère les informations de l'AppUser depuis Firestore
  Future<AppUser?> getAppUser(String userId) async {
    final docRef = _db.collection('users').doc(userId);
    final snapshot = await docRef.get();
    if (snapshot.exists) {
      return AppUser.fromFirestore(snapshot as DocumentSnapshot<Map<String, dynamic>>);
    }
    return null;
  }


  // --- Gestion des Agendas ---

  /// Crée un nouvel agenda pour un utilisateur donné
  Future<DocumentReference> createAgenda(String userId, Agenda agendaData) async {
    // Assurez-vous que l'objet Agenda contient bien le userId correct avant de l'envoyer
    // La méthode toJson() s'occupe de convertir l'Agenda en Map
    if (agendaData.userId != userId) {
      throw Exception("Mismatch between provided userId and agendaData.userId");
    }
    // Ajoute un nouveau document avec un ID généré automatiquement
    return await _db.collection('agendas').add(agendaData.toJson());
  }

  /// Récupère le flux (Stream) des agendas d'un utilisateur
  Stream<List<Agenda>> getUserAgendasStream(String userId) {
    return _db
        .collection('agendas')
        .where('userId', isEqualTo: userId) // Filtre par utilisateur
    // Optionnel: trier par nom, date, etc.
    // .orderBy('name')
        .snapshots() // Retourne un Stream qui se met à jour automatiquement
        .map((snapshot) => snapshot.docs
        .map((doc) => Agenda.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
        .toList());
  }

  /// Met à jour le nom d'un agenda
  Future<void> updateAgendaName(String agendaId, String newName) async {
    await _db.collection('agendas').doc(agendaId).update({'name': newName});
  }

  /// Met à jour la palette instance d'un agenda
  Future<void> updateAgendaPalette(String agendaId, Palette newPalette) async {
    await _db.collection('agendas').doc(agendaId).update({
      'embeddedPaletteInstance': newPalette.toJson()
    });
  }

  /// Supprime un agenda (et potentiellement ses notes associées - voir ci-dessous)
  Future<void> deleteAgenda(String agendaId) async {
    // !! IMPORTANT: Implémenter la suppression des notes associées (SF-AGENDA-06b) !!
    // Cela nécessite une requête pour trouver les notes puis les supprimer
    // (peut nécessiter une transaction ou un traitement par lots)
    print("--- TODO: Implement deletion of notes for agenda $agendaId ---");
    // Exemple simple (pourrait être inefficace sur beaucoup de notes):
    // QuerySnapshot notesSnapshot = await _db.collection('notes').where('agendaId', isEqualTo: agendaId).get();
    // WriteBatch batch = _db.batch();
    // for (DocumentSnapshot doc in notesSnapshot.docs) {
    //   batch.delete(doc.reference);
    // }
    // await batch.commit();

    // Ensuite, supprimer l'agenda lui-même
    await _db.collection('agendas').doc(agendaId).delete();
  }


  // --- Gestion des Notes ---

  /// Crée une nouvelle note
  Future<DocumentReference> createNote(Note noteData) async {
    // La méthode toJson() convertit la Note en Map
    return await _db.collection('notes').add(noteData.toJson());
  }

  /// Récupère le flux (Stream) des notes pour un agenda spécifique
  Stream<List<Note>> getAgendaNotesStream(String agendaId) {
    return _db
        .collection('notes')
        .where('agendaId', isEqualTo: agendaId)
        .orderBy('createdAt', descending: true) // Tri par défaut (SF-VIEW-02)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => Note.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
        .toList());
  }

  /// Met à jour le commentaire d'une note
  Future<void> updateNoteComment(String noteId, String newComment) async {
    await _db.collection('notes').doc(noteId).update({
      'comment': newComment,
      'commentUpdatedAt': Timestamp.now(), // Mettre à jour la date de modification
    });
  }

  /// Supprime une note
  Future<void> deleteNote(String noteId) async {
    await _db.collection('notes').doc(noteId).delete();
  }


// --- Gestion des Palettes Modèles Personnelles (SF-PALETTE-08) ---
// À implémenter plus tard : createPaletteModel, getUserPaletteModelsStream, updatePaletteModel, deletePaletteModel...
// Ces modèles seraient dans une collection séparée, par exemple 'palette_models'.

}