import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/palette_model.dart';
import '../services/firestore_service.dart';
import 'edit_palette_model_page.dart';

class PaletteModelManagementPage extends StatelessWidget {
  const PaletteModelManagementPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();
    final userId = context.watch<User?>()?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Mes Modèles de Palettes')),
      body:
          userId == null
              ? const Center(child: Text("Veuillez vous connecter."))
              : StreamBuilder<List<PaletteModel>>(
                stream: firestoreService.getUserPaletteModelsStream(userId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    print("Error loading palette models: ${snapshot.error}");
                    return Center(child: Text('Erreur: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Padding(padding: EdgeInsets.all(16.0), child: Text('Aucun modèle de palette créé.\nCliquez sur "+" pour en ajouter un.', textAlign: TextAlign.center)),
                    );
                  }

                  final models = snapshot.data!;

                  return ListView.builder(
                    itemCount: models.length,
                    itemBuilder: (context, index) {
                      final model = models[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        child: ListTile(
                          leading: Wrap(
                            spacing: 2,
                            runSpacing: 2,
                            children: model.colors.take(4).map((c) => Container(width: 12, height: 12, color: _safeParseColor(c.hexValue), margin: const EdgeInsets.all(1))).toList(),
                          ),
                          title: Text(model.name),
                          subtitle: Text("${model.colors.length} couleurs"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                tooltip: 'Modifier',
                                onPressed: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => EditPaletteModelPage(existingPaletteModel: model))); // Mode édition
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                tooltip: 'Supprimer',
                                onPressed: () => _showDeletePaletteModelConfirmDialog(context, model, firestoreService),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        tooltip: "Nouvelle Palette Modèle",
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const EditPaletteModelPage()));
        },
      ),
    );
  }

  void _showDeletePaletteModelConfirmDialog(BuildContext context, PaletteModel model, FirestoreService firestoreService) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirmer la suppression'),
          content: Text('Supprimer le modèle "${model.name}" ?\n(N\'affecte pas les journals existants).'),
          actions: [
            TextButton(child: const Text('Annuler'), onPressed: () => Navigator.of(dialogContext).pop()),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Supprimer'),
              onPressed: () async {
                try {
                  // Utiliser dialogContext pour lire le service
                  final fs = dialogContext.read<FirestoreService>();
                  await fs.deletePaletteModel(model.id);
                  Navigator.of(dialogContext).pop();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Modèle supprimé.'), duration: Duration(seconds: 2)));
                  }
                } catch (e) {
                  print("Error deleting palette model: $e");
                  Navigator.of(dialogContext).pop();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
                  }
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
      return Color(int.parse(hexString.replaceFirst('#', 'FF'), radix: 16));
    } catch (e) {
      return Colors.grey; // Couleur par défaut en cas d'erreur
    }
  }
}
