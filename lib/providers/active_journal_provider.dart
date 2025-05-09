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

    if (isLoading) _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadInitialJournalForUser(String userId) async {
    _logger.i('Chargement journal initial pour utilisateur: $userId');

    try {
      String? lastUsedJournalId;

      if (lastUsedJournalId != null) {
        _logger.i('Dernier journal utilisé: $lastUsedJournalId');
        await setActiveJournal(lastUsedJournalId, userId, isInitialLoad: true);
      } else {
        _logger.i('Aucun dernier journal, chargement du premier.');
        final journals = await _firestoreService.getJournalsStream(userId).first;
        if (journals.isNotEmpty) {
          _logger.i('Premier journal trouvé: ${journals.first.id}');
          await setActiveJournal(journals.first.id, userId, isInitialLoad: true);
        } else {
          _logger.w('Aucun journal pour utilisateur $userId.');
          clearActiveJournalState();
        }
      }
    } catch (e, stackTrace) {
      _logger.e('Erreur chargement journal initial', error: e, stackTrace: stackTrace);
      _errorMessage = 'Impossible de charger le journal initial.';
      clearActiveJournalState();
    }
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
    if (!isInitialLoad) notifyListeners();

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
                clearActiveJournalState();
                if (!isInitialLoad) _loadInitialJournalForUser(userId);
              }
            } else {
              _logger.w('Journal actif $journalId n\'existe plus ou accès refusé.');
              _errorMessage = 'Le journal sélectionné n\'est plus accessible.';
              clearActiveJournalState();
              if (!isInitialLoad) _loadInitialJournalForUser(userId);
            }
            _isLoading = false;
            notifyListeners();
          },
          onError: (error, stackTrace) {
            _logger.e('Erreur écoute journal actif $journalId', error: error, stackTrace: stackTrace);
            _errorMessage = 'Erreur de chargement du journal actif.';
            clearActiveJournalState();
            _isLoading = false;
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
