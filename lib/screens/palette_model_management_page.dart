import 'package:colors_notes/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

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
    final l10n = AppLocalizations.of(context)!;
    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final String? currentUserId = authService.currentUser?.uid;

    if (currentUserId == null) {
      _loggerPage.w("PaletteModelManagementPage: currentUserId is null."); // Log in English
      return Scaffold(
          appBar: AppBar(title: Text(l10n.managePaletteModelsAppBarTitle)),
          body: Center(child: Text(l10n.userNotConnectedError))
      );
    }

    final List<PaletteModel> staticPredefinedPalettes = predefinedPalettes;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.paletteModelsAppBarTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: l10n.createNewPersonalModelTooltip,
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const UnifiedPaletteEditorPage())
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<PaletteModel>>(
        stream: firestoreService.getUserPaletteModelsStream(currentUserId),
        builder: (context, userModelsSnapshot) {
          if (userModelsSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (userModelsSnapshot.hasError) {
            _loggerPage.e("Error loading user models: ${userModelsSnapshot.error}"); // Log in English
            return Center(child: Text(l10n.errorLoadingPersonalModels));
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
                    const SizedBox(height: 16),
                    Text(l10n.noPaletteModelsAvailableMessage, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(l10n.createFirstModelMessage, textAlign: TextAlign.center),
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
              final String modelTypeSuffix = model.isPredefined ? l10n.paletteModelSuffixPredefined : l10n.paletteModelSuffixPersonal;
              final String pluralS = model.colors.length == 1 ? "" : "s"; // Basic pluralization for 'color(s)'

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
                            l10n.paletteModelInfo(model.colors.length, pluralS, modelTypeSuffix),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        trailing: isEditable
                            ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: l10n.editModelTooltip,
                              onPressed: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => UnifiedPaletteEditorPage(paletteModelToEdit: model))
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_forever_outlined, color: Colors.redAccent),
                              tooltip: l10n.deleteModelTooltip,
                              onPressed: () => _confirmDeleteModel(context, firestoreService, model, l10n),
                            ),
                          ],
                        )
                            : null,
                        onTap: isEditable
                            ? () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => UnifiedPaletteEditorPage(paletteModelToEdit: model))
                          );
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

  /// Shows a confirmation dialog and deletes a user-created [PaletteModel] if confirmed.
  Future<void> _confirmDeleteModel(BuildContext context, FirestoreService firestoreService, PaletteModel modelToDelete, AppLocalizations l10n) async {
    if (modelToDelete.isPredefined) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.predefinedModelsCannotBeDeletedSnackbar)));
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(l10n.deleteModelDialogTitle),
          content: Text(l10n.deleteModelDialogContent(modelToDelete.name)),
          actions: <Widget>[
            TextButton(child: Text(l10n.cancelButtonLabel), onPressed: () => Navigator.of(dialogContext).pop(false)),
            TextButton(style: TextButton.styleFrom(foregroundColor: Colors.red), child: Text(l10n.deleteButtonLabel), onPressed: () => Navigator.of(dialogContext).pop(true)),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await firestoreService.deletePaletteModel(modelToDelete.id);
        _loggerPage.i("Model ${modelToDelete.name} deleted."); // Log in English
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.modelDeletedSnackbar(modelToDelete.name))));
        }
      } catch (e) {
        _loggerPage.e("Error deleting model: $e"); // Log in English
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.errorDeletingModelSnackbar(e.toString()))));
        }
      }
    }
  }
}
