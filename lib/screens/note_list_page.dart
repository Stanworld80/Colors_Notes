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

final _loggerPage = Logger(printer: PrettyPrinter(methodCount: 0, printTime: false));

class NoteListPage extends StatefulWidget {
  final String journalId;

  NoteListPage({Key? key, required this.journalId}) : super(key: key);

  @override
  _NoteListPageState createState() => _NoteListPageState();
}

class _NoteListPageState extends State<NoteListPage> {
  String _sortBy = 'eventTimestamp';
  bool _sortDescending = true;
  bool _isGridView = false;

  ColorData? _getColorDataById(Journal? journal, String paletteElementId) {
    if (journal == null) return null;
    try {
      return journal.palette.colors.firstWhere((c) => c.paletteElementId == paletteElementId);
    } catch (e) {
      _loggerPage.w("ColorData non trouvé pour paletteElementId: $paletteElementId dans le journal ${journal.name}");
      return null;
    }
  }

  void _showSortOptions(BuildContext scaffoldContext) {
    showModalBottomSheet(
      context: context,
      builder: (builderContext) {
        return Wrap(
          children: <Widget>[
            ListTile(
              leading: Icon(_sortBy == 'eventTimestamp' ? (_sortDescending ? Icons.arrow_downward : Icons.arrow_upward) : Icons.date_range_outlined),
              title: Text('Trier par Date de l\'événement'),
              onTap: () {
                if (mounted) {
                  setState(() {
                    if (_sortBy == 'eventTimestamp') _sortDescending = !_sortDescending;
                    else _sortDescending = true;
                    _sortBy = 'eventTimestamp';
                  });
                }
                Navigator.pop(builderContext);
              },
            ),
            ListTile(
              leading: Icon(_sortBy == 'createdAt' ? (_sortDescending ? Icons.arrow_downward : Icons.arrow_upward) : Icons.schedule_outlined),
              title: Text('Trier par Date de création'),
              onTap: () {
                if (mounted) {
                  setState(() {
                    if (_sortBy == 'createdAt') _sortDescending = !_sortDescending;
                    else _sortDescending = true;
                    _sortBy = 'createdAt';
                  });
                }
                Navigator.pop(builderContext);
              },
            ),
            ListTile(
              leading: Icon(_sortBy == 'content' ? (_sortDescending ? Icons.arrow_downward : Icons.arrow_upward) : Icons.sort_by_alpha_outlined),
              title: Text('Trier par Contenu'),
              onTap: () {
                if (mounted) {
                  setState(() {
                    if (_sortBy == 'content') _sortDescending = !_sortDescending;
                    else _sortDescending = false;
                    _sortBy = 'content';
                  });
                }
                Navigator.pop(builderContext);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDeleteNote(BuildContext context, FirestoreService firestoreService, String noteId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Confirmer la suppression'),
          content: Text('Voulez-vous vraiment supprimer cette note ?'),
          actions: <Widget>[
            TextButton(
              child: Text('Annuler'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text('Supprimer'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await firestoreService.deleteNote(noteId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Note supprimée avec succès.')),
          );
        }
      } catch (e) {
        _loggerPage.e("Erreur suppression note: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur lors de la suppression: ${e.toString()}')),
          );
        }
      }
    }
  }

  Widget _buildNoteGridItem(BuildContext context, Note note, ColorData? colorData, FirestoreService firestoreService, Journal? journal) {
    final DateFormat dateFormat = DateFormat('dd/MM/yy HH:mm', 'fr_FR');
    final Color cardColor = colorData?.color ?? Colors.grey.shade100;
    final Color textColor = cardColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
    final Color subtleTextColor = cardColor.computeLuminance() > 0.5 ? Colors.black54 : Colors.white70;
    final Color iconColor = cardColor.computeLuminance() > 0.5 ? Colors.black54 : Colors.white;


    return Card(
      elevation: 3.0,
      color: cardColor, // Couleur de fond de la carte
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        // Optionnel: retirer la bordure si la couleur de fond est suffisante
        // side: BorderSide(
        //   color: colorData?.color ?? Colors.grey.shade300,
        //   width: 1.5,
        // ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EntryPage(
                journalId: widget.journalId,
                noteToEdit: note,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Optionnel: Remplacer le CircleAvatar par le titre de la couleur si désiré
                  Text(
                    colorData?.title ?? "Couleur",
                    style: TextStyle(fontSize: 11, color: subtleTextColor, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: textColor.withOpacity(0.7), size: 20),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    tooltip: "Supprimer la note",
                    onPressed: () => _confirmDeleteNote(context, firestoreService, note.id),
                  )
                ],
              ),
              SizedBox(height: 6),
              Expanded(
                child: Text(
                  note.content,
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: textColor),
                  maxLines: (journal?.palette.colors.length ?? 0) > 5 ? 3 : 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Spacer(), // Peut-être plus nécessaire si Expanded est utilisé pour le contenu
              Text(
                dateFormat.format(note.eventTimestamp.toDate().toLocal()),
                style: TextStyle(fontSize: 10, color: subtleTextColor),
              ),
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

    final Journal? journalForPalette = activeJournalNotifier.activeJournalId == widget.journalId
        ? activeJournalNotifier.activeJournal
        : null;

    return Scaffold(
      body: StreamBuilder<List<Note>>(
        stream: firestoreService.getJournalNotesStream(widget.journalId, sortBy: _sortBy, descending: _sortDescending),
        builder: (context, snapshot) {
          if (activeJournalNotifier.isLoading && journalForPalette == null && activeJournalNotifier.activeJournalId == widget.journalId) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            _loggerPage.e("Erreur chargement notes: ${snapshot.error}");
            return Center(child: Text('Erreur de chargement des notes. ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notes_outlined, size: 60, color: Theme.of(context).colorScheme.secondary),
                  SizedBox(height: 16),
                  Text(
                    'Aucune note dans ce journal.',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
            );
          }

          final notes = snapshot.data!;

          if (journalForPalette == null && activeJournalNotifier.activeJournalId != widget.journalId && !activeJournalNotifier.isLoading) {
            _loggerPage.w("Détails du journal (pour la palette) non disponibles pour ${widget.journalId}.");
          }

          final screenWidth = MediaQuery.of(context).size.width;
          int gridCrossAxisCount = 2;
          if (screenWidth > 600) gridCrossAxisCount = 3;
          if (screenWidth > 900) gridCrossAxisCount = 4;
          if (screenWidth > 1200) gridCrossAxisCount = 5;


          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
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
                    SizedBox(width: 8),
                    TextButton.icon(
                      icon: Icon(Icons.sort_outlined),
                      label: Text("Trier"),
                      onPressed: () => _showSortOptions(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isGridView
                    ? GridView.builder(
                  padding: EdgeInsets.all(12.0),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: gridCrossAxisCount,
                    crossAxisSpacing: 10.0,
                    mainAxisSpacing: 10.0,
                    childAspectRatio: (journalForPalette?.palette.colors.length ?? 0) > 5 ? 3/2.8 : 3/2.2,
                  ),
                  itemCount: notes.length,
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    final colorData = _getColorDataById(journalForPalette, note.paletteElementId);
                    return _buildNoteGridItem(context, note, colorData, firestoreService, journalForPalette);
                  },
                )
                    : ListView.builder(
                  padding: EdgeInsets.all(8.0),
                  itemCount: notes.length,
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    final colorData = _getColorDataById(journalForPalette, note.paletteElementId);
                    final DateFormat dateFormat = DateFormat('EEEE dd MMMM Künstler, HH:mm', 'fr_FR');

                    final Color cardColor = colorData?.color ?? Theme.of(context).cardColor;
                    final Color textColor = cardColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
                    final Color subtleTextColor = cardColor.computeLuminance() > 0.5 ? Colors.black54 : Colors.white70;
                    final Color iconColor = cardColor.computeLuminance() > 0.5 ? Colors.black54 : Colors.white;


                    return Card(
                      elevation: 2.0,
                      color: cardColor, // Couleur de fond de la carte
                      margin: EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        // Optionnel: retirer la bordure si la couleur de fond est suffisante
                        // side: BorderSide(
                        //   color: colorData?.color ?? Colors.grey.shade300,
                        //   width: 1.5,
                        // ),
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.all(12.0),
                        leading: colorData != null
                            ? CircleAvatar(
                          backgroundColor: Colors.transparent, // Rendre transparent si le fond de la carte est la couleur
                          child: Text(
                            colorData.title.isNotEmpty ? colorData.title[0].toUpperCase() : '?',
                            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                          ),
                        )
                            : CircleAvatar(backgroundColor: Colors.grey, child: Icon(Icons.palette_outlined, color: Colors.white)),
                        title: Text(
                          note.content,
                          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16, color: textColor),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (colorData != null) Text("Humeur: ${colorData.title}", style: TextStyle(fontSize: 12, color: subtleTextColor)),
                              Text(
                                'Date: ${dateFormat.format(note.eventTimestamp.toDate().toLocal())}',
                                style: TextStyle(fontSize: 12, color: subtleTextColor),
                              ),
                              Text(
                                'Créé le: ${DateFormat('dd/MM/yy HH:mm', 'fr_FR').format(note.createdAt.toDate().toLocal())}',
                                style: TextStyle(fontSize: 10, color: subtleTextColor.withOpacity(0.8)),
                              ),
                            ],
                          ),
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.delete_forever_outlined, color: textColor.withOpacity(0.7)),
                          onPressed: () => _confirmDeleteNote(context, firestoreService, note.id),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EntryPage(
                                journalId: widget.journalId,
                                noteToEdit: note,
                              ),
                            ),
                          );
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
