// lib/providers/active_agenda_provider.dart
import 'package:flutter/foundation.dart';
import '../models/agenda.dart'; // Importer Agenda

class ActiveAgendaNotifier extends ChangeNotifier {
  // Remplacer _activeAgendaId et _activeAgendaName par l'objet Agenda complet
  Agenda? _currentAgenda;

  Agenda? get currentAgenda => _currentAgenda;

  // Garder un getter pour le nom pour la compatibilité/simplicité si besoin
  String get activeAgendaName => _currentAgenda?.name ?? 'Chargement...';

  String? get activeAgendaId => _currentAgenda?.id; // Getter pour l'ID aussi

  void setActiveAgenda(Agenda? agenda) {
    // Déterminer si une mise à jour est nécessaire
    bool hasChanged = false;
    if (_currentAgenda?.id != agenda?.id) {
      // L'ID a changé (ou on passe de/vers null)
      hasChanged = true;
    } else if (agenda != null && _currentAgenda != null) {
      // L'ID est le même, vérifier si le nom a changé
      if (_currentAgenda!.name != agenda.name) {
        hasChanged = true;
      }
      // Ajoutez ici d'autres vérifications si nécessaire (ex: changement de palette)
      // else if (!listEquals(_currentAgenda!.embeddedPaletteInstance.colors, agenda.embeddedPaletteInstance.colors)) {
      //    hasChanged = true;
      // }
    }

    // Si une mise à jour est nécessaire, mettre à jour l'état et notifier
    if (hasChanged) {
      _currentAgenda = agenda;
      print(
        "ActiveAgendaNotifier: State updated. ID=${_currentAgenda?.id}, Name=${_currentAgenda?.name}",
      );
      notifyListeners();
    } else {
      print("ActiveAgendaNotifier: State unchanged."); // Pour déboguer
    }
  }

  // Optionnel: garder clearActiveAgenda si vous préférez l'utiliser explicitement
  void clearActiveAgenda() {
    if (_currentAgenda != null) {
      _currentAgenda = null;
      print("ActiveAgendaNotifier: State cleared via clearActiveAgenda().");
      notifyListeners();
    }
  }
}
