// lib/screens/note_list_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../providers/active_journal_provider.dart';
import '../services/firestore_service.dart';
import '../models/note.dart';
import '../models/journal.dart';
import '../models/color_data.dart';
import '../models/palette.dart';
import '../widgets/dynamic_journal_app_bar.dart';
import 'edit_palette_model_page.dart';

enum SortOrder { descending, ascending }

class NoteListPage extends StatefulWidget {
  const NoteListPage({Key? key}) : super(key: key);

  @override
  State<NoteListPage> createState() => _NoteListPageState();
}

class _NoteListPageState extends State<NoteListPage> {
  SortOrder _currentSortOrder = SortOrder.descending;
  bool _groupByColor = false;
  bool _isGridView = false;

  void _showEditNoteDialog(BuildContext context, Note note, Palette? currentPalette) {
    final TextEditingController commentController = TextEditingController(text: note.comment);
    ColorData? currentColorData;
    if (currentPalette != null) {
      try {
        currentColorData = currentPalette.colors.firstWhere(
              (c) => c.paletteElementId == note.paletteElementId,
        );
      } catch (e) {
        print("Note orpheline (ID) détectée dans _showEditNoteDialog: ID '${note.paletteElementId}' non trouvé.");
        currentColorData = null;
      }
    }
    Color displayColor = currentColorData != null ? _safeParseColor(currentColorData.hexValue) : Colors.grey;
    String displayTitle = currentColorData?.title ?? "ID: ${note.paletteElementId}";

    final firestoreService = context.read<FirestoreService>();
    DateTime selectedDateTime = note.eventTimestamp.toDate();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
            builder: (stfContext, stfSetState) {
              Future<void> _selectDate() async {
                final DateTime? pickedDate = await showDatePicker(context: stfContext, initialDate: selectedDateTime, firstDate: DateTime(2000), lastDate: DateTime(2101));
                if (pickedDate != null) {
                  final newDateTime = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, selectedDateTime.hour, selectedDateTime.minute);
                  stfSetState(() { selectedDateTime = newDateTime; });
                }
              }
              Future<void> _selectTime() async {
                final TimeOfDay? pickedTime = await showTimePicker(context: stfContext, initialTime: TimeOfDay.fromDateTime(selectedDateTime));
                if (pickedTime != null) {
                  final newDateTime = DateTime(selectedDateTime.year, selectedDateTime.month, selectedDateTime.day, pickedTime.hour, pickedTime.minute);
                  stfSetState(() { selectedDateTime = newDateTime; });
                }
              }

              return AlertDialog(
                title: Row(
                  children: [
                    Container(width: 20, height: 20, color: displayColor),
                    const SizedBox(width: 10),
                    Expanded(child: Text(
                        'Modifier: ${currentColorData != null ? displayTitle : "(ID Non Trouvé)"}',
                        overflow: TextOverflow.ellipsis)
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(controller: commentController, autofocus: true, maxLength: 256, decoration: const InputDecoration(hintText: 'Modifiez votre commentaire...', labelText: 'Commentaire'), maxLines: 3, textInputAction: TextInputAction.newline,),
                      const SizedBox(height: 20),
                      Text("Date et Heure de l'événement:", style: Theme.of(stfContext).textTheme.labelMedium),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(DateFormat('dd/MM/yyyy HH:mm').format(selectedDateTime)),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(icon: const Icon(Icons.calendar_today, size: 20), tooltip: 'Choisir la date', onPressed: _selectDate, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                              const SizedBox(width: 5),
                              IconButton(icon: const Icon(Icons.access_time, size: 20), tooltip: 'Choisir l\'heure', onPressed: _selectTime, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                            ],
                          )
                        ],
                      ),
                    ],
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Supprimer'),
                    onPressed: () { Navigator.of(dialogContext).pop(); _showDeleteConfirmDialog(context, note); },
                  ),
                  const Spacer(),
                  TextButton(child: const Text('Annuler'), onPressed: () { Navigator.of(dialogContext).pop(); },),
                  ElevatedButton(
                    child: const Text('Enregistrer'),
                    onPressed: () async {
                      final updatedComment = commentController.text.trim();
                      final updatedTimestamp = Timestamp.fromDate(selectedDateTime);
                      bool commentChanged = updatedComment.isNotEmpty && updatedComment != note.comment;
                      bool timestampChanged = updatedTimestamp.seconds != note.eventTimestamp.seconds || updatedTimestamp.nanoseconds != note.eventTimestamp.nanoseconds;

                      if (commentChanged || timestampChanged) {
                        try {
                          await firestoreService.updateNoteDetails(
                            note.id,
                            newComment: commentChanged ? updatedComment : null,
                            newEventTimestamp: timestampChanged ? updatedTimestamp : null,
                          );
                          Navigator.of(dialogContext).pop();
                          if (context.mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note modifiée.'), duration: Duration(seconds: 2))); }
                        } catch (e) {
                          Navigator.of(dialogContext).pop();
                          if (context.mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red)); }
                        }
                      } else {
                        Navigator.of(dialogContext).pop();
                      }
                    },
                  ),
                ],
              );
            }
        );
      },
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, Note note) {
    final firestoreService = context.read<FirestoreService>();
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirmer la suppression'),
          content: const Text('Êtes-vous sûr de vouloir supprimer cette note définitivement ?'),
          actions: <Widget>[
            TextButton(child: const Text('Annuler'), onPressed: () { Navigator.of(dialogContext).pop(); },),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Supprimer'),
              onPressed: () async {
                try {
                  await firestoreService.deleteNote(note.id);
                  Navigator.of(dialogContext).pop();
                  if (context.mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note supprimée.'), duration: Duration(seconds: 2))); }
                } catch (e) {
                  Navigator.of(dialogContext).pop();
                  if (context.mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red)); }
                }
              },
            ),
          ],
        );
      },
    );
  }

  Color _safeParseColor(String hexString) {
    try {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('FF');
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (e) {
      return Colors.grey;
    }
  }

  Widget _buildNoteGridItem(BuildContext context, Note note, Palette? currentPalette) {
    ColorData? currentColorData;
    if (currentPalette != null) {
      try { currentColorData = currentPalette.colors.firstWhere((c) => c.paletteElementId == note.paletteElementId); }
      catch (e) { currentColorData = null; }
    }
    Color displayColor = currentColorData != null ? _safeParseColor(currentColorData.hexValue) : Colors.grey;
    bool isOrphan = currentColorData == null;

    final formattedDate = DateFormat('dd/MM HH:mm').format(note.eventTimestamp.toDate());
    final textColor = ThemeData.estimateBrightnessForColor(displayColor) == Brightness.dark ? Colors.white : Colors.black;

    return InkWell(
      onTap: () => _showEditNoteDialog(context, note, currentPalette),
      borderRadius: BorderRadius.circular(8.0),
      child: Card(
        color: displayColor,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (isOrphan) Tooltip(message: "ID Couleur: ${note.paletteElementId}", child: Icon(Icons.error_outline, size: 12, color: textColor.withOpacity(0.7))),
              Expanded(child: Text(note.comment, style: TextStyle(color: textColor, fontSize: 12), overflow: TextOverflow.ellipsis, maxLines: isOrphan ? 3 : 4)),
              Text(formattedDate, style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoteListItem(BuildContext context, Note note, Palette? currentPalette) {
    ColorData? currentColorData;
    if (currentPalette != null) {
      try { currentColorData = currentPalette.colors.firstWhere((c) => c.paletteElementId == note.paletteElementId); }
      catch (e) { currentColorData = null; }
    }
    Color displayColor = currentColorData != null ? _safeParseColor(currentColorData.hexValue) : Colors.grey;
    String displayTitle = currentColorData?.title ?? "ID: ${note.paletteElementId}";
    bool isOrphan = currentColorData == null;

    final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(note.eventTimestamp.toDate());

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: ListTile(
        leading: Container(width: 24, height: 24, color: displayColor),
        title: Text(note.comment),
        subtitle: Text(
          '${isOrphan ? "(ID Non Trouvé) " : ""}Titre: $displayTitle - $formattedDate',
          style: TextStyle(color: isOrphan ? Colors.red.shade800 : null),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.edit, size: 20), tooltip: 'Modifier la note', onPressed: () { _showEditNoteDialog(context, note, currentPalette); }),
            IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent), tooltip: 'Supprimer la note', onPressed: () { _showDeleteConfirmDialog(context, note); }),
          ],
        ),
        onTap: () => _showEditNoteDialog(context, note, currentPalette),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeJournalNotifier = context.watch<ActiveJournalNotifier>();
    final Journal? currentJournal = activeJournalNotifier.currentJournal;
    final String? journalId = currentJournal?.id;
    final Palette? currentPalette = currentJournal?.embeddedPaletteInstance;
    final firestoreService = context.read<FirestoreService>();

    String getCurrentTitleForNote(Note note) {
      if (currentPalette != null) {
        try { return currentPalette.colors.firstWhere((c) => c.paletteElementId == note.paletteElementId).title; }
        catch (e) { /* non trouvé */ }
      }
      return "zzz_ID Non Trouvé";
    }

    return Scaffold(
      appBar: const DynamicJournalAppBar(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: Icon(_groupByColor ? Icons.sort_by_alpha : Icons.calendar_today_outlined),
                  label: Text(_groupByColor ? 'Trier par couleur (titre)' : 'Trier par date'),
                  onPressed: () { setState(() { _groupByColor = !_groupByColor; }); },
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact, textStyle: Theme.of(context).textTheme.labelSmall),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(_isGridView ? Icons.view_list : Icons.view_module),
                  tooltip: _isGridView ? 'Affichage Liste' : 'Affichage Grille',
                  onPressed: () { setState(() { _isGridView = !_isGridView; }); },
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(_currentSortOrder == SortOrder.descending ? Icons.arrow_downward : Icons.arrow_upward),
                  tooltip: _currentSortOrder == SortOrder.descending ? 'Ordre décroissant' : 'Ordre croissant',
                  onPressed: () { setState(() { _currentSortOrder = _currentSortOrder == SortOrder.descending ? SortOrder.ascending : SortOrder.descending; }); },
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
          Expanded(
            child: journalId == null
                ? const Center(child: Text('Sélectionnez un journal pour voir les notes.'))
                : StreamBuilder<List<Note>>(
              stream: firestoreService.getJournalNotesStream(journalId, descending: _currentSortOrder == SortOrder.descending),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) { return const Center(child: CircularProgressIndicator()); }
                if (snapshot.hasError) { return Center(child: Text('Erreur chargement des notes: ${snapshot.error}')); }
                if (!snapshot.hasData || snapshot.data!.isEmpty) { return const Center(child: Text('Aucune note dans ce journal.')); }

                List<Note> notes = snapshot.data!;

                if (_groupByColor) {
                  notes = List<Note>.from(notes);
                  notes.sort((a, b) {
                    String titleA = getCurrentTitleForNote(a);
                    String titleB = getCurrentTitleForNote(b);
                    int titleCompare = titleA.toLowerCase().compareTo(titleB.toLowerCase());
                    if (titleCompare != 0) return titleCompare;
                    return (_currentSortOrder == SortOrder.descending)
                        ? b.eventTimestamp.compareTo(a.eventTimestamp)
                        : a.eventTimestamp.compareTo(b.eventTimestamp);
                  });
                }

                if (_isGridView) {
                  return GridView.builder(
                    padding: const EdgeInsets.all(8.0),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 130.0, childAspectRatio: 0.9, crossAxisSpacing: 8.0, mainAxisSpacing: 8.0),
                    itemCount: notes.length,
                    itemBuilder: (context, index) => _buildNoteGridItem(context, notes[index], currentPalette),
                  );
                } else {
                  return ListView.builder(
                    itemCount: notes.length,
                    itemBuilder: (context, index) => _buildNoteListItem(context, notes[index], currentPalette),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
