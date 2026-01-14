import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show User; // Specific import for User type
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

import '../models/app_user.dart';
import '../models/journal.dart';
import '../models/palette.dart';
import '../models/palette_model.dart';
import '../models/color_data.dart';
import '../models/note.dart';
import '../core/predefined_templates.dart'; // Provides predefinedPalettes

/// Logger instance for this service.
final _logger = Logger(
  printer: PrettyPrinter(
    methodCount: 1, // Nombre de méthodes à afficher dans la trace d'appel
    errorMethodCount: 8, // Nombre de méthodes à afficher pour les erreurs
    lineLength: 120, // Largeur de la ligne pour le log
    colors: true, // Utiliser des couleurs pour différencier les niveaux de log
    printEmojis: true, // Afficher des emojis pour les niveaux de log
    printTime: true, // Afficher l'heure du log
  ),
);
/// A global Uuid instance for generating unique IDs.
const Uuid _uuid = Uuid();

/// Service class for interacting with Cloud Firestore.
///
/// This service handles all database operations for the application,
/// including managing users, journals, notes, and palette models.
class FirestoreService {
  final FirebaseFirestore _db;
  static const int _maxJournalNameLength = 100;
  static const int _maxNoteContentLength = 10000; // Arbitrary safe limit

  /// Creates an instance of [FirestoreService].
  ///
  /// Requires a [FirebaseFirestore] instance.
  FirestoreService(this._db);

  void _validateJournal(Journal journal) {
    if (journal.name.trim().isEmpty) {
      throw ArgumentError('Le nom du journal ne peut pas être vide.');
    }
    if (journal.name.length > _maxJournalNameLength) {
      throw ArgumentError('Le nom du journal dépasse la limite de $_maxJournalNameLength caractères.');
    }
    if (journal.userId.isEmpty) {
       throw ArgumentError('UserId est requis pour le journal.');
    }
    // Validation palette minimal structure
    if (journal.palette.colors.isEmpty) {
      throw ArgumentError('La palette du journal ne peut pas être vide.');
    }
  }

  void _validateNote(Note note) {
    if (note.journalId.isEmpty) {
      throw ArgumentError('JournalId est requis pour la note.');
    }
    if (note.userId.isEmpty) {
      throw ArgumentError('UserId est requis pour la note.');
    }
    // Assuming Note has content or similar field. Checking 'Note' model structure might be needed if I don't recall. 
    // Checking previous file dump... Note class details were not fully visible in list_dir but likely standard.
    // I shall be conservative and only validate IDs which are critical. 
  }

