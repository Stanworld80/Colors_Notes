import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/active_journal_provider.dart';
import '../services/firestore_service.dart';
import '../models/journal.dart';
import '../models/color_data.dart';
import '../models/note.dart';
import '../widgets/dynamic_journal_app_bar.dart';


class LoggedHomepage extends StatefulWidget {
  const LoggedHomepage({Key? key}) : super(key: key);

  @override
  State<LoggedHomepage> createState() => _LoggedHomepageState();
}

class _LoggedHomepageState extends State<LoggedHomepage> {
  bool _isLoadingJournal = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.read<ActiveJournalNotifier>().activeJournalId == null) {
        _loadInitialJournal();
      } else {
        if (mounted) {
          setState(() {
            _isLoadingJournal = false;
          });
        }
      }
    });
  }

  Future<void> _loadInitialJournal() async {
    if (!mounted) return;
    final firestoreService = context.read<FirestoreService>();
    final activeJournalNotifier = context.read<ActiveJournalNotifier>();
    final user = context.read<User?>();

    if (user != null) {
      try {
        List<Journal> userJournals = await firestoreService.getUserJournalsStream(user.uid).first;
        Journal? initialJournal;
        if (userJournals.isNotEmpty) {
          initialJournal = userJournals.first;
        }
        if (mounted) {
          activeJournalNotifier.setActiveJournal(initialJournal);
        }
      } catch (e) {
        print("Erreur chargement journal initial: $e");
        if (mounted) {
          activeJournalNotifier.setActiveJournal(null);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur chargement journals: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoadingJournal = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoadingJournal = false;
        });
        activeJournalNotifier.setActiveJournal(null);
      }
    }
  }

  void _showCreateNoteDialog(BuildContext context, ColorData colorData, String journalId) {
    final TextEditingController commentController = TextEditingController();
    Color color;
    try {
      color = Color(int.parse(colorData.hexValue.replaceFirst('#', 'FF'), radix: 16));
    } catch (e) {
      color = Colors.grey;
      print("Erreur parsing couleur pour dialog: ${colorData.hexValue} - ${e}");
    }
    final firestoreService = context.read<FirestoreService>();
    final user = context.read<User?>();

    DateTime selectedDateTime = DateTime.now();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
            builder: (stfContext, stfSetState) {
              Future<void> _selectDate() async {
                final DateTime? pickedDate = await showDatePicker(
                  context: stfContext,
                  initialDate: selectedDateTime,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2101),
                );
                if (pickedDate != null) {
                  final newDateTime = DateTime(
                    pickedDate.year,
                    pickedDate.month,
                    pickedDate.day,
                    selectedDateTime.hour,
                    selectedDateTime.minute,
                  );
                  stfSetState(() {
                    selectedDateTime = newDateTime;
                  });
                }
              }

              Future<void> _selectTime() async {
                final TimeOfDay? pickedTime = await showTimePicker(
                  context: stfContext,
                  initialTime: TimeOfDay.fromDateTime(selectedDateTime),
                );
                if (pickedTime != null) {
                  final newDateTime = DateTime(
                    selectedDateTime.year,
                    selectedDateTime.month,
                    selectedDateTime.day,
                    pickedTime.hour,
                    pickedTime.minute,
                  );
                  stfSetState(() {
                    selectedDateTime = newDateTime;
                  });
                }
              }

              return AlertDialog(
                title: Row(
                  children: [
                    Container(width: 20, height: 20, color: color),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Note pour "${colorData.title}"', overflow: TextOverflow.ellipsis)),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: commentController,
                        autofocus: true,
                        maxLength: 256,
                        decoration: const InputDecoration(
                          hintText: 'Entrez votre commentaire...',
                          labelText: 'Commentaire',
                        ),
                        maxLines: 3,
                        textInputAction: TextInputAction.newline,
                      ),
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
                              IconButton(
                                icon: const Icon(Icons.calendar_today, size: 20),
                                tooltip: 'Choisir la date',
                                onPressed: _selectDate,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 5),
                              IconButton(
                                icon: const Icon(Icons.access_time, size: 20),
                                tooltip: 'Choisir l\'heure',
                                onPressed: _selectTime,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          )
                        ],
                      ),
                    ],
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    child: const Text('Annuler'),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                  ElevatedButton(
                    child: const Text('Enregistrer'),
                    onPressed: () async {
                      final comment = commentController.text.trim();
                      if (comment.isNotEmpty) {
                        if (user != null) {
                          final newNote = Note(
                            id: '',
                            journalId: journalId,
                            userId: user.uid,
                            colorSnapshot: colorData,
                            comment: comment,
                            createdAt: Timestamp.now(),
                            eventTimestamp: Timestamp.fromDate(selectedDateTime),
                          );
                          try {
                            await firestoreService.createNote(newNote);
                            Navigator.of(dialogContext).pop();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Note enregistrée !'), duration: Duration(seconds: 2)),
                              );
                            }
                          } catch (e) {
                            print("Error saving note: $e");
                            Navigator.of(dialogContext).pop();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        } else {
                          Navigator.of(dialogContext).pop();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Erreur: Utilisateur déconnecté.'), backgroundColor: Colors.red),
                            );
                          }
                        }
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


  @override
  Widget build(BuildContext context) {
    final activeJournalNotifier = context.watch<ActiveJournalNotifier>();
    final Journal? currentJournal = activeJournalNotifier.currentJournal;
    final List<ColorData> currentColors = currentJournal?.embeddedPaletteInstance.colors ?? [];

    return Scaffold(
      appBar: const DynamicJournalAppBar(),
      body: _isLoadingJournal
          ? const Center(child: CircularProgressIndicator())
          : (currentJournal == null
          ? const Center(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Text(
                "Aucun journal sélectionné ou trouvé.\n\nAllez dans l'onglet 'Journals' pour en créer ou en sélectionner un.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey)),
          ))
          : ListView(
        padding: const EdgeInsets.only(bottom: 80),
        children: <Widget>[
          if (currentColors.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 40.0),
              child: Center(
                child: Text(
                    'Cette palette est vide.\nModifiez-la en cliquant sur l\'icône 🖌️\nen haut à droite.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey[600])
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 100.0,
                  crossAxisSpacing: 10.0,
                  mainAxisSpacing: 10.0,
                  childAspectRatio: 1.1,
                ),
                itemCount: currentColors.length,
                itemBuilder: (context, index) {
                  final colorData = currentColors[index];
                  Color color;
                  try {
                    color = Color(int.parse(colorData.hexValue.replaceFirst('#', 'FF'), radix: 16));
                  } catch (e) {
                    color = Colors.grey;
                    print("Erreur parsing couleur grille: ${colorData.hexValue} - ${e}");
                  }

                  return InkWell(
                    onTap: () {
                      _showCreateNoteDialog(context, colorData, currentJournal.id);
                    },
                    borderRadius: BorderRadius.circular(8.0),
                    child: Container(
                      decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(color: Colors.black38, width: 0.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.3),
                              spreadRadius: 1,
                              blurRadius: 3,
                              offset: const Offset(1, 1),
                            )
                          ]
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Text(
                            colorData.title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: ThemeData.estimateBrightnessForColor(color) == Brightness.dark
                                  ? Colors.white : Colors.black,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      )),
    );
  }
}
