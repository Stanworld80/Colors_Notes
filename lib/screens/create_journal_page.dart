import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:colors_notes/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../core/app_constants.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/journal.dart';
import '../models/palette_model.dart';
import '../providers/active_journal_provider.dart';
import '../widgets/inline_palette_editor.dart';
import '../viewmodels/create_journal_view_model.dart';

class CreateJournalPage extends StatelessWidget {
  const CreateJournalPage({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.uid;

    if (userId == null) {
      return const Scaffold(
        body: Center(child: Text("User not authenticated")),
      );
    }

    return ChangeNotifierProvider(
      create: (_) => CreateJournalViewModel(firestoreService, userId),
      child: const _CreateJournalContent(),
    );
  }
}

class _CreateJournalContent extends StatefulWidget {
  const _CreateJournalContent();

  @override
  __CreateJournalContentState createState() => __CreateJournalContentState();
}

class __CreateJournalContentState extends State<_CreateJournalContent> {
  final _formKey = GlobalKey<FormState>();
  final _journalNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _journalNameController.addListener(_onNameChanged);
  }

  void _onNameChanged() {
    final viewModel = Provider.of<CreateJournalViewModel>(context, listen: false);
    viewModel.setJournalName(_journalNameController.text.trim(), AppLocalizations.of(context)!);
  }

