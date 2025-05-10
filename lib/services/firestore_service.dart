// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

import '../models/app_user.dart';
import '../models/journal.dart';
import '../models/palette.dart';
import '../models/palette_model.dart';
import '../models/color_data.dart';
import '../models/note.dart';
import '../core/predefined_templates.dart';

final _logger = Logger(
  printer: PrettyPrinter(
    methodCount: 1, errorMethodCount: 8, lineLength: 120,
    colors: true, printEmojis: true, printTime: true,
  ),
);
const Uuid _uuid = Uuid();

class FirestoreService {
  final FirebaseFirestore _db;

  FirestoreService(this._db);

  Future<void> initializeNewUserData(User firebaseUser, {String? displayName, String? email}) async {
    try {
      _logger.i('Initialisation des données pour le nouvel utilisateur: ${firebaseUser.uid}');

      AppUser newUser = AppUser(
        id: firebaseUser.uid,
        email: firebaseUser.email ?? email,
        displayName: firebaseUser.displayName ?? displayName ?? 'Nouvel Utilisateur',
        registrationDate: Timestamp.now(),
      );
      await _db.collection('users').doc(newUser.id).set(newUser.toMap());
      _logger.i('Document utilisateur créé pour ${newUser.id}');

      if (predefinedPalettes.isEmpty) {
        _logger.w('Aucune palette prédéfinie disponible pour créer le journal par défaut.');
        Palette fallbackPalette = Palette(
            id: _uuid.v4(),
            name: "Palette de Base",
            colors: [ColorData(title: "Défaut", hexCode: "808080", paletteElementId: _uuid.v4(), isDefault: true)],
            userId: firebaseUser.uid, // Assigner le userId ici aussi
            isPredefined: false
        );
        Journal defaultJournal = Journal(
          id: _uuid.v4(),
          userId: firebaseUser.uid,
          name: 'Mon Premier Journal',
          palette: fallbackPalette,
          createdAt: Timestamp.now(),
          lastUpdatedAt: Timestamp.now(),
        );
        // Correction: Utiliser la collection 'journals' directement, pas en sous-collection de user pour cette structure.
        // Si la structure est users/{userId}/journals, alors la création est différente.
        // Basé sur getJournalsStream, la collection 'journals' est à la racine.
        await _db.collection('journals').doc(defaultJournal.id).set(defaultJournal.toMap());
        _logger.i('Journal par défaut créé avec palette de secours pour ${firebaseUser.uid} avec ID ${defaultJournal.id}');
        return;
      }

      PaletteModel defaultPaletteTemplate = predefinedPalettes[0];

      List<ColorData> instanceColors = defaultPaletteTemplate.colors.map((colorTemplate) {
        return ColorData(
          title: colorTemplate.title,
          hexCode: colorTemplate.hexCode,
          isDefault: colorTemplate.isDefault,
          paletteElementId: _uuid.v4(), // Générer un ID unique pour l'instance de couleur
        );
      }).toList();

      Palette paletteForJournal = Palette(
        id: _uuid.v4(), // ID unique pour l'instance de palette
        name: defaultPaletteTemplate.name, // Nom hérité du modèle
        colors: instanceColors,
        isPredefined: false, // Ce n'est pas un modèle prédéfini, mais une instance
        userId: firebaseUser.uid, // Associer l'userId à l'instance de palette
      );

      Journal defaultJournal = Journal(
        id: _uuid.v4(), // ID unique pour le journal
        userId: firebaseUser.uid,
        name: 'Mon Premier Journal',
        palette: paletteForJournal, // Instance de palette
        createdAt: Timestamp.now(),
        lastUpdatedAt: Timestamp.now(),
      );
      await _db.collection('journals').doc(defaultJournal.id).set(defaultJournal.toMap());
      _logger.i('Journal par défaut créé pour ${firebaseUser.uid} avec ID ${defaultJournal.id}');

    } catch (e, stackTrace) {
      _logger.e('Erreur initialisation données utilisateur', error: e, stackTrace: stackTrace);
      throw Exception('Échec initialisation données utilisateur: ${e.toString()}');
    }
  }

