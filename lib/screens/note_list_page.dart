import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:intl/intl.dart';

import '../services/firestore_service.dart';
import '../models/note.dart';
import '../models/journal.dart';
import '../models/color_data.dart';
import '../providers/active_journal_provider.dart';
import 'entry_page.dart';

final _loggerPage = Logger(printer: PrettyPrinter(methodCount: 0));

class NoteListPage extends StatefulWidget {
  final String journalId;

  NoteListPage({Key? key, required this.journalId}) : super(key: key);

  @override
  _NoteListPageState createState() => _NoteListPageState();
}

class _NoteListPageState extends State<NoteListPage> {
  String _sortBy = 'eventTimestamp';
  bool _sortDescending = true;

  ColorData? _getColorDataById(Journal? journal, String paletteElementId) {
    if (journal == null) return null;
    try {
      return journal.palette.colors.firstWhere((c) => c.paletteElementId == paletteElementId);
    } catch (e) {
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
                  SizedBox(height: 8),
                  Text(
                    'Appuyez sur le bouton "+" pour en ajouter une.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            );
          }

          final notes = snapshot.data!;

          if (journalForPalette == null && activeJournalNotifier.activeJournalId != widget.journalId && !activeJournalNotifier.isLoading) {
            _loggerPage.w("Détails du journal (pour la palette) non disponibles pour ${widget.journalId}. Les couleurs des notes pourraient ne pas s'afficher.");
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: Icon(Icons.sort_outlined),
                      label: Text("Trier"),
                      onPressed: () => _showSortOptions(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.all(8.0),
                  itemCount: notes.length,
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    final colorData = _getColorDataById(journalForPalette, note.paletteElementId);
                    final DateFormat dateFormat = DateFormat('EEEE dd MMMM<x_bin_534>, HH:mm', 'fr_FR');

                    return Card(
                      elevation: 2.0,
                      margin: EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        side: BorderSide(
                          color: colorData?.color ?? Colors.grey.shade300,
                          width: 1.5,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.all(12.0),
                        leading: colorData != null
                            ? CircleAvatar(
                          backgroundColor: colorData.color,
                          child: Text(
                            colorData.title.isNotEmpty ? colorData.title[0].toUpperCase() : '?',
                            style: TextStyle(color: colorData.color.computeLuminance() > 0.5 ? Colors.black : Colors.white),
                          ),
                        )
                            : CircleAvatar(backgroundColor: Colors.grey, child: Icon(Icons.palette_outlined, color: Colors.white)),
                        title: Text(
                          note.content,
                          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (colorData != null) Text("Humeur: ${colorData.title}", style: TextStyle(fontSize: 12)),
                              Text(
                                'Date: ${dateFormat.format(note.eventTimestamp.toDate().toLocal())}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                              Text(
                                'Créé le: ${DateFormat('dd/MM/yy HH:mm', 'fr_FR').format(note.createdAt.toDate().toLocal())}',
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.delete_forever_outlined, color: Colors.redAccent),
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
        _loggerPage.i("Note $noteId supprimée.");
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
}
