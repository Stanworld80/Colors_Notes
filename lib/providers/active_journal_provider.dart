// lib/providers/active_journal_provider.dart
import 'package:flutter/foundation.dart'; // Peut rester utile
import '../models/journal.dart';

class ActiveJournalNotifier extends ChangeNotifier {
  Journal? _currentJournal;
  Journal? get currentJournal => _currentJournal;
  String get activeJournalName => _currentJournal?.name ?? 'Chargement...';
  String? get activeJournalId => _currentJournal?.id;

  // Méthode setActiveJournal Simplifiée
  void setActiveJournal(Journal? journal) {
    // Vérifier si l'instance de l'objet Journal passé est différente de l'actuelle
    // Cela fonctionne car _savePalette crée une nouvelle instance Journal lors de la mise à jour.
    if (!identical(_currentJournal, journal)) {
      // Utilise identical pour comparer les références mémoire
      _currentJournal = journal;
      print("ActiveJournalNotifier: State updated (new instance). ID=${_currentJournal?.id}, Name=${_currentJournal?.name}");
      notifyListeners(); // Notifie les widgets qui écoutent
    } else {
      print("ActiveJournalNotifier: State unchanged (same instance or both null).");
    }
  }

  // La méthode clear peut simplement appeler setActiveJournal(null)
  void clearActiveJournal() {
    setActiveJournal(null);
  }
}