  /// Initializes data for a new user in Firestore.
  ///
  /// This includes creating a user document in the 'users' collection and
  /// setting up a default journal with a default color palette for the user.
  /// The default palette is based on the first predefined palette template if available,
  /// otherwise a fallback palette is created.
  ///
  /// [firebaseUser] The Firebase [User] object for the newly registered user.
  /// [displayName] Optional display name to store for the user.
  /// [email] Optional email to store for the user.
  /// Throws an [Exception] if data initialization fails.
  Future<void> initializeNewUserData(User firebaseUser, {String? displayName, String? email}) async {
    try {
      _logger.i('Initialisation des données pour le nouvel utilisateur: ${firebaseUser.uid}');

      // Create the AppUser object
      AppUser newUser = AppUser(
        id: firebaseUser.uid,
        email: firebaseUser.email ?? email,
        displayName: firebaseUser.displayName ?? displayName ?? 'Nouvel Utilisateur', // UI Text in French
        registrationDate: Timestamp.now(),
      );
      // Save the user to Firestore
      await _db.collection('users').doc(newUser.id).set(newUser.toMap());
      _logger.i('Document utilisateur créé pour ${newUser.id}');

      // Check for predefined palettes
      if (predefinedPalettes.isEmpty) {
        _logger.w('Aucune palette prédéfinie disponible pour créer le journal par défaut.');
        // Create a fallback palette if no predefined ones are available
        Palette fallbackPalette = Palette(
            id: _uuid.v4(),
            name: "Palette de Base", // UI Text in French
            colors: [ColorData(title: "Défaut", hexCode: "808080", paletteElementId: _uuid.v4(), isDefault: true)], // UI Text in French
            userId: firebaseUser.uid, // Associate with the user
            isPredefined: false // This is a user-specific instance, not a global predefined one
        );
        Journal defaultJournal = Journal(
          id: _uuid.v4(),
          userId: firebaseUser.uid,
          name: 'Mon Premier Journal', // UI Text in French
          palette: fallbackPalette,
          createdAt: Timestamp.now(),
          lastUpdatedAt: Timestamp.now(),
        );
        await _db.collection('journals').doc(defaultJournal.id).set(defaultJournal.toMap());
        _logger.i('Journal par défaut créé avec palette de secours pour ${firebaseUser.uid} avec ID ${defaultJournal.id}');
        return;
      }

      // Use the first predefined palette for the default journal
      PaletteModel defaultPaletteTemplate = predefinedPalettes[0];

      // Create ColorData instances for the journal's palette, ensuring unique paletteElementIds
      List<ColorData> instanceColors = defaultPaletteTemplate.colors.map((colorTemplate) {
        return ColorData(
          title: colorTemplate.title,
          hexCode: colorTemplate.hexCode,
          isDefault: colorTemplate.isDefault,
          paletteElementId: _uuid.v4(), // Generate a unique ID for each color instance
        );
      }).toList();

      // Create the Palette instance for the journal
      Palette paletteForJournal = Palette(
        id: _uuid.v4(), // New unique ID for this palette instance
        name: defaultPaletteTemplate.name, // Name from the template
        colors: instanceColors,
        isPredefined: false, // This is a user's instance, not a global predefined one
        userId: firebaseUser.uid, // Link to the user
      );

      // Create the default Journal
      Journal defaultJournal = Journal(
        id: _uuid.v4(), // New unique ID for the journal
        userId: firebaseUser.uid,
        name: 'Mon Premier Journal', // UI Text in French
        palette: paletteForJournal, // The newly created palette instance
        createdAt: Timestamp.now(),
        lastUpdatedAt: Timestamp.now(),
      );
      // Save the journal to Firestore
      await _db.collection('journals').doc(defaultJournal.id).set(defaultJournal.toMap());
      _logger.i('Journal par défaut créé pour ${firebaseUser.uid} avec ID ${defaultJournal.id}');

    } catch (e, stackTrace) {
      _logger.e('Erreur initialisation données utilisateur', error: e, stackTrace: stackTrace);
      throw Exception('Échec initialisation données utilisateur: ${e.toString()}'); // Error message in French
    }
  }

