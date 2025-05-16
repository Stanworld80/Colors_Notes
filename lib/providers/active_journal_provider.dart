import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/journal.dart';

/// Logger instance for this provider.
final _logger = Logger(printer: PrettyPrinter(methodCount: 1, printTime: true));

/// Manages the state of the currently active journal.
///
/// This notifier listens to authentication changes and loads the appropriate
/// journal for the current user. It provides streams for the active journal ID
/// and the [Journal] object itself, as well as loading and error states.
class ActiveJournalNotifier extends ChangeNotifier {
  final AuthService _authService;
  final FirestoreService _firestoreService;

  /// The ID of the currently active journal. Null if no journal is active.
  String? _activeJournalId;
  /// The currently active [Journal] object. Null if no journal is active or loaded.
  Journal? _activeJournal;
  /// Indicates if the notifier is currently loading journal data.
  bool _isLoading = false;
  /// Holds an error message if an error occurred during loading or processing.
  String? _errorMessage;

  /// Subscription to the authentication user stream.
  StreamSubscription<User?>? _userSubscription;
  /// Subscription to the active journal's document stream from Firestore.
  StreamSubscription<DocumentSnapshot?>? _journalSubscription;

  /// Gets the ID of the currently active journal.
  String? get activeJournalId => _activeJournalId;

  /// Gets the currently active [Journal] object.
  Journal? get activeJournal => _activeJournal;

  /// Returns `true` if data is currently being loaded, `false` otherwise.
  bool get isLoading => _isLoading;

  /// Gets the current error message, if any.
  String? get errorMessage => _errorMessage;

  /// Creates an instance of [ActiveJournalNotifier].
  ///
  /// Initializes by listening to user authentication state changes.
  /// [authService] provides authentication functionalities.
  /// [firestoreService] provides data access functionalities.
  ActiveJournalNotifier(this._authService, this._firestoreService) {
    _logger.i('ActiveJournalNotifier initialisé.');
    _userSubscription = _authService.userStream.listen(_onUserChanged);
    if (_authService.currentUser != null) {
      _onUserChanged(_authService.currentUser);
    }
  }

  /// Handles changes in the authenticated user's state.
  ///
  /// When a user logs in, it attempts to load their initial journal.
  /// When a user logs out, it clears the active journal state.
  Future<void> _onUserChanged(User? user) async {
    _logger.i('Changement utilisateur: ${user?.uid}');
    _isLoading = true;
    _errorMessage = null;
    // Notify listeners early if it's not the initial setup,
    // to reflect the loading state due to user change.
    // However, the constructor call to _onUserChanged should not notify yet.
    // This is tricky. For now, relying on notifyListeners() at the end of this method.

    if (user == null) {
      clearActiveJournalState();
      _isLoading = false; // Ensure isLoading is false after clearing state.
    } else {
      await _loadInitialJournalForUser(user.uid);
    }

    // Ensure isLoading is false if not already handled by sub-methods.
    if (_isLoading) {
      _isLoading = false;
    }
    notifyListeners();
  }

  /// Loads the initial journal for a given user.
  ///
  /// This method attempts to load the first available journal for the user.
  /// If no journals are found, the active journal state is cleared.
  Future<void> _loadInitialJournalForUser(String userId) async {
    _logger.i('Chargement journal initial pour utilisateur: $userId');

    try {
      // CORRECTION: Suppression de la variable `lastUsedJournalId` et de la condition `if (lastUsedJournalId != null)`
      // car `lastUsedJournalId` n'était jamais initialisé et la condition était toujours fausse.
      // La logique charge maintenant toujours le premier journal trouvé par défaut.
      // Si une logique de "dernier journal utilisé" doit être implémentée,
      // `lastUsedJournalId` devrait être chargé (par ex. depuis SharedPreferences).

      _logger.i('Chargement du premier journal disponible.');
      final journals = await _firestoreService.getJournalsStream(userId).first;
      if (journals.isNotEmpty) {
        _logger.i('Premier journal trouvé: ${journals.first.id}');
        // Set isInitialLoad to true to prevent premature UI updates if handled by _onUserChanged.
        await setActiveJournal(journals.first.id, userId, isInitialLoad: true);
      } else {
        _logger.w('Aucun journal pour utilisateur $userId.');
        clearActiveJournalState();
      }
    } catch (e, stackTrace) {
      _logger.e('Erreur chargement journal initial', error: e, stackTrace: stackTrace);
      _errorMessage = 'Impossible de charger le journal initial.';
      clearActiveJournalState();
    }
    // _isLoading state is managed by setActiveJournal or the calling context of clearActiveJournalState.
  }

