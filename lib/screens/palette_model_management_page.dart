import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/palette_model.dart';
import '../models/color_data.dart';
import '../core/predefined_templates.dart'; // Provides staticPredefinedPalettes
import 'unified_palette_editor_page.dart'; // For editing/creating palette models

/// Logger instance for this page.
final _loggerPage = Logger(printer: PrettyPrinter(methodCount: 0));

/// A screen for managing palette models.
///
/// This page displays a list of both predefined and user-created [PaletteModel]s.
/// Users can:
/// - View all available palette models.
/// - Create new personal palette models.
/// - Edit their personal palette models.
/// - Delete their personal palette models (predefined models cannot be deleted).
/// Navigation to [UnifiedPaletteEditorPage] is used for creating or editing models.
class PaletteModelManagementPage extends StatelessWidget {
  /// Creates an instance of [PaletteModelManagementPage].
  const PaletteModelManagementPage({super.key});

  /// Builds a widget that displays small preview squares for a list of colors.
  ///
  /// [colors] The list of [ColorData] to display previews for.
  /// [context] The build context.
  /// Returns a [Widget] (typically a [Wrap] of colored containers) or an empty [SizedBox]
  /// if the [colors] list is empty.
  Widget _buildColorPreviews(List<ColorData> colors, BuildContext context) {
    if (colors.isEmpty) {
      return const SizedBox.shrink(); // Return an empty widget if there are no colors
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Wrap(
        spacing: 4.0, // Horizontal spacing between color previews
        runSpacing: 4.0, // Vertical spacing between lines of color previews
        children: colors.map((colorData) {
          return Container(
            width: 20.0,
            height: 20.0,
            decoration: BoxDecoration(
              color: colorData.color, // The actual color
              borderRadius: BorderRadius.circular(4.0),
              border: Border.all(
                color: Theme.of(context).dividerColor.withOpacity(0.5), // Subtle border
                width: 0.5,
              ),
            ),
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
      // Display an error message if the user is not authenticated.
      return Scaffold(
          appBar: AppBar(title: const Text('Gérer les Modèles de Palette')), // UI Text in French
          body: const Center(child: Text("Utilisateur non connecté.")) // UI Text in French
      );
    }

    // Load predefined palette models (static list).
    final List<PaletteModel> staticPredefinedPalettes = predefinedPalettes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modèles de Palette'), // UI Text in French
        actions: [
          // Button to navigate to the creation page for a new palette model.
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: "Créer un nouveau modèle personnel", // UI Text in French
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const UnifiedPaletteEditorPage()) // No model passed, so it's for creation
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<PaletteModel>>(
        // Stream user-specific palette models from Firestore.
        stream: firestoreService.getUserPaletteModelsStream(currentUserId),
        builder: (context, userModelsSnapshot) {
          if (userModelsSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (userModelsSnapshot.hasError) {
            _loggerPage.e("Erreur chargement modèles utilisateur: ${userModelsSnapshot.error}");
            return const Center(child: Text('Erreur de chargement des modèles personnels.')); // UI Text in French
          }

          final List<PaletteModel> userModels = userModelsSnapshot.data ?? [];
          // Combine user models with predefined models for display.
          final List<PaletteModel> allModels = [...userModels, ...staticPredefinedPalettes];

          if (allModels.isEmpty) {
            // Display a message if no palette models are available.
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.palette_outlined, size: 60, color: Theme.of(context).colorScheme.secondary),
                    const SizedBox(height: 16),
                    Text('Aucun modèle de palette disponible.', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center), // UI Text in French
                    const SizedBox(height: 8),
                    const Text('Créez votre premier modèle personnel en appuyant sur le bouton "+" en haut.', textAlign: TextAlign.center), // UI Text in French
                  ],
                ),
              ),
            );
          }

          // Display the list of all palette models.
          return ListView.builder(
            itemCount: allModels.length,
            itemBuilder: (context, index) {
              final model = allModels[index];
              final bool isEditable = !model.isPredefined; // Predefined models are not editable/deletable by user.

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                            // UI Text in French, e.g., "5 couleurs (Personnel)"
                            "${model.colors.length} couleur${model.colors.length > 1 ? 's' : ''} ${model.isPredefined ? '(Prédéfini)' : '(Personnel)'}",
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        trailing: isEditable
                            ? Row( // Action buttons for editable (user-created) models.
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: "Modifier le modèle", // UI Text in French
                              onPressed: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => UnifiedPaletteEditorPage(paletteModelToEdit: model))
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_forever_outlined, color: Colors.redAccent),
                              tooltip: "Supprimer le modèle", // UI Text in French
                              onPressed: () => _confirmDeleteModel(context, firestoreService, model),
                            ),
                          ],
                        )
                            : null, // No actions for predefined models.
                        onTap: isEditable // Allow tapping to edit only for user models.
                            ? () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => UnifiedPaletteEditorPage(paletteModelToEdit: model))
                          );
                        }
                            : null,
                      ),
                      // Display color previews for the model.
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

  /// Shows a confirmation dialog and deletes a user-created [PaletteModel] if confirmed.
  ///
  /// Predefined models cannot be deleted.
  ///
  /// [context] The build context for showing the dialog.
  /// [firestoreService] The service to handle Firestore operations.
  /// [modelToDelete] The [PaletteModel] to be deleted.
  Future<void> _confirmDeleteModel(BuildContext context, FirestoreService firestoreService, PaletteModel modelToDelete) async {
    if (modelToDelete.isPredefined) {
      // Predefined models are protected from deletion.
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Les modèles prédéfinis ne peuvent pas être supprimés.'))); // UI Text in French
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Supprimer le Modèle ?'), // UI Text in French
          content: Text('Voulez-vous vraiment supprimer le modèle de palette "${modelToDelete.name}" ? Cette action est irréversible.'), // UI Text in French
          actions: <Widget>[
            TextButton(child: const Text('Annuler'), onPressed: () => Navigator.of(dialogContext).pop(false)), // UI Text in French
            TextButton(style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Supprimer'), onPressed: () => Navigator.of(dialogContext).pop(true)), // UI Text in French
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await firestoreService.deletePaletteModel(modelToDelete.id);
        _loggerPage.i("Modèle ${modelToDelete.name} supprimé.");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Modèle "${modelToDelete.name}" supprimé.'))); // UI Text in French
        }
      } catch (e) {
        _loggerPage.e("Erreur suppression modèle: $e");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur de suppression: ${e.toString()}'))); // UI Text in French
        }
      }
    }
  }
}
