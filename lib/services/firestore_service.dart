import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Pour User si besoin
// Importer vos modèles créés à l'étape 2
import '../models/app_user.dart';
import '../models/agenda.dart';
import '../models/note.dart';
import '../models/palette.dart';
import '../models/palette_model.dart'; // Si vous avez un modèle Palette séparé
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
      return AppUser.fromFirestore(snapshot);
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
    print("Deleting notes for agenda $agendaId...");
    // 1. Trouver et supprimer les notes associées
    final WriteBatch batch = _db.batch();
    final notesSnapshot = await _db.collection('notes').where('agendaId', isEqualTo: agendaId).get();
    for (final doc in notesSnapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit(); // Exécuter la suppression par lots
    print("${notesSnapshot.size} notes deleted.");

    // 2. Supprimer l'agenda lui-même
    await _db.collection('agendas').doc(agendaId).delete();
    print("Agenda $agendaId deleted.");
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


  /// Crée un nouveau modèle de palette
  Future<DocumentReference> createPaletteModel(PaletteModel model) async {
    // Assurez-vous que le userId est correct
    return await _db.collection('palette_models').add(model.toJson());
  }

  /// Récupère le flux des modèles de palettes d'un utilisateur
  Stream<List<PaletteModel>> getUserPaletteModelsStream(String userId) {
    return _db
        .collection('palette_models')
        .where('userId', isEqualTo: userId)
        .orderBy('name') // Trier par nom par exemple
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => PaletteModel.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
        .toList());
  }

  /// Met à jour un modèle de palette existant (nom et/ou couleurs)
  Future<void> updatePaletteModel(String modelId, String newName, List<ColorData> newColors) async {
    // Valider la taille de la palette ici ou avant d'appeler
    if (newColors.length < PaletteModel.minColors || newColors.length > PaletteModel.maxColors) {
      throw Exception("La palette doit contenir entre ${PaletteModel.minColors} et ${PaletteModel.maxColors} couleurs.");
    }
    await _db.collection('palette_models').doc(modelId).update({
      'name': newName,
      'colors': newColors.map((c) => c.toJson()).toList(),
    });
  }

  /// Renomme un modèle de palette existant
  Future<void> renamePaletteModel(String modelId, String newName) async {
    await _db.collection('palette_models').doc(modelId).update({'name': newName});
  }


  /// Supprime un modèle de palette
  Future<void> deletePaletteModel(String modelId) async {
    await _db.collection('palette_models').doc(modelId).delete();
    // Pas besoin de supprimer autre chose, car ce ne sont que des modèles
  }

  Future<bool> checkPaletteModelNameExists(String userId, String name, {String? modelIdToExclude}) async {
    print("Checking if palette model name '$name' exists for user $userId (excluding $modelIdToExclude)");
    // Requête pour trouver les modèles avec le même userId ET le même nom
    var query = _db.collection('palette_models')
        .where('userId', isEqualTo: userId)
        .where('name', isEqualTo: name) // Firestore est sensible à la casse par défaut
        .limit(1); // On a juste besoin de savoir s'il y en a au moins un

    try {
      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        print("Name '$name' does not exist.");
        return false; // Le nom n'existe pas
      } else {
        // Le nom existe. Vérifier si c'est le document qu'on est en train de modifier.
        if (modelIdToExclude != null && snapshot.docs.first.id == modelIdToExclude) {
          print("Name '$name' exists, but it's the model being edited ($modelIdToExclude). Allowed.");
          return false; // C'est le modèle actuel qu'on modifie, donc ce n'est pas un conflit
        } else {
          print("Name '$name' already exists for a different model.");
          return true; // Le nom existe et appartient à un AUTRE modèle
        }
      }
    } catch (e) {
      print("Error checking palette model name existence: $e");
      // En cas d'erreur, on pourrait retourner true pour empêcher la sauvegarde par sécurité,
      // ou false pour permettre de continuer mais logger l'erreur. Retourner false est peut-être moins bloquant.
      return false; // Ou `throw e;` pour propager l'erreur
    }
  }

}