  Future<AppUser?> getUser(String uid) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        return AppUser.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e, stackTrace) {
      _logger.e('Erreur get User $uid', error: e, stackTrace: stackTrace);
      throw Exception('Impossible de récupérer les infos utilisateur.');
    }
  }

  Stream<List<Journal>> getJournalsStream(String userId) {
    try {
      return _db
          .collection('journals')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
          .map((doc) => Journal.fromMap(doc.data(), doc.id))
          .toList())
          .handleError((error, stackTrace) {
        _logger.e('Erreur stream journaux pour $userId', error: error, stackTrace: stackTrace);
        // Ne pas relancer l'erreur ici directement peut masquer le problème dans l'UI
        // Il est préférable de laisser l'erreur se propager pour que StreamBuilder puisse la gérer.
        // throw error; // Commenté
        return <Journal>[]; // Ou retourner une liste vide en cas d'erreur pour éviter de casser l'UI
      });
    } catch (e, stackTrace) {
      _logger.e('Erreur config stream journaux pour $userId', error: e, stackTrace: stackTrace);
      return Stream.error(Exception('Impossible de charger les journaux.'));
    }
  }

  Stream<DocumentSnapshot> getJournalStream(String journalId) {
    try {
      return _db.collection('journals').doc(journalId).snapshots()
          .handleError((error, stackTrace) {
        _logger.e('Erreur stream journal $journalId', error: error, stackTrace: stackTrace);
        // throw error; // Commenté
        // Retourner un stream d'erreur spécifique ou gérer autrement
        return Stream.error(error);
      });
    } catch (e, stackTrace) {
      _logger.e('Erreur config stream pour journal $journalId', error: e, stackTrace: stackTrace);
      return Stream.error(Exception('Impossible de charger le journal.'));
    }
  }

  // Nouvelle méthode pour vérifier l'existence d'un nom de journal pour un utilisateur
  Future<bool> checkJournalNameExists(String name, String userId) async {
    try {
      final querySnapshot = await _db
          .collection('journals')
          .where('userId', isEqualTo: userId)
          .where('name', isEqualTo: name)
          .limit(1) // On a juste besoin de savoir si au moins un existe
          .get();
      return querySnapshot.docs.isNotEmpty;
    } catch (e, stackTrace) {
      _logger.e('Erreur vérification nom journal "$name" pour utilisateur $userId', error: e, stackTrace: stackTrace);
      // En cas d'erreur, il est plus sûr de supposer que le nom pourrait exister
      // ou de relancer l'exception pour que l'appelant la gère.
      // Pour cette fonction, relancer l'exception est probablement mieux.
      throw Exception('Erreur lors de la vérification du nom du journal.');
    }
  }


  Future<void> createJournal(Journal journal) async {
    try {
      // La vérification du nom du journal devrait être faite AVANT d'appeler cette méthode.
      // Mais par sécurité, on pourrait la remettre ici si ce service est appelé d'ailleurs.
      // Pour l'instant, on suppose qu'elle est faite dans CreateJournalPage.
      await _db.collection('journals').doc(journal.id).set(journal.toMap());
      _logger.i('Journal créé: ${journal.id} pour ${journal.userId}');
    } catch (e, stackTrace) {
      _logger.e('Erreur création journal ${journal.id}', error: e, stackTrace: stackTrace);
      throw Exception('Impossible de créer le journal.');
    }
  }

  Future<void> updateJournal(Journal journal) async {
    try {
      journal.lastUpdatedAt = Timestamp.now();
      await _db.collection('journals').doc(journal.id).update(journal.toMap());
      _logger.i('Journal mis à jour: ${journal.id}');
    } catch (e, stackTrace) {
      _logger.e('Erreur màj journal ${journal.id}', error: e, stackTrace: stackTrace);
      throw Exception('Impossible de mettre à jour le journal.');
    }
  }

  Future<void> updateJournalName(String journalId, String newName) async {
    // Idéalement, vérifier aussi l'unicité du nouveau nom ici si appelé directement.
    try {
      await _db.collection('journals').doc(journalId).update({
        'name': newName,
        'lastUpdatedAt': Timestamp.now(),
      });
      _logger.i('Nom du journal $journalId mis à jour vers "$newName"');
    } catch (e, stackTrace) {
      _logger.e('Erreur màj nom journal $journalId', error: e, stackTrace: stackTrace);
      throw Exception('Impossible de mettre à jour le nom du journal.');
    }
  }

  Future<void> updateJournalPaletteInstance(String journalId, Palette newPaletteInstance) async {
    try {
      await _db.collection('journals').doc(journalId).update({
        'palette': newPaletteInstance.toMap(), // S'assurer que Palette.toMap() est correct
        'lastUpdatedAt': Timestamp.now(),
      });
      _logger.i('Palette du journal $journalId mise à jour.');
    } catch (e, stackTrace) {
      _logger.e('Erreur màj palette journal $journalId', error: e, stackTrace: stackTrace);
      throw Exception('Impossible de mettre à jour la palette du journal.');
    }
  }

  Future<void> deleteJournal(String journalId, String userId) async {
    try {
      WriteBatch batch = _db.batch();

      // Supprimer les notes associées au journal
      // Note: S'assurer que la collection 'notes' est bien à la racine et non une sous-collection de 'journals'
      // Si c'est une sous-collection, la requête serait _db.collection('journals').doc(journalId).collection('notes')
      // D'après getJournalNotesStream, 'notes' semble être une collection racine avec un champ 'journalId'.
      QuerySnapshot notesSnapshot = await _db.collection('notes')
          .where('journalId', isEqualTo: journalId)
      // Optionnel: .where('userId', isEqualTo: userId) pour plus de sécurité si les règles ne le font pas
          .get();

      for (DocumentSnapshot noteDoc in notesSnapshot.docs) {
        batch.delete(noteDoc.reference);
      }
      _logger.i('${notesSnapshot.docs.length} notes marquées pour suppression pour le journal $journalId.');

      // Supprimer le journal lui-même
      batch.delete(_db.collection('journals').doc(journalId));

      await batch.commit();
      _logger.i('Journal $journalId et ses notes associées supprimés.');
    } catch (e, stackTrace) {
      _logger.e('Erreur suppression journal $journalId', error: e, stackTrace: stackTrace);
      throw Exception('Impossible de supprimer le journal et ses notes.');
    }
  }

  Stream<List<Note>> getJournalNotesStream(String journalId, {String? sortBy, bool descending = false}) {
    try {
      Query query = _db.collection('notes').where('journalId', isEqualTo: journalId);

      // Appliquer le tri si spécifié
      if (sortBy != null) {
        query = query.orderBy(sortBy, descending: descending);
      } else {
        // Tri par défaut si aucun n'est spécifié (par exemple, par date de création ou d'événement)
        query = query.orderBy('eventTimestamp', descending: true);
      }

      return query.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) => Note.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
      }).handleError((error, stackTrace) {
        _logger.e('Erreur stream notes journal $journalId', error: error, stackTrace: stackTrace);
        return <Note>[]; // Retourner une liste vide en cas d'erreur
      });
    } catch (e, stackTrace) {
      _logger.e('Erreur config stream notes $journalId', error: e, stackTrace: stackTrace);
      return Stream.error(Exception('Impossible de charger les notes.'));
    }
  }

  Future<void> createNote(Note note) async {
    try {
      await _db.collection('notes').doc(note.id).set(note.toMap());
      _logger.i('Note créée: ${note.id} dans journal ${note.journalId}');
    } catch (e, stackTrace) {
      _logger.e('Erreur création note ${note.id}', error: e, stackTrace: stackTrace);
      throw Exception('Impossible de créer la note.');
    }
  }

  Future<void> updateNote(Note note) async {
    try {
      note.lastUpdatedAt = Timestamp.now();
      await _db.collection('notes').doc(note.id).update(note.toMap());
      _logger.i('Note màj: ${note.id}');
    } catch (e, stackTrace) {
      _logger.e('Erreur màj note ${note.id}', error: e, stackTrace: stackTrace);
      throw Exception('Impossible de mettre à jour la note.');
    }
  }

  Future<void> deleteNote(String noteId) async {
    try {
      await _db.collection('notes').doc(noteId).delete();
      _logger.i('Note supprimée: $noteId');
    } catch (e, stackTrace) {
      _logger.e('Erreur suppression note $noteId', error: e, stackTrace: stackTrace);
      throw Exception('Impossible de supprimer la note.');
    }
  }

  Future<bool> isPaletteElementUsedInNotes(String journalId, String paletteElementId) async {
    try {
      final querySnapshot = await _db
          .collection('notes')
          .where('journalId', isEqualTo: journalId)
          .where('paletteElementId', isEqualTo: paletteElementId)
          .limit(1)
          .get();
      return querySnapshot.docs.isNotEmpty;
    } catch (e, stackTrace) {
      _logger.e('Erreur vérif utilisation paletteElementId $paletteElementId journal $journalId', error: e, stackTrace: stackTrace);
      throw Exception('Impossible de vérifier l\'utilisation de la couleur.');
    }
  }

  Stream<List<PaletteModel>> getUserPaletteModelsStream(String userId) {
    try {
      return _db
          .collection('paletteModels')
          .where('userId', isEqualTo: userId)
      // Optionnel: trier les modèles par nom ou date de création
          .orderBy('name')
          .snapshots()
          .map((snapshot) => snapshot.docs
          .map((doc) => PaletteModel.fromMap(doc.data(), doc.id))
          .toList())
          .handleError((error, stackTrace) {
        _logger.e('Erreur stream modèles palette pour $userId', error: error, stackTrace: stackTrace);
        return <PaletteModel>[];
      });
    } catch (e, stackTrace) {
      _logger.e('Erreur config stream modèles palette pour $userId', error: e, stackTrace: stackTrace);
      return Stream.error(Exception('Impossible de charger les modèles de palette.'));
    }
  }

  Stream<List<PaletteModel>> getPredefinedPaletteModelsStream() {
    // Pour les modèles prédéfinis, il est plus simple de les retourner directement
    // depuis la liste `predefinedPalettes` plutôt que de les lire depuis Firestore,
    // sauf si vous les stockez aussi dans Firestore pour une gestion centralisée par un admin.
    // Si `predefinedPalettes` est la source de vérité, la méthode devient synchrone.
    // Si vous les stockez dans Firestore avec isPredefined = true:
    try {
      return _db
          .collection('paletteModels')
          .where('isPredefined', isEqualTo: true)
          .orderBy('name')
          .snapshots()
          .map((snapshot) => snapshot.docs
          .map((doc) => PaletteModel.fromMap(doc.data(), doc.id))
          .toList())
          .handleError((error, stackTrace) {
        _logger.e('Erreur stream modèles palette prédéfinis', error: error, stackTrace: stackTrace);
        return <PaletteModel>[];
      });
    } catch (e, stackTrace) {
      _logger.e('Erreur config stream modèles palette prédéfinis', error: e, stackTrace: stackTrace);
      return Stream.error(Exception('Impossible de charger les modèles de palette prédéfinis.'));
    }
  }

  Future<void> createPaletteModel(PaletteModel paletteModel) async {
    try {
      // La vérification du nom du modèle devrait être faite AVANT d'appeler cette méthode.
      await _db.collection('paletteModels').doc(paletteModel.id).set(paletteModel.toMap());
      _logger.i('Modèle de palette créé: ${paletteModel.id} par ${paletteModel.userId}');
    } catch (e, stackTrace) {
      _logger.e('Erreur création modèle palette ${paletteModel.id}', error: e, stackTrace: stackTrace);
      throw Exception('Impossible de créer le modèle de palette.');
    }
  }

  Future<void> updatePaletteModel(PaletteModel paletteModel) async {
    try {
      await _db.collection('paletteModels').doc(paletteModel.id).update(paletteModel.toMap());
      _logger.i('Modèle de palette màj: ${paletteModel.id}');
    } catch (e, stackTrace) {
      _logger.e('Erreur màj modèle palette ${paletteModel.id}', error: e, stackTrace: stackTrace);
      throw Exception('Impossible de mettre à jour le modèle de palette.');
    }
  }

  Future<void> deletePaletteModel(String paletteModelId) async {
    try {
      await _db.collection('paletteModels').doc(paletteModelId).delete();
      _logger.i('Modèle de palette supprimé: $paletteModelId');
    } catch (e, stackTrace) {
      _logger.e('Erreur suppression modèle palette $paletteModelId', error: e, stackTrace: stackTrace);
      throw Exception('Impossible de supprimer le modèle de palette.');
    }
  }

  Future<bool> checkPaletteModelNameExists(String name, String userId, {String? excludeId}) async {
    try {
      Query query = _db
          .collection('paletteModels')
          .where('userId', isEqualTo: userId)
          .where('name', isEqualTo: name);

      final snapshot = await query.get();
      if (excludeId != null) {
        return snapshot.docs.any((doc) => doc.id != excludeId);
      }
      return snapshot.docs.isNotEmpty;
    } catch (e, stackTrace) {
      _logger.e('Erreur vérif nom modèle palette "$name"', error: e, stackTrace: stackTrace);
      throw Exception('Erreur lors de la vérification du nom du modèle de palette.');
    }
  }
}
