// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';
import '../models/agenda.dart';
import '../models/note.dart';
import '../models/palette.dart';
import '../models/palette_model.dart';
import '../models/color_data.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- User Management (No changes) ---
  Future<void> createUserDocument(User user) async {
    final userRef = _db.collection('users').doc(user.uid);
    final docSnapshot = await userRef.get();
    if (!docSnapshot.exists) {
      AppUser newUser = AppUser(id: user.uid, email: user.email ?? 'no-email@example.com', role: 'Utilisateur');
      await userRef.set(newUser.toJson());
      print("User document created for ${user.uid}");
    } else {
      print("User document already exists for ${user.uid}");
    }
  }

  Future<AppUser?> getAppUser(String userId) async {
    final docRef = _db.collection('users').doc(userId);
    final snapshot = await docRef.get();
    if (snapshot.exists) {
      return AppUser.fromFirestore(snapshot);
    }
    return null;
  }

  // --- Agenda Management (No changes) ---
  Future<DocumentReference> createAgenda(String userId, Agenda agendaData) async {
    if (agendaData.userId != userId) {
      throw Exception("Mismatch between provided userId and agendaData.userId");
    }
    return await _db.collection('agendas').add(agendaData.toJson());
  }

  Stream<List<Agenda>> getUserAgendasStream(String userId) {
    return _db
        .collection('agendas')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Agenda.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>)).toList());
  }

  Future<void> updateAgendaName(String agendaId, String newName) async {
    await _db.collection('agendas').doc(agendaId).update({'name': newName});
  }

  Future<void> updateAgendaPalette(String agendaId, Palette newPalette) async {
    await _db.collection('agendas').doc(agendaId).update({'embeddedPaletteInstance': newPalette.toJson()});
  }

  Future<void> deleteAgenda(String agendaId) async {
    print("Deleting notes for agenda $agendaId...");
    final WriteBatch batch = _db.batch();
    final notesSnapshot = await _db.collection('notes').where('agendaId', isEqualTo: agendaId).get();
    for (final doc in notesSnapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    print("${notesSnapshot.size} notes deleted.");
    await _db.collection('agendas').doc(agendaId).delete();
    print("Agenda $agendaId deleted.");
  }

  Future<void> updateAgendaPaletteInstance(String agendaId, Palette newPaletteInstance) async {
    final agendaRef = _db.collection('agendas').doc(agendaId);
    await agendaRef.update({'embeddedPaletteInstance': newPaletteInstance.toJson()});
    print("Palette instance updated for agenda $agendaId");
  }

  // --- Note Management (MODIFIED) ---
  Future<DocumentReference> createNote(Note noteData) async {
    return await _db.collection('notes').add(noteData.toJson());
  }

  /// Récupère le flux (Stream) des notes pour un agenda spécifique,
  /// avec option de tri par eventTimestamp.
  Stream<List<Note>> getAgendaNotesStream(String agendaId, {bool descending = true}) {
    // Ajout du paramètre descending
    return _db
        .collection('notes')
        .where('agendaId', isEqualTo: agendaId)
        // Utiliser le paramètre pour contrôler l'ordre de tri
        .orderBy('eventTimestamp', descending: descending) // MODIFIÉ
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Note.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>)).toList());
  }

  Future<void> updateNoteDetails(String noteId, {String? newComment, Timestamp? newEventTimestamp}) async {
    Map<String, dynamic> dataToUpdate = {};
    if (newComment != null) {
      dataToUpdate['comment'] = newComment;
    }
    if (newEventTimestamp != null) {
      dataToUpdate['eventTimestamp'] = newEventTimestamp;
    }
    if (dataToUpdate.isEmpty) {
      print("updateNoteDetails called with no changes for note $noteId.");
      return;
    }
    await _db.collection('notes').doc(noteId).update(dataToUpdate);
  }

  Future<void> deleteNote(String noteId) async {
    await _db.collection('notes').doc(noteId).delete();
  }

  // --- Palette Model Management (No changes) ---
  Future<DocumentReference> createPaletteModel(PaletteModel model) async {
    return await _db.collection('palette_models').add(model.toJson());
  }

  Stream<List<PaletteModel>> getUserPaletteModelsStream(String userId) {
    return _db
        .collection('palette_models')
        .where('userId', isEqualTo: userId)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => PaletteModel.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>)).toList());
  }

  Future<void> updatePaletteModel(String modelId, String newName, List<ColorData> newColors) async {
    if (newColors.length < PaletteModel.minColors || newColors.length > PaletteModel.maxColors) {
      throw Exception("La palette doit contenir entre ${PaletteModel.minColors} et ${PaletteModel.maxColors} couleurs.");
    }
    await _db.collection('palette_models').doc(modelId).update({'name': newName, 'colors': newColors.map((c) => c.toJson()).toList()});
  }

  Future<void> renamePaletteModel(String modelId, String newName) async {
    await _db.collection('palette_models').doc(modelId).update({'name': newName});
  }

  Future<void> deletePaletteModel(String modelId) async {
    await _db.collection('palette_models').doc(modelId).delete();
  }

  Future<bool> checkPaletteModelNameExists(String userId, String name, {String? modelIdToExclude}) async {
    print("Checking if palette model name '$name' exists for user $userId (excluding $modelIdToExclude)");
    var query = _db.collection('palette_models').where('userId', isEqualTo: userId).where('name', isEqualTo: name).limit(1);
    try {
      final snapshot = await query.get();
      if (snapshot.docs.isEmpty) {
        print("Name '$name' does not exist.");
        return false;
      } else {
        if (modelIdToExclude != null && snapshot.docs.first.id == modelIdToExclude) {
          print("Name '$name' exists, but it's the model being edited ($modelIdToExclude). Allowed.");
          return false;
        } else {
          print("Name '$name' already exists for a different model.");
          return true;
        }
      }
    } catch (e) {
      print("Error checking palette model name existence: $e");
      return false;
    }
  }
}
