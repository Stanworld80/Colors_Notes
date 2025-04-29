// lib/providers/active_agenda_provider.dart
import 'package:flutter/foundation.dart'; // Peut rester utile
import '../models/agenda.dart';

class ActiveAgendaNotifier extends ChangeNotifier {
  Agenda? _currentAgenda;

  Agenda? get currentAgenda => _currentAgenda;
  String get activeAgendaName => _currentAgenda?.name ?? 'Chargement...';
  String? get activeAgendaId => _currentAgenda?.id;

  // Méthode setActiveAgenda Simplifiée
  void setActiveAgenda(Agenda? agenda) {
    // Vérifier si l'instance de l'objet Agenda passé est différente de l'actuelle
    // Cela fonctionne car _savePalette crée une nouvelle instance Agenda lors de la mise à jour.
    if (!identical(_currentAgenda, agenda)) { // Utilise identical pour comparer les références mémoire
      _currentAgenda = agenda;
      print("ActiveAgendaNotifier: State updated (new instance). ID=${_currentAgenda?.id}, Name=${_currentAgenda?.name}");
      notifyListeners(); // Notifie les widgets qui écoutent
    } else {
      print("ActiveAgendaNotifier: State unchanged (same instance or both null).");
    }
  }

  // La méthode clear peut simplement appeler setActiveAgenda(null)
  void clearActiveAgenda() {
    setActiveAgenda(null);
  }
}