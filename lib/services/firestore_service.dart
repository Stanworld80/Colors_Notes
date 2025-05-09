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
            userId: firebaseUser.uid,
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
          paletteElementId: _uuid.v4(),
        );
      }).toList();

      Palette paletteForJournal = Palette(
        id: _uuid.v4(),
        name: defaultPaletteTemplate.name,
        colors: instanceColors,
        isPredefined: false,
        userId: firebaseUser.uid,
      );

      Journal defaultJournal = Journal(
        id: _uuid.v4(),
        userId: firebaseUser.uid,
        name: 'Mon Premier Journal',
        palette: paletteForJournal,
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
        throw error;
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
        throw error;
      });
    } catch (e, stackTrace) {
      _logger.e('Erreur config stream pour journal $journalId', error: e, stackTrace: stackTrace);
      return Stream.error(Exception('Impossible de charger le journal.'));
    }
  }

  Future<void> createJournal(Journal journal) async {
    try {
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
        'palette': newPaletteInstance.toMap(),
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
      QuerySnapshot notesSnapshot = await _db.collection('notes')
          .where('journalId', isEqualTo: journalId)
          .get();
      for (DocumentSnapshot noteDoc in notesSnapshot.docs) {
        batch.delete(noteDoc.reference);
      }
      _logger.i('${notesSnapshot.docs.length} notes marquées pour suppression pour le journal $journalId.');
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
      query = query.orderBy(sortBy ?? 'eventTimestamp', descending: descending);

      return query.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) => Note.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
      }).handleError((error, stackTrace) {
        _logger.e('Erreur stream notes journal $journalId', error: error, stackTrace: stackTrace);
        throw error;
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
          .snapshots()
          .map((snapshot) => snapshot.docs
          .map((doc) => PaletteModel.fromMap(doc.data(), doc.id))
          .toList())
          .handleError((error, stackTrace) {
        _logger.e('Erreur stream modèles palette pour $userId', error: error, stackTrace: stackTrace);
        throw error;
      });
    } catch (e, stackTrace) {
      _logger.e('Erreur config stream modèles palette pour $userId', error: e, stackTrace: stackTrace);
      return Stream.error(Exception('Impossible de charger les modèles de palette.'));
    }
  }

  Stream<List<PaletteModel>> getPredefinedPaletteModelsStream() {
    try {
      return _db
          .collection('paletteModels')
          .where('isPredefined', isEqualTo: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
          .map((doc) => PaletteModel.fromMap(doc.data(), doc.id))
          .toList())
          .handleError((error, stackTrace) {
        _logger.e('Erreur stream modèles palette prédéfinis', error: error, stackTrace: stackTrace);
        throw error;
      });
    } catch (e, stackTrace) {
      _logger.e('Erreur config stream modèles palette prédéfinis', error: e, stackTrace: stackTrace);
      return Stream.error(Exception('Impossible de charger les modèles de palette prédéfinis.'));
    }
  }

  Future<void> createPaletteModel(PaletteModel paletteModel) async {
    try {
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