  /// Sets the specified journal as the active one.
  ///
  /// If the journal ID is the same as the current active one and it's not an initial load,
  /// it does nothing. Otherwise, it cancels any existing journal subscription,
  /// updates the active journal ID, and subscribes to the new journal's data.
  ///
  /// [journalId] The ID of the journal to set as active.
  /// [userId] The ID of the current user, for validation.
  /// [isInitialLoad] Flag to indicate if this is part of the initial loading sequence,
  /// which might affect how/when listeners are notified.
  Future<void> setActiveJournal(String journalId, String userId, {bool isInitialLoad = false}) async {
    _logger.i('Définition journal actif: $journalId pour utilisateur $userId');
    if (_activeJournalId == journalId && _activeJournal != null && !isInitialLoad) {
      _logger.i('Journal $journalId déjà actif.');
      if (_isLoading) { // If it was loading but is already active, stop loading.
        _isLoading = false;
        notifyListeners();
      }
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    if (!isInitialLoad) notifyListeners(); // Notify for user-initiated changes to show loading.

    await _journalSubscription?.cancel();
    _activeJournalId = journalId;

    _journalSubscription = _firestoreService
        .getJournalStream(journalId)
        .listen(
          (journalDoc) {
        if (journalDoc.exists && journalDoc.data() != null) {
          final journalData = journalDoc.data() as Map<String, dynamic>;
          // Validate that the journal belongs to the current user.
          if (journalData['userId'] == userId) {
            _activeJournal = Journal.fromMap(journalData, journalDoc.id);
            _logger.i('Active journal màj: ${_activeJournal?.name} (ID: $journalId)');
            _errorMessage = null;
          } else {
            _logger.w('Tentative de définition d\'un journal actif ($journalId) n\'appartenant pas à l\'utilisateur ($userId). Appartenance: ${journalData['userId']}');
            _errorMessage = 'Accès non autorisé à ce journal.';
            clearActiveJournalState();
            // If not an initial load, try to recover by loading a valid journal.
            if (!isInitialLoad) _loadInitialJournalForUser(userId);
          }
        } else {
          _logger.w('Journal actif $journalId n\'existe plus ou accès refusé.');
          _errorMessage = 'Le journal sélectionné n\'est plus accessible.';
          clearActiveJournalState();
          // If not an initial load, try to recover.
          if (!isInitialLoad) _loadInitialJournalForUser(userId);
        }

        // If the active journal ID still matches the one being processed, update loading state.
        // This handles cases where clearActiveJournalState might have been called by an error condition above.
        if (_activeJournalId == journalId) {
          _isLoading = false;
        }
        notifyListeners();
      },
      onError: (error, stackTrace) {
        _logger.e('Erreur écoute journal actif $journalId', error: error, stackTrace: stackTrace);
        _errorMessage = 'Erreur de chargement du journal actif.';
        // clearActiveJournalState(); // Original commented out line
        _isLoading = false; // Explicitly set isLoading to false after an error.
        notifyListeners(); // Notify about the error state and loading false.
      },
    );
  }

  /// Clears the current active journal state.
  ///
  /// Resets [activeJournalId], [activeJournal], and [errorMessage] to null.
  /// Cancels any active journal subscription.
  /// This method does not notify listeners by itself, nor does it manage `_isLoading`;
  /// calling contexts should handle these aspects.
  void clearActiveJournalState() {
    _logger.i('Nettoyage état journal actif.');
    _activeJournalId = null;
    _activeJournal = null;
    _journalSubscription?.cancel();
    _journalSubscription = null;
    // _errorMessage = null; // Error message might be useful to keep if it led to this state.
    // Or clear it if this is a standard logout/user change.
    // For now, let's clear it as it implies a reset.
    _errorMessage = null;

    // Note: _isLoading should be managed by the calling method or context,
    // as clearing state doesn't inherently mean loading is finished or started.
    // However, typically, if we clear state, it's either because we logged out (loading done)
    // or an error occurred (loading should stop).
    // For robustness, methods calling this might need to manage _isLoading and notifyListeners.
  }

  /// Cleans up resources when the notifier is disposed.
  ///
  /// Cancels all active stream subscriptions.
  @override
  void dispose() {
    _logger.i('ActiveJournalNotifier dispose appelé.');
    _userSubscription?.cancel();
    _journalSubscription?.cancel();
    super.dispose();
  }
}
