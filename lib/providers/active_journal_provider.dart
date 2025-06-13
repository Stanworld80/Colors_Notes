import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/journal.dart';

final _logger = Logger(printer: PrettyPrinter(methodCount: 1, printTime: true));

class ActiveJournalNotifier extends ChangeNotifier {
  final AuthService _authService;
  final FirestoreService _firestoreService;

  String? _activeJournalId;
  Journal? _activeJournal;
  bool _isLoading = false;
  String? _errorMessage;

  StreamSubscription<User?>? _userSubscription;
  StreamSubscription<DocumentSnapshot?>? _journalSubscription;

  String? get activeJournalId => _activeJournalId;
  Journal? get activeJournal => _activeJournal;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// CONSTRUCTEUR MODIFIÉ : Ne fait plus rien d'asynchrone.
  ActiveJournalNotifier(this._authService, this._firestoreService) {
    _logger.i('ActiveJournalNotifier instancié (inactif).');
  }

  /// NOUVELLE MÉTHODE : Démarre l'écoute des changements d'authentification.
  /// Doit être appelée une fois que l'interface est prête.
  void listenToAuthChanges() {
    // Si on écoute déjà, on ne fait rien pour éviter les doublons.
    if (_userSubscription != null) return;

    _logger.i('ActiveJournalNotifier commence à écouter les changements d\'auth.');
    _userSubscription = _authService.userStream.listen(_onUserChanged);

    // Vérifie l'état initial au cas où l'utilisateur serait déjà connecté.
    if (_authService.currentUser != null) {
      _onUserChanged(_authService.currentUser);
    } else {
      clearActiveJournalState();
      notifyListeners();
    }
  }

  Future<void> _onUserChanged(User? user) async {
    _logger.i('Changement utilisateur détecté: ${user?.uid}');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    if (user == null) {
      clearActiveJournalState();
      _isLoading = false;
    } else {
      await _loadInitialJournalForUser(user.uid);
    }

    // Assure que l'état de chargement est bien mis à jour à la fin.
    if (_isLoading) {
      _isLoading = false;
    }
    notifyListeners();
  }

  Future<void> _loadInitialJournalForUser(String userId) async {
    _logger.i('Chargement du journal initial pour l\'utilisateur: $userId');
    try {
      final journals = await _firestoreService.getJournalsStream(userId).first;
      if (journals.isNotEmpty) {
        _logger.i('Premier journal trouvé: ${journals.first.id}');
        await setActiveJournal(journals.first.id, userId);
      } else {
        _logger.w('Aucun journal trouvé pour l\'utilisateur $userId.');
        clearActiveJournalState();
      }
    } catch (e, stackTrace) {
      _logger.e('Erreur lors du chargement du journal initial', error: e, stackTrace: stackTrace);
      _errorMessage = 'Impossible de charger le journal initial.';
      clearActiveJournalState();
    }
  }

  Future<void> setActiveJournal(String journalId, String userId) async {
    if (_activeJournalId == journalId && _activeJournal != null) {
      _logger.i('Journal $journalId déjà actif.');
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    await _journalSubscription?.cancel();
    _activeJournalId = journalId;

    _journalSubscription = _firestoreService.getJournalStream(journalId).listen(
          (journalDoc) {
        if (journalDoc.exists && journalDoc.data() != null) {
          final journalData = journalDoc.data() as Map<String, dynamic>;
          if (journalData['userId'] == userId) {
            _activeJournal = Journal.fromMap(journalData, journalDoc.id);
            _errorMessage = null;
          } else {
            _errorMessage = 'Accès non autorisé à ce journal.';
            clearActiveJournalState();
            _loadInitialJournalForUser(userId);
          }
        } else {
          _errorMessage = 'Le journal sélectionné n\'est plus accessible.';
          clearActiveJournalState();
          _loadInitialJournalForUser(userId);
        }
        _isLoading = false;
        notifyListeners();
      },
      onError: (error, stackTrace) {
        _logger.e('Erreur écoute journal actif $journalId', error: error, stackTrace: stackTrace);
        _errorMessage = 'Erreur de chargement du journal actif.';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  void clearActiveJournalState() {
    _activeJournalId = null;
    _activeJournal = null;
    _journalSubscription?.cancel();
    _journalSubscription = null;
    _errorMessage = null;
  }

  @override
  void dispose() {
    _logger.i('ActiveJournalNotifier dispose appelé.');
    _userSubscription?.cancel();
    _journalSubscription?.cancel();
    super.dispose();
  }
}
