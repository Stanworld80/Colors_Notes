import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../providers/active_agenda_provider.dart';
import '../models/agenda.dart';
import '../models/color_data.dart';
import '../models/note.dart';


class LoggedHomepage extends StatefulWidget {
  const LoggedHomepage({Key? key}) : super(key: key);

  @override
  State<LoggedHomepage> createState() => _LoggedHomepageState();
}

class _LoggedHomepageState extends State<LoggedHomepage> {
  bool _isLoadingAgenda = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.read<ActiveAgendaNotifier>().activeAgendaId == null) {
        _loadInitialAgenda();
      } else {
        if (mounted) {
          setState(() {
            _isLoadingAgenda = false;
          });
        }
      }
    });
  }

  Future<void> _loadInitialAgenda() async {
    final firestoreService = context.read<FirestoreService>();
    final activeAgendaNotifier = context.read<ActiveAgendaNotifier>();
    final user = context.read<User?>();

    if (user != null) {
      try {
        List<Agenda> userAgendas =
        await firestoreService.getUserAgendasStream(user.uid).first;

        Agenda? initialAgenda;
        if (userAgendas.isNotEmpty) {
          initialAgenda = userAgendas.first; // Prend le premier pour l'instant
        }

        if (mounted) {
          activeAgendaNotifier.setActiveAgenda(initialAgenda);
        }
      } catch (e) {
        print("Error loading initial agenda: $e");
        if (mounted) {
          activeAgendaNotifier.setActiveAgenda(null);
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoadingAgenda = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoadingAgenda = false;
        });
        activeAgendaNotifier.setActiveAgenda(null);
      }
    }
  }

  Future<void> _signOut(BuildContext context) async {
    final authService = context.read<AuthService>();
    final activeAgendaNotifier = context.read<ActiveAgendaNotifier>();
    try {
      await authService.signOut();
      activeAgendaNotifier.setActiveAgenda(null);
    } catch (e) {
      print("Error signing out: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e')),
        );
      }
    }
  }

  void _showCreateNoteDialog(BuildContext context, ColorData colorData, String agendaId) {
    final TextEditingController commentController = TextEditingController();
    final color = Color(int.parse(colorData.hexValue.replaceFirst('#', 'FF'), radix: 16));

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              Container(width: 20, height: 20, color: color),
              const SizedBox(width: 10),
              Expanded(child: Text('Note pour "${colorData.title}"', overflow: TextOverflow.ellipsis)),
            ],
          ),
          content: TextField(
            controller: commentController,
            autofocus: true,
            maxLength: 256,
            decoration: const InputDecoration(
              hintText: 'Entrez votre commentaire...',
              labelText: 'Commentaire',
            ),
            maxLines: 3,
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
                  final firestoreService = dialogContext.read<FirestoreService>();
                  final user = dialogContext.read<User?>();

                  if (user != null) {
                    final newNote = Note(
                      id: '',
                      agendaId: agendaId,
                      userId: user.uid,
                      colorSnapshot: colorData,
                      comment: comment,
                      createdAt: Timestamp.now(),
                      commentUpdatedAt: Timestamp.now(),
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
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final user = context.watch<User?>();
    final activeAgendaNotifier = context.watch<ActiveAgendaNotifier>();
    final Agenda? currentAgenda = activeAgendaNotifier.currentAgenda;
    final List<ColorData> currentColors = currentAgenda?.embeddedPaletteInstance.colors ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(_isLoadingAgenda ? 'Chargement...' : activeAgendaNotifier.activeAgendaName),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Déconnexion',
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: _isLoadingAgenda
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Welcome!', style: TextStyle(fontSize: 24)),
                  if (user != null)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'Logged in as: ${user.email}',
                        style: const TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ]),
          ),
          const SizedBox(height: 20),

          // --- Grille Palette ---
          if (currentAgenda == null && !_isLoadingAgenda)
            const Center(child: Text("Aucun agenda sélectionné.")),
          if (currentAgenda != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  crossAxisSpacing: 8.0,
                  mainAxisSpacing: 8.0,
                  childAspectRatio: 1.0,
                ),
                itemCount: currentColors.length,
                itemBuilder: (context, index) {
                  final colorData = currentColors[index];
                  final color = Color(int.parse(colorData.hexValue.replaceFirst('#', 'FF'), radix: 16));

                  return GestureDetector(
                    onTap: () {
                      _showCreateNoteDialog(context, colorData, currentAgenda.id);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: Colors.black54, width: 0.5),
                      ),
                      child: Center(
                        child: Text(
                          colorData.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: ThemeData.estimateBrightnessForColor(color) == Brightness.dark
                                ? Colors.white : Colors.black,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 20), // Espace en bas
        ],
      ),
    );
  }
}