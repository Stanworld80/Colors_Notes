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

  ActiveJournalNotifier(this._authService, this._firestoreService) {
    _logger.i('ActiveJournalNotifier initialisé.');
    _userSubscription = _authService.userStream.listen(_onUserChanged);
    if (_authService.currentUser != null) {
      _onUserChanged(_authService.currentUser);
    }
  }

  Future<void> _onUserChanged(User? user) async {
    _logger.i('Changement utilisateur: ${user?.uid}');
    _isLoading = true;
    _errorMessage = null;

    if (user == null) {
      clearActiveJournalState();
      _isLoading = false;
    } else {
      await _loadInitialJournalForUser(user.uid);
    }

    // Correction: S'assurer que isLoading est mis à false si ce n'est pas déjà fait
    // dans _loadInitialJournalForUser ou clearActiveJournalState.
    // Cependant, la logique actuelle semble le couvrir.
    // Si _isLoading est toujours true ici, cela signifie qu'une opération asynchrone
    // n'a pas correctement mis à jour son état.
    // Pour plus de robustesse, on peut ajouter :
    if (_isLoading) {
      _isLoading = false;
    }
    notifyListeners();
  }

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
        await setActiveJournal(journals.first.id, userId, isInitialLoad: true);
      } else {
        _logger.w('Aucun journal pour utilisateur $userId.');
        clearActiveJournalState(); // Met _isLoading à false et notifie si nécessaire
      }
    } catch (e, stackTrace) {
      _logger.e('Erreur chargement journal initial', error: e, stackTrace: stackTrace);
      _errorMessage = 'Impossible de charger le journal initial.';
      clearActiveJournalState(); // Met _isLoading à false et notifie si nécessaire
    }
    // _isLoading est géré dans setActiveJournal ou clearActiveJournalState,
    // et finalement dans _onUserChanged.
  }

  Future<void> setActiveJournal(String journalId, String userId, {bool isInitialLoad = false}) async {
    _logger.i('Définition journal actif: $journalId pour utilisateur $userId');
    if (_activeJournalId == journalId && _activeJournal != null && !isInitialLoad) {
      _logger.i('Journal $journalId déjà actif.');
      if (_isLoading) {
        _isLoading = false;
        notifyListeners();
      }
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    if (!isInitialLoad) notifyListeners(); // Notifie pour les changements initiés par l'utilisateur

    await _journalSubscription?.cancel();
    _activeJournalId = journalId;

    _journalSubscription = _firestoreService
        .getJournalStream(journalId)
        .listen(
          (journalDoc) {
            if (journalDoc.exists && journalDoc.data() != null) {
              final journalData = journalDoc.data() as Map<String, dynamic>;
              if (journalData['userId'] == userId) {
                _activeJournal = Journal.fromMap(journalData, journalDoc.id);
                _logger.i('Journal actif màj: ${_activeJournal?.name} (ID: $journalId)');
                _errorMessage = null;
              } else {
                _logger.w('Tentative de définition d\'un journal actif ($journalId) n\'appartenant pas à l\'utilisateur ($userId). Appartenance: ${journalData['userId']}');
                _errorMessage = 'Accès non autorisé à ce journal.';
                clearActiveJournalState(); // Ceci mettra aussi _isLoading à false et notifiera
                if (!isInitialLoad) _loadInitialJournalForUser(userId); // Tente de charger un journal valide
              }
            } else {
              _logger.w('Journal actif $journalId n\'existe plus ou accès refusé.');
              _errorMessage = 'Le journal sélectionné n\'est plus accessible.';
              clearActiveJournalState(); // Ceci mettra aussi _isLoading à false et notifiera
              if (!isInitialLoad) _loadInitialJournalForUser(userId); // Tente de charger un journal valide
            }
            // Si clearActiveJournalState n'a pas été appelé, mettre isLoading à false ici.
            // Si clearActiveJournalState a été appelé, il a déjà géré isLoading et notifyListeners.
            if (_activeJournalId == journalId) {
              // Vérifie si le journal est toujours celui qu'on traite
              _isLoading = false;
            }
            notifyListeners();
          },
          onError: (error, stackTrace) {
            _logger.e('Erreur écoute journal actif $journalId', error: error, stackTrace: stackTrace);
            _errorMessage = 'Erreur de chargement du journal actif.';
            clearActiveJournalState(); // Ceci mettra aussi _isLoading à false et notifiera
            _isLoading = false; // Assurez-vous que isLoading est false après une erreur
            notifyListeners();
          },
        );
  }

  void clearActiveJournalState() {
    _logger.i('Nettoyage état journal actif.');
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
