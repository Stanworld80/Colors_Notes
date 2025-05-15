import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

import '../services/firestore_service.dart';
import '../models/note.dart';
import '../models/journal.dart';
import '../models/color_data.dart';
import '../providers/active_journal_provider.dart';
import 'entry_page.dart';
import '../services/auth_service.dart';

final _loggerPage = Logger(printer: PrettyPrinter(methodCount: 0, printTime: false));

class NoteListPage extends StatefulWidget {
  final String journalId;

  NoteListPage({super.key, required this.journalId});

  @override
  _NoteListPageState createState() => _NoteListPageState();
}

class _NoteListPageState extends State<NoteListPage> {
  String _sortBy = 'eventTimestamp';
  bool _sortDescending = true;
  bool _isGridView = false;
  bool _isDeletingAllNotes = false;

  ColorData? _getColorDataById(Journal? journal, String paletteElementId) {
    if (journal == null) return null;
    try {
      return journal.palette.colors.firstWhere((c) => c.paletteElementId == paletteElementId);
    } catch (e) {
      _loggerPage.w("ColorData non trouvé pour paletteElementId: $paletteElementId dans le journal ${journal.name}");
      return null;
    }
  }

  Widget _buildSortButton(String sortType, IconData mainIcon, String tooltip) {
    bool isActive = _sortBy == sortType;
    const double directionIconSize = 16.0;

    return IconButton(
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(mainIcon),
          if (isActive) Padding(padding: const EdgeInsets.only(left: 4.0), child: Icon(_sortDescending ? Icons.arrow_drop_down : Icons.arrow_drop_up, size: directionIconSize)),
        ],
      ),
      tooltip: tooltip + (isActive ? (_sortDescending ? " (Décroissant)" : " (Croissant)") : ""),
      color: isActive ? Theme.of(context).colorScheme.primary : Theme.of(context).iconTheme.color,
      onPressed: () {
        if (mounted) {
          setState(() {
            if (isActive) {
              _sortDescending = !_sortDescending;
            } else {
              _sortBy = sortType;
              if (sortType == 'eventTimestamp' || sortType == 'createdAt') {
                _sortDescending = true;
              } else {
                _sortDescending = false;
              }
            }
          });
        }
      },
    );
  }

  Future<void> _confirmDeleteNote(BuildContext context, FirestoreService firestoreService, String noteId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirmer la suppression'),
          content: const Text('Voulez-vous vraiment supprimer cette note ?'),
          actions: <Widget>[
            TextButton(child: const Text('Annuler'), onPressed: () => Navigator.of(dialogContext).pop(false)),
            TextButton(style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Supprimer'), onPressed: () => Navigator.of(dialogContext).pop(true)),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await firestoreService.deleteNote(noteId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note supprimée avec succès.')));
        }
      } catch (e) {
        _loggerPage.e("Erreur suppression note: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur lors de la suppression: ${e.toString()}')));
        }
      }
    }
  }

  Future<void> _confirmDeleteAllNotes(BuildContext context, FirestoreService firestoreService, String journalId, String userId) async {
    if (_isDeletingAllNotes) return;

    final bool? firstConfirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Supprimer toutes les notes ?'),
          content: const Text('Cette action supprimera DÉFINITIVEMENT toutes les notes de ce journal. Voulez-vous continuer ?'),
          actions: <Widget>[
            TextButton(child: const Text('Annuler'), onPressed: () => Navigator.of(dialogContext).pop(false)),
            TextButton(style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Supprimer Tout'), onPressed: () => Navigator.of(dialogContext).pop(true)),
          ],
        );
      },
    );

    if (firstConfirm != true) return;

    final bool? secondConfirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('CONFIRMATION FINALE'),
          content: const Text('Êtes-vous absolument certain(e) ? Cette action est IRRÉVERSIBLE.'),
          actions: <Widget>[
            TextButton(child: const Text('NON, ANNULER'), onPressed: () => Navigator.of(dialogContext).pop(false)),
            TextButton(
              style: TextButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('OUI, SUPPRIMER TOUTES LES NOTES'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (secondConfirm == true) {
      if (mounted) {
        setState(() {
          _isDeletingAllNotes = true;
        });
      }
      try {
        await firestoreService.deleteAllNotesInJournal(journalId, userId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Toutes les notes ont été supprimées.'), backgroundColor: Colors.green));
        }
      } catch (e) {
        _loggerPage.e("Erreur suppression de toutes les notes: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur lors de la suppression de toutes les notes: ${e.toString()}'), backgroundColor: Colors.red));
        }
      } finally {
        if (mounted) {
          setState(() {
            _isDeletingAllNotes = false;
          });
        }
      }
    }
  }

  Widget _buildNoteGridItem(BuildContext context, Note note, ColorData? colorData, FirestoreService firestoreService, Journal? journal) {
    final DateFormat dateFormat = DateFormat('dd/MM/yy HH:mm', 'fr_FR');
    final Color cardColor = colorData?.color ?? Colors.grey.shade100;
    final Color textColor = cardColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
    final Color subtleTextColor = cardColor.computeLuminance() > 0.5 ? Colors.black54 : Colors.white70;

    double titleFontSize = 10.0;
    double contentFontSize = 11.0;
    double dateFontSize = 9.0;
    int maxLinesForContent = 2;

    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth / 9 < 80) {
      titleFontSize = 8.0;
      contentFontSize = 9.0;
      dateFontSize = 7.0;
      maxLinesForContent = 1;
    }

    return Card(
      elevation: 2.0,
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      child: InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => EntryPage(journalId: widget.journalId, noteToEdit: note)));
        },
        borderRadius: BorderRadius.circular(8.0),
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      colorData?.title ?? "Couleur",
                      style: TextStyle(fontSize: titleFontSize, color: subtleTextColor, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: textColor.withOpacity(0.7), size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    tooltip: "Supprimer la note",
                    onPressed: () => _confirmDeleteNote(context, firestoreService, note.id),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  note.content,
                  style: TextStyle(fontWeight: FontWeight.normal, fontSize: contentFontSize, color: textColor),
                  maxLines: maxLinesForContent,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(dateFormat.format(note.eventTimestamp.toDate().toLocal()), style: TextStyle(fontSize: dateFontSize, color: subtleTextColor)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final activeJournalNotifier = Provider.of<ActiveJournalNotifier>(context);
    final Journal? journalForPalette = activeJournalNotifier.activeJournalId == widget.journalId ? activeJournalNotifier.activeJournal : null;
    final authService = Provider.of<AuthService>(context, listen: false);
    final String? currentUserId = authService.currentUser?.uid;

    String firestoreSortField = _sortBy;
    bool firestoreSortDescending = _sortDescending;

    if (_sortBy == 'paletteOrder' || _sortBy == 'content') {
      firestoreSortField = 'eventTimestamp';
      firestoreSortDescending = true;
    }

    return Scaffold(
      body: StreamBuilder<List<Note>>(
        stream: firestoreService.getJournalNotesStream(widget.journalId, sortBy: firestoreSortField, descending: firestoreSortDescending),
        builder: (context, snapshot) {
          if (activeJournalNotifier.isLoading && journalForPalette == null && activeJournalNotifier.activeJournalId == widget.journalId) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            _loggerPage.e("Erreur chargement notes: ${snapshot.error}");
            return Center(child: Text('Erreur de chargement des notes. ${snapshot.error}'));
          }

          List<Note> notes = snapshot.data ?? [];

          if (notes.isEmpty && !_isDeletingAllNotes) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notes_outlined, size: 60, color: Theme.of(context).colorScheme.secondary),
                  const SizedBox(height: 16),
                  Text('Aucune note dans ce journal.', style: Theme.of(context).textTheme.headlineSmall),
                ],
              ),
            );
          }

          if (_sortBy == 'paletteOrder' && journalForPalette != null) {
            final paletteOrderMap = {for (var i = 0; i < journalForPalette.palette.colors.length; i++) journalForPalette.palette.colors[i].paletteElementId: i};
            notes.sort((a, b) {
              final indexA = paletteOrderMap[a.paletteElementId] ?? double.maxFinite.toInt();
              final indexB = paletteOrderMap[b.paletteElementId] ?? double.maxFinite.toInt();
              int comparison = indexA.compareTo(indexB);
              return _sortDescending ? -comparison : comparison;
            });
          } else if (_sortBy == 'content') {
            notes.sort((a, b) {
              int comparison = a.content.toLowerCase().compareTo(b.content.toLowerCase());
              return _sortDescending ? -comparison : comparison;
            });
          }

          if (journalForPalette == null && activeJournalNotifier.activeJournalId != widget.journalId && !activeJournalNotifier.isLoading) {
            _loggerPage.w("Détails du journal (pour la palette) non disponibles pour ${widget.journalId}. Le tri par couleur peut ne pas fonctionner correctement.");
          }

          final screenWidth = MediaQuery.of(context).size.width;
          int gridCrossAxisCount;
          if (screenWidth < 400) {
            gridCrossAxisCount = 3;
          } else if (screenWidth < 600) {
            gridCrossAxisCount = 4;
          } else if (screenWidth < 800) {
            gridCrossAxisCount = 5;
          } else if (screenWidth < 1000) {
            gridCrossAxisCount = 6;
          } else if (screenWidth < 1200) {
            gridCrossAxisCount = 7;
          } else if (screenWidth < 1400) {
            gridCrossAxisCount = 8;
          } else {
            gridCrossAxisCount = 9;
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (currentUserId != null && notes.isNotEmpty)
                      Tooltip(
                        message: "Supprimer toutes les notes de ce journal",
                        child: IconButton(
                          icon: Icon(Icons.delete_sweep_outlined, color: Theme.of(context).colorScheme.error),
                          onPressed: _isDeletingAllNotes ? null : () => _confirmDeleteAllNotes(context, firestoreService, widget.journalId, currentUserId),
                        ),
                      ),
                    if (_isDeletingAllNotes) const Padding(padding: EdgeInsets.all(8.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.0))),
                    IconButton(
                      icon: Icon(_isGridView ? Icons.view_list_outlined : Icons.grid_view_outlined),
                      tooltip: _isGridView ? "Afficher en liste" : "Afficher en grille",
                      onPressed: () {
                        if (mounted) {
                          setState(() {
                            _isGridView = !_isGridView;
                          });
                        }
                      },
                    ),
                    Expanded(
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 0,
                        runSpacing: 0,
                        children: [
                          _buildSortButton('eventTimestamp', Icons.event_note_outlined, "Trier par date d'événement"),
                          _buildSortButton('paletteOrder', Icons.palette_outlined, "Trier par couleur de palette"),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child:
                    _isGridView
                        ? GridView.builder(
                          padding: const EdgeInsets.all(8.0),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: gridCrossAxisCount, crossAxisSpacing: 4.0, mainAxisSpacing: 4.0, childAspectRatio: 1.1),
                          itemCount: notes.length,
                          itemBuilder: (context, index) {
                            final note = notes[index];
                            final colorData = _getColorDataById(journalForPalette, note.paletteElementId);
                            return _buildNoteGridItem(context, note, colorData, firestoreService, journalForPalette);
                          },
                        )
                        : ListView.builder(
                          padding: const EdgeInsets.all(8.0),
                          itemCount: notes.length,
                          itemBuilder: (context, index) {
                            final note = notes[index];
                            final colorData = _getColorDataById(journalForPalette, note.paletteElementId);
                            final DateFormat dateFormat = DateFormat('EEEE dd MMMM GetSRP à HH:mm', 'fr_FR');

                            final Color cardColor = colorData?.color ?? Theme.of(context).cardColor;
                            final Color textColor = cardColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
                            final Color subtleTextColor = cardColor.computeLuminance() > 0.5 ? Colors.black54 : Colors.white70;

                            return Card(
                              elevation: 2.0,
                              color: cardColor,
                              margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(12.0),
                                leading:
                                    colorData != null
                                        ? CircleAvatar(backgroundColor: Colors.transparent)
                                        : const CircleAvatar(backgroundColor: Colors.grey, child: Icon(Icons.help_outline, color: Colors.white)),
                                title: Text(note.content, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16, color: textColor), maxLines: 3, overflow: TextOverflow.ellipsis),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 6.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (colorData != null) Text(colorData.title, style: TextStyle(fontSize: 12, color: subtleTextColor, fontWeight: FontWeight.bold)),
                                      Text('Date: ${dateFormat.format(note.eventTimestamp.toDate().toLocal())}', style: TextStyle(fontSize: 12, color: subtleTextColor)),
                                      Text(
                                        'Créé le: ${DateFormat('dd/MM/yy HH:mm', 'fr_FR').format(note.createdAt.toDate().toLocal())}',
                                        style: TextStyle(fontSize: 10, color: subtleTextColor.withOpacity(0.8)),
                                      ),
                                    ],
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: Icon(Icons.delete_forever_outlined, color: textColor.withOpacity(0.7)),
                                  tooltip: "Supprimer cette note",
                                  onPressed: () => _confirmDeleteNote(context, firestoreService, note.id),
                                ),
                                onTap: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => EntryPage(journalId: widget.journalId, noteToEdit: note)));
                                },
                              ),
                            );
                          },
                        ),
              ),
            ],
          );
        },
      ),
    );
  }
}