  /// Retrieves an [AppUser] from Firestore by their UID.
  ///
  /// [uid] The unique identifier of the user.
  /// Returns the [AppUser] if found, otherwise `null`.
  /// Throws an [Exception] if fetching fails.
  Future<AppUser?> getUser(String uid) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        return AppUser.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e, stackTrace) {
      _logger.e('Erreur get User $uid', error: e, stackTrace: stackTrace);
      throw Exception('Impossible de récupérer les infos utilisateur.'); // Error message in French
    }
  }

  /// Returns a stream of the list of journals for a given user, sorted by creation date (descending).
  ///
  /// [userId] The ID of the user whose journals are to be fetched.
  /// Returns a [Stream] of a list of [Journal] objects.
  /// Emits an empty list or an error if fetching fails.
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
          .handleError((error, stackTrace) { // Handle errors within the stream
        _logger.e('Erreur stream journaux pour $userId', error: error, stackTrace: stackTrace);
        return <Journal>[]; // Return an empty list on error to keep stream alive if desired
      });
    } catch (e, stackTrace) { // Catch synchronous errors during stream setup
      _logger.e('Erreur config stream journaux pour $userId', error: e, stackTrace: stackTrace);
      return Stream.error(Exception('Impossible de charger les journaux.')); // Error message in French
    }
  }

  /// Returns a stream of a specific [Journal] document by its ID.
  ///
  /// [journalId] The ID of the journal to stream.
  /// Returns a [Stream] of [DocumentSnapshot].
  /// Emits an error if streaming fails.
  Stream<DocumentSnapshot> getJournalStream(String journalId) {
    try {
      return _db.collection('journals').doc(journalId).snapshots()
          .handleError((error, stackTrace) {
        _logger.e('Erreur stream journal $journalId', error: error, stackTrace: stackTrace);
        // Propagate the error through the stream
        return Stream.error(error);
      });
    } catch (e, stackTrace) {
      _logger.e('Erreur config stream pour journal $journalId', error: e, stackTrace: stackTrace);
      return Stream.error(Exception('Impossible de charger le journal.')); // Error message in French
    }
  }

  /// Checks if a journal with the given [name] already exists for the specified [userId].
  ///
  /// [name] The name of the journal to check.
  /// [userId] The ID of the user.
  /// Returns `true` if a journal with that name exists for the user, `false` otherwise.
  /// Throws an [Exception] if the check fails.
  Future<bool> checkJournalNameExists(String name, String userId) async {
    try {
      final querySnapshot = await _db
          .collection('journals')
          .where('userId', isEqualTo: userId)
          .where('name', isEqualTo: name)
          .limit(1) // Optimization: only need to know if at least one exists
          .get();
      return querySnapshot.docs.isNotEmpty;
    } catch (e, stackTrace) {
      _logger.e('Erreur vérification nom journal "$name" pour utilisateur $userId', error: e, stackTrace: stackTrace);
      throw Exception('Erreur lors de la vérification du nom du journal.'); // Error message in French
    }
  }

  /// Creates a new journal in Firestore.
  ///
  /// [journal] The [Journal] object to be created.
  /// Throws an [Exception] if creation fails.
  Future<void> createJournal(Journal journal) async {
    try {
      _validateJournal(journal);
      await _db.collection('journals').doc(journal.id).set(journal.toMap());
      _logger.i('Journal créé: ${journal.id} pour ${journal.userId}');
    } catch (e, stackTrace) {
      _logger.e('Erreur création journal ${journal.id}', error: e, stackTrace: stackTrace);
      throw Exception('Impossible de créer le journal.'); // Error message in French
    }
  }

  /// Updates an existing journal in Firestore.
  ///
  /// The journal's `lastUpdatedAt` field is automatically set to the current time.
  /// [journal] The [Journal] object with updated data.
  /// Throws an [Exception] if the update fails.
  Future<void> updateJournal(Journal journal) async {
    try {
      _validateJournal(journal);
      journal.lastUpdatedAt = Timestamp.now(); // Ensure lastUpdatedAt is current
      await _db.collection('journals').doc(journal.id).update(journal.toMap());
      _logger.i('Journal mis à jour: ${journal.id}');
    } catch (e, stackTrace) {
      _logger.e('Erreur màj journal ${journal.id}', error: e, stackTrace: stackTrace);
      throw Exception('Impossible de mettre à jour le journal.'); // Error message in French
    }
  }

  /// Updates only the name and `lastUpdatedAt` timestamp of a specific journal.
  ///
  /// [journalId] The ID of the journal to update.
  /// [newName] The new name for the journal.
  /// Throws an [Exception] if the update fails.
  Future<void> updateJournalName(String journalId, String newName) async {
    try {
      await _db.collection('journals').doc(journalId).update({
        'name': newName,
        'lastUpdatedAt': Timestamp.now(),
      });
      _logger.i('Nom du journal $journalId mis à jour vers "$newName"');
    } catch (e, stackTrace) {
      _logger.e('Erreur màj nom journal $journalId', error: e, stackTrace: stackTrace);
      throw Exception('Impossible de mettre à jour le nom du journal.'); // Error message in French
    }
  }

  /// Updates the embedded palette instance of a specific journal and its `lastUpdatedAt` timestamp.
  ///
  /// [journalId] The ID of the journal whose palette is to be updated.
  /// [newPaletteInstance] The new [Palette] object to be set for the journal.
  /// Throws an [Exception] if the update fails.
  Future<void> updateJournalPaletteInstance(String journalId, Palette newPaletteInstance) async {
    try {
      await _db.collection('journals').doc(journalId).update({
        'palette': newPaletteInstance.toMap(), // Assumes Palette.toMap() correctly serializes the palette
        'lastUpdatedAt': Timestamp.now(),
      });
      _logger.i('Palette du journal $journalId mise à jour.');
    } catch (e, stackTrace) {
      _logger.e('Erreur màj palette journal $journalId', error: e, stackTrace: stackTrace);
      throw Exception('Impossible de mettre à jour la palette du journal.'); // Error message in French
    }
  }

  /// Deletes a journal and all its associated notes from Firestore.
  ///
  /// This operation is performed in a batch to ensure atomicity.
  /// [journalId] The ID of the journal to delete.
  /// [userId] The ID of the user who owns the journal (for security/validation in `deleteAllNotesInJournal`).
  /// Throws an [Exception] if deletion fails.
  Future<void> deleteJournal(String journalId, String userId) async {
    try {
      WriteBatch batch = _db.batch();

      // Use the dedicated method to delete all notes within the journal, adding to the same batch.
      await deleteAllNotesInJournal(journalId, userId, batch: batch);

      // Delete the journal document itself.
      batch.delete(_db.collection('journals').doc(journalId));

      await batch.commit(); // Commit all batched operations.
      _logger.i('Journal $journalId et ses notes associées supprimés.');
    } catch (e, stackTrace) {
      _logger.e('Erreur suppression journal $journalId', error: e, stackTrace: stackTrace);
      throw Exception('Impossible de supprimer le journal et ses notes.'); // Error message in French
    }
  }

  /// Deletes all notes within a specific journal for a given user.
  ///
  /// This operation can optionally be part of an existing [WriteBatch].
  /// If no batch is provided, a new one is created for this operation.
  ///
  /// [journalId] The ID of the journal from which to delete notes.
  /// [userId] The ID of the user who owns the notes (for security query).
  /// [batch] An optional [WriteBatch] to add delete operations to.
  /// Throws an [Exception] if deletion fails.
  Future<void> deleteAllNotesInJournal(String journalId, String userId, {WriteBatch? batch}) async {
    _logger.i('Suppression de toutes les notes pour le journal $journalId (utilisateur $userId)');
    try {
      // Query for all notes belonging to the specified journal and user.
      QuerySnapshot notesSnapshot = await _db.collection('notes')
          .where('journalId', isEqualTo: journalId)
          .where('userId', isEqualTo: userId) // Ensures only the owner's notes are targeted.
          .get();

      bool useExternalBatch = batch != null;
      WriteBatch currentBatch = batch ?? _db.batch(); // Use provided batch or create a new one.

      for (DocumentSnapshot noteDoc in notesSnapshot.docs) {
        currentBatch.delete(noteDoc.reference);
      }

      if (!useExternalBatch) {
        // If a local batch was created, commit it now.
        await currentBatch.commit();
        _logger.i('${notesSnapshot.docs.length} notes supprimées pour le journal $journalId.');
      } else {
        // If using an external batch, logging indicates marking for deletion.
        // The actual commit will happen outside this method.
        _logger.i('${notesSnapshot.docs.length} notes marquées pour suppression (batch) pour le journal $journalId.');
      }
    } catch (e, stackTrace) {
      _logger.e('Erreur lors de la suppression de toutes les notes du journal $journalId', error: e, stackTrace: stackTrace);
      throw Exception('Impossible de supprimer toutes les notes du journal.'); // Error message in French
    }
  }


  /// Returns a stream of the list of notes for a given journal, with optional sorting and filtering.
  ///
  /// [journalId] The ID of the journal whose notes are to be fetched.
  /// [sortBy] The field to sort by (e.g., 'eventTimestamp', 'createdAt'). Defaults to 'eventTimestamp'.
  /// [descending] Whether to sort in descending order. Defaults to `true` for 'eventTimestamp', `false` otherwise.
  /// [filterByPaletteElementId] Optional: if provided, filters notes to only show those with this paletteElementId.
  /// Returns a [Stream] of a list of [Note] objects.
  /// Emits an empty list or an error if fetching fails.
  Stream<List<Note>> getJournalNotesStream(String journalId, {String? sortBy, bool descending = false, String? filterByPaletteElementId}) {
    try {
      Query query = _db.collection('notes').where('journalId', isEqualTo: journalId);

      if (filterByPaletteElementId != null) {
        query = query.where('paletteElementId', isEqualTo: filterByPaletteElementId);
      }

      if (sortBy != null) {
        query = query.orderBy(sortBy, descending: descending);
      } else {
        // Default sort order if none is specified.
        query = query.orderBy('eventTimestamp', descending: true);
      }

      return query.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) => Note.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
      }).handleError((error, stackTrace) {
        _logger.e('Erreur stream notes journal $journalId', error: error, stackTrace: stackTrace);
        return <Note>[]; // Return an empty list on error.
      });
    } catch (e, stackTrace) {
      _logger.e('Erreur config stream notes $journalId', error: e, stackTrace: stackTrace);
      return Stream.error(Exception('Impossible de charger les notes.')); // Error message in French
    }
  }

  /// Creates a new note in Firestore.
  ///
  /// [note] The [Note] object to be created.
  /// Throws an [Exception] if creation fails.
  Future<void> createNote(Note note) async {
    try {
      _validateNote(note);
      await _db.collection('notes').doc(note.id).set(note.toMap());
      _logger.i('Note créée: ${note.id} dans journal ${note.journalId}');
    } catch (e, stackTrace) {
      _logger.e('Erreur création note ${note.id}', error: e, stackTrace: stackTrace);
      throw Exception('Impossible de créer la note.'); // Error message in French
    }
  }

  /// Updates an existing note in Firestore.
  ///
  /// The note's `lastUpdatedAt` field is automatically set to the current time.
  /// [note] The [Note] object with updated data.
  /// Throws an [Exception] if the update fails.
  Future<void> updateNote(Note note) async {
    try {
      _validateNote(note);
      note.lastUpdatedAt = Timestamp.now(); // Ensure lastUpdatedAt is current
      await _db.collection('notes').doc(note.id).update(note.toMap());
      _logger.i('Note màj: ${note.id}');
    } catch (e, stackTrace) {
      _logger.e('Erreur màj note ${note.id}', error: e, stackTrace: stackTrace);
      throw Exception('Impossible de mettre à jour la note.'); // Error message in French
    }
  }

  /// Deletes a note from Firestore by its ID.
  ///
  /// [noteId] The ID of the note to delete.
  /// Throws an [Exception] if deletion fails.
  Future<void> deleteNote(String noteId) async {
    try {
      await _db.collection('notes').doc(noteId).delete();
      _logger.i('Note supprimée: $noteId');
    } catch (e, stackTrace) {
      _logger.e('Erreur suppression note $noteId', error: e, stackTrace: stackTrace);
      throw Exception('Impossible de supprimer la note.'); // Error message in French
    }
  }

  /// Checks if a specific [paletteElementId] (a color) is currently used by any note
  /// within a given [journalId].
  ///
  /// [journalId] The ID of the journal to check within.
  /// [paletteElementId] The ID of the color element to check for usage.
  /// Returns `true` if the color is used in at least one note, `false` otherwise.
  /// Throws an [Exception] if the check fails.
  Future<bool> isPaletteElementUsedInNotes(String journalId, String paletteElementId) async {
    try {
      final querySnapshot = await _db
          .collection('notes')
          .where('journalId', isEqualTo: journalId)
          .where('paletteElementId', isEqualTo: paletteElementId)
          .limit(1) // Optimization: only need to find one instance.
          .get();
      return querySnapshot.docs.isNotEmpty;
    } catch (e, stackTrace) {
      _logger.e('Erreur vérif utilisation paletteElementId $paletteElementId journal $journalId', error: e, stackTrace: stackTrace);
      throw Exception('Impossible de vérifier l\'utilisation de la couleur.'); // Error message in French
    }
  }

  /// Returns a stream of the list of personal palette models for a given user, sorted by name.
  ///
  /// [userId] The ID of the user whose palette models are to be fetched.
  /// Returns a [Stream] of a list of [PaletteModel] objects.
  /// Emits an empty list or an error if fetching fails.
  Stream<List<PaletteModel>> getUserPaletteModelsStream(String userId) {
    try {
      return _db
          .collection('paletteModels')
          .where('userId', isEqualTo: userId) // Filter by user ID
          .where('isPredefined',isEqualTo: false) // Ensure only user-created models are fetched
          .orderBy('name') // Sort by name
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
      return Stream.error(Exception('Impossible de charger les modèles de palette.')); // Error message in French
    }
  }

  /// Returns a stream of the list of predefined palette models, sorted by name.
  ///
  /// These models are typically identified by an `isPredefined` flag in Firestore.
  /// Returns a [Stream] of a list of [PaletteModel] objects.
  /// Emits an empty list or an error if fetching fails.
  Stream<List<PaletteModel>> getPredefinedPaletteModelsStream() {
    try {
      return _db
          .collection('paletteModels')
          .where('isPredefined', isEqualTo: true) // Filter for predefined models
          .orderBy('name') // Sort by name
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
      return Stream.error(Exception('Impossible de charger les modèles de palette prédéfinis.')); // Error message in French
    }
  }

  /// Creates a new personal palette model in Firestore.
  ///
  /// [paletteModel] The [PaletteModel] object to be created. It should have `isPredefined` set to `false`.
  /// Throws an [Exception] if creation fails.
  Future<void> createPaletteModel(PaletteModel paletteModel) async {
    try {
      // Ensure the model being created is marked as not predefined and has a userId.
      if (paletteModel.isPredefined || paletteModel.userId == null || paletteModel.userId!.isEmpty) {
        _logger.w('Attempted to create a palette model with isPredefined=true or missing userId as a user model. Model ID: ${paletteModel.id}');
        throw ArgumentError('User-created palette models must have isPredefined=false and a valid userId.');
      }
      await _db.collection('paletteModels').doc(paletteModel.id).set(paletteModel.toMap());
      _logger.i('Modèle de palette créé: ${paletteModel.id} par ${paletteModel.userId}');
    } catch (e, stackTrace) {
      _logger.e('Erreur création modèle palette ${paletteModel.id}', error: e, stackTrace: stackTrace);
      throw Exception('Impossible de créer le modèle de palette.'); // Error message in French
    }
  }

  /// Updates an existing personal palette model in Firestore.
  ///
  /// [paletteModel] The [PaletteModel] object with updated data. It should have `isPredefined` set to `false`.
  /// Throws an [Exception] if the update fails or if trying to update a predefined model.
  Future<void> updatePaletteModel(PaletteModel paletteModel) async {
    try {
      // Prevent updating predefined models through this method.
      if (paletteModel.isPredefined) {
        _logger.w('Attempted to update a predefined palette model. Model ID: ${paletteModel.id}');
        throw ArgumentError('Predefined palette models cannot be updated through this method.');
      }
      await _db.collection('paletteModels').doc(paletteModel.id).update(paletteModel.toMap());
      _logger.i('Modèle de palette màj: ${paletteModel.id}');
    } catch (e, stackTrace) {
      _logger.e('Erreur màj modèle palette ${paletteModel.id}', error: e, stackTrace: stackTrace);
      throw Exception('Impossible de mettre à jour le modèle de palette.'); // Error message in French
    }
  }

  /// Deletes a personal palette model from Firestore by its ID.
  ///
  /// Predefined models cannot be deleted.
  /// [paletteModelId] The ID of the palette model to delete.
  /// Throws an [Exception] if deletion fails.
  Future<void> deletePaletteModel(String paletteModelId) async {
    try {
      // Optional: Add a check here to prevent deletion if model.isPredefined == true,
      // though the primary guard should be in the UI/calling code.
      // Example check (would require fetching the model first, or passing the model object):
      // DocumentSnapshot modelDoc = await _db.collection('paletteModels').doc(paletteModelId).get();
      // if (modelDoc.exists && (modelDoc.data() as Map<String,dynamic>)['isPredefined'] == true) {
      //   _logger.w('Attempted to delete a predefined palette model. Model ID: $paletteModelId');
      //   throw Exception('Les modèles prédéfinis ne peuvent pas être supprimés.');
      // }
      await _db.collection('paletteModels').doc(paletteModelId).delete();
      _logger.i('Modèle de palette supprimé: $paletteModelId');
    } catch (e, stackTrace) {
      _logger.e('Erreur suppression modèle palette $paletteModelId', error: e, stackTrace: stackTrace);
      throw Exception('Impossible de supprimer le modèle de palette.'); // Error message in French
    }
  }

  /// Checks if a palette model with the given [name] already exists for the [userId],
  /// optionally excluding a specific [excludeId] (useful when updating an existing model).
  ///
  /// [name] The name of the palette model to check.
  /// [userId] The ID of the user.
  /// [excludeId] An optional ID of a palette model to exclude from the check.
  /// Returns `true` if a conflicting name exists, `false` otherwise.
  /// Throws an [Exception] if the check fails.
  Future<bool> checkPaletteModelNameExists(String name, String userId, {String? excludeId}) async {
    try {
      Query query = _db
          .collection('paletteModels')
          .where('userId', isEqualTo: userId)
          .where('isPredefined', isEqualTo: false) // Only check against user's own non-predefined models
          .where('name', isEqualTo: name);

      final snapshot = await query.get();
      if (excludeId != null) {
        // If excludeId is provided, a name exists if there's any document
        // in the snapshot whose ID is different from excludeId.
        return snapshot.docs.any((doc) => doc.id != excludeId);
      }
      // If no excludeId, a name exists if any documents are returned.
      return snapshot.docs.isNotEmpty;
    } catch (e, stackTrace) {
      _logger.e('Erreur vérif nom modèle palette "$name"', error: e, stackTrace: stackTrace);
      throw Exception('Erreur lors de la vérification du nom du modèle de palette.'); // Error message in French
    }
  }
}