  @override
  void dispose() {
    _journalNameController.removeListener(_onNameChanged);
    _journalNameController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateJournal(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;

    final viewModel = Provider.of<CreateJournalViewModel>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;
    final activeJournalNotifier = Provider.of<ActiveJournalNotifier>(context, listen: false);

    final newJournal = await viewModel.createJournal(
      journalName: _journalNameController.text.trim(),
      l10n: l10n,
    );

    if (newJournal != null) {
      // Success
      if (mounted) {
        await activeJournalNotifier.setActiveJournal(newJournal.id, newJournal.userId);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.journalCreatedSuccess(newJournal.name))));
        Navigator.of(context).pop();
      }
    } else if (viewModel.errorMessage != null) {
      // Error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(viewModel.errorMessage!)));
      }
    }
  }

  Future<bool> _handleDeleteAllColors(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(l10n.emptyPaletteDialogTitle),
          content: Text(l10n.emptyPaletteDialogContent),
          actions: <Widget>[
            TextButton(child: Text(l10n.cancelButtonLabel), onPressed: () => Navigator.of(dialogContext).pop(false)),
            TextButton(style: TextButton.styleFrom(foregroundColor: Colors.red), child: Text(l10n.emptyButtonLabel), onPressed: () => Navigator.of(dialogContext).pop(true)),
          ],
        );
      },
    );
    return confirm ?? false;
  }

  Widget _buildStepIndicator(BuildContext context, String stepNumber, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          CircleAvatar(
              radius: 14,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(stepNumber, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
          ),
          const SizedBox(width: 12),
          Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final viewModel = Provider.of<CreateJournalViewModel>(context);

    // Initial check for loading error or user issues
    // Using addPostFrameCallback to avoid build-time snackbars if immediate error
    if (viewModel.errorMessage != null && !viewModel.isLoading && viewModel.creationMode == JournalCreationMode.emptyPalette) {
         // This might trigger on verify failures too? 
         // Actually viewModel.errorMessage is set on createJournal failure too. 
         // We handle createJournal failure in _handleCreateJournal. 
         // But _loadInitialData could fail.
         // If _availablePaletteModels is empty, it's not an error but a state.
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.createJournalPageTitle)),
      body: viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Card(
                elevation: 2.0,
                margin: const EdgeInsets.only(bottom: 20.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStepIndicator(context, "1", l10n.step1JournalName),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _journalNameController,
                        decoration: InputDecoration(
                          labelText: l10n.journalNameTextFieldLabel,
                          hintText: l10n.journalNameTextFieldHint,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                          prefixIcon: const Icon(Icons.drive_file_rename_outline),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return l10n.journalNameValidatorEmpty;
                          }
                          if (value.length > 70) {
                            return l10n.journalNameValidatorTooLong;
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),

              Card(
                elevation: 2.0,
                margin: const EdgeInsets.only(bottom: 20.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStepIndicator(context, "2", l10n.step2PaletteConfiguration),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<PaletteSourceType>(
                        value: viewModel.selectedSourceType,
                        decoration: InputDecoration(
                            labelText: l10n.paletteSourceDropdownLabel,
                            border: const OutlineInputBorder()
                        ),
                        items: [
                          DropdownMenuItem(value: PaletteSourceType.empty, child: Text(l10n.paletteSourceEmptyOption)),
                          DropdownMenuItem(value: PaletteSourceType.model, child: Text(l10n.paletteSourceModelOption)),
                          DropdownMenuItem(value: PaletteSourceType.existingJournal, child: Text(l10n.paletteSourceExistingJournalOption)),
                        ],
                        onChanged: (PaletteSourceType? newValue) {
                          if (newValue != null) {
                            viewModel.setSourceType(newValue, l10n);
                          }
                        },
                      ),
                      const SizedBox(height: 15),
                      if (viewModel.creationMode == JournalCreationMode.fromPaletteModel)
                        viewModel.availablePaletteModels.isEmpty
                         ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(l10n.noPaletteModelsAvailableMessage, style: TextStyle(color: Colors.orange.shade700))
                           )
                         : DropdownButtonFormField<PaletteModel>(
                              value: viewModel.selectedPaletteModel,
                              items: viewModel.availablePaletteModels.map((PaletteModel model) {
                                return DropdownMenuItem<PaletteModel>(
                                  value: model,
                                  child: Text(model.name + (model.isPredefined ? l10n.paletteModelSuffixPredefined : l10n.paletteModelSuffixPersonal)),
                                );
                              }).toList(),
                              onChanged: (PaletteModel? newValue) {
                                viewModel.setSelectedPaletteModel(newValue, l10n);
                              },
                              decoration: InputDecoration(labelText: l10n.choosePaletteModelDropdownLabel),
                              validator: (value) => viewModel.creationMode == JournalCreationMode.fromPaletteModel && value == null ? l10n.pleaseChooseModelValidator : null,
                            ),

                      if (viewModel.creationMode == JournalCreationMode.fromExistingJournal)
                        viewModel.availableUserJournals.isEmpty
                        ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(l10n.noExistingJournalsToCopy, style: TextStyle(color: Colors.orange.shade700))
                          )
                        : DropdownButtonFormField<Journal>(
                              value: viewModel.selectedExistingJournal,
                              items: viewModel.availableUserJournals.map((Journal journal) {
                                return DropdownMenuItem<Journal>(
                                  value: journal,
                                  child: Text(journal.name),
                                );
                              }).toList(),
                              onChanged: (Journal? newValue) {
                                viewModel.setSelectedExistingJournal(newValue, l10n);
                              },
                              decoration: InputDecoration(labelText: l10n.copyPaletteFromJournalDropdownLabel),
                              validator: (value) => viewModel.creationMode == JournalCreationMode.fromExistingJournal && value == null ? l10n.pleaseChooseJournalValidator : null,
                            ),

                      const SizedBox(height: 10),
                      InlinePaletteEditorWidget(
                        key: viewModel.paletteEditorKey,
                        initialPaletteName: viewModel.preparedPaletteName,
                        initialColors: viewModel.preparedColors,
                        onPaletteNameChanged: (newName) {
                           viewModel.setPreparedPaletteName(newName);
                        },
                        onColorsChanged: (newColors) {
                           viewModel.setPreparedColors(newColors);
                        },
                        showNameEditor: false,
                        isEditingJournalPalette: false,
                        onDeleteAllColorsRequested: () => _handleDeleteAllColors(context),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add_circle_outline),
                  label: Text(l10n.createJournalButtonLabel),
                  onPressed: viewModel.isLoading ? null : () => _handleCreateJournal(context),
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      textStyle: const TextStyle(fontSize: 16)
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
