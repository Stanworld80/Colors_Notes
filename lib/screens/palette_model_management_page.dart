import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/palette_model.dart';
import '../models/color_data.dart';
import '../core/predefined_templates.dart';
import 'unified_palette_editor_page.dart';

final _loggerPage = Logger(printer: PrettyPrinter(methodCount: 0));

class PaletteModelManagementPage extends StatelessWidget {
  PaletteModelManagementPage({Key? key}) : super(key: key);

  Widget _buildColorPreviews(List<ColorData> colors, BuildContext context) {
    if (colors.isEmpty) {
      return SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Wrap(
        spacing: 4.0,
        runSpacing: 4.0,
        children:
            colors.map((colorData) {
              return Container(
                width: 20.0,
                height: 20.0,
                decoration: BoxDecoration(color: colorData.color, borderRadius: BorderRadius.circular(4.0), border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.5), width: 0.5)),
              );
            }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final String? currentUserId = authService.currentUser?.uid;

    if (currentUserId == null) {
      _loggerPage.w("PaletteModelManagementPage: currentUserId est null.");
      return Scaffold(appBar: AppBar(title: Text('Gérer les Modèles de Palette')), body: Center(child: Text("Utilisateur non connecté.")));
    }

    final List<PaletteModel> staticPredefinedPalettes = predefinedPalettes;

    return Scaffold(
      appBar: AppBar(
        title: Text('Modèles de Palette'),
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle_outline),
            tooltip: "Créer un nouveau modèle personnel",
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => UnifiedPaletteEditorPage()));
            },
          ),
        ],
      ),
      body: StreamBuilder<List<PaletteModel>>(
        stream: firestoreService.getUserPaletteModelsStream(currentUserId),
        builder: (context, userModelsSnapshot) {
          if (userModelsSnapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (userModelsSnapshot.hasError) {
            _loggerPage.e("Erreur chargement modèles utilisateur: ${userModelsSnapshot.error}");
            return Center(child: Text('Erreur de chargement des modèles personnels.'));
          }

          final List<PaletteModel> userModels = userModelsSnapshot.data ?? [];

          final List<PaletteModel> allModels = [...userModels, ...staticPredefinedPalettes];

          if (allModels.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.palette_outlined, size: 60, color: Theme.of(context).colorScheme.secondary),
                    SizedBox(height: 16),
                    Text('Aucun modèle de palette disponible.', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                    SizedBox(height: 8),
                    Text('Créez votre premier modèle personnel en appuyant sur le bouton "+" en haut.', textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            itemCount: allModels.length,
            itemBuilder: (context, index) {
              final model = allModels[index];
              final bool isEditable = !model.isPredefined;

              return Card(
                margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(model.name, style: Theme.of(context).textTheme.titleMedium),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            "${model.colors.length} couleur${model.colors.length > 1 ? 's' : ''} ${model.isPredefined ? '(Prédéfini)' : '(Personnel)'}",
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),

                        trailing:
                            isEditable
                                ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.edit_outlined),
                                      tooltip: "Modifier le modèle",
                                      onPressed: () {
                                        Navigator.push(context, MaterialPageRoute(builder: (context) => UnifiedPaletteEditorPage(paletteModelToEdit: model)));
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete_forever_outlined, color: Colors.redAccent),
                                      tooltip: "Supprimer le modèle",
                                      onPressed: () => _confirmDeleteModel(context, firestoreService, model),
                                    ),
                                  ],
                                )
                                : null,
                        onTap:
                            isEditable
                                ? () {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => UnifiedPaletteEditorPage(paletteModelToEdit: model)));
                                }
                                : null,
                      ),

                      _buildColorPreviews(model.colors, context),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmDeleteModel(BuildContext context, FirestoreService firestoreService, PaletteModel modelToDelete) async {
    if (modelToDelete.isPredefined) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Les modèles prédéfinis ne peuvent pas être supprimés.')));
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Supprimer le Modèle ?'),
          content: Text('Voulez-vous vraiment supprimer le modèle de palette "${modelToDelete.name}" ? Cette action est irréversible.'),
          actions: <Widget>[
            TextButton(child: Text('Annuler'), onPressed: () => Navigator.of(dialogContext).pop(false)),
            TextButton(style: TextButton.styleFrom(foregroundColor: Colors.red), child: Text('Supprimer'), onPressed: () => Navigator.of(dialogContext).pop(true)),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await firestoreService.deletePaletteModel(modelToDelete.id);
        _loggerPage.i("Modèle ${modelToDelete.name} supprimé.");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Modèle "${modelToDelete.name}" supprimé.')));
        }
      } catch (e) {
        _loggerPage.e("Erreur suppression modèle: $e");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur de suppression: ${e.toString()}')));
        }
      }
    }
  }
}
