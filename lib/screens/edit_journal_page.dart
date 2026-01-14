// fichier: lib/screens/edit_journal_page.dart
import 'dart:async';

import 'package:colors_notes/l10n/app_localizations.dart';
import 'package:colors_notes/models/journal.dart';
import 'package:colors_notes/services/firestore_service.dart';
import 'package:colors_notes/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class EditJournalPage extends StatefulWidget {
  final Journal journal;

  const EditJournalPage({super.key, required this.journal});

  @override
  State<EditJournalPage> createState() => _EditJournalPageState();
}

class _EditJournalPageState extends State<EditJournalPage> {
  late TextEditingController _nameController;
  late bool _notificationsEnabled;
  late TextEditingController _notificationPhraseController;
  late List<bool> _notificationDays;
  late List<TimeOfDay> _notificationTimes;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.journal.name);
    _notificationsEnabled = widget.journal.notificationsEnabled;
    _notificationPhraseController =
        TextEditingController(text: widget.journal.notificationPhrase);
    _notificationDays = List.from(widget.journal.notificationDays);
    _notificationTimes = widget.journal.notificationTimes
        .map((timeStr) => TimeOfDay(
              hour: int.parse(timeStr.split(':')[0]),
              minute: int.parse(timeStr.split(':')[1]),
            ))
        .toList();
  }

  Future<void> _saveJournal() async {
    if (_formKey.currentState!.validate()) {
      final firestoreService =
          Provider.of<FirestoreService>(context, listen: false);
      final notificationService =
          Provider.of<NotificationService>(context, listen: false);

      final updatedJournal = widget.journal.copyWith(
        name: _nameController.text,
        notificationsEnabled: _notificationsEnabled,
        notificationPhrase: _notificationPhraseController.text,
        notificationDays: _notificationDays,
        notificationTimes: _notificationTimes
            .map((time) => '${time.hour}:${time.minute}')
            .toList(),
      );

      await firestoreService.updateJournal(updatedJournal);

      // Schedule or cancel notifications
      if (updatedJournal.notificationsEnabled) {
        await notificationService.scheduleJournalNotifications(updatedJournal);
      } else {
        await notificationService.cancelJournalNotifications(updatedJournal.id);
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  void _addNotificationTime() {
    if (_notificationTimes.length < 12) {
      setState(() {
        _notificationTimes.add(const TimeOfDay(hour: 8, minute: 0));
      });
    }
  }

  void _removeNotificationTime(int index) {
    setState(() {
      _notificationTimes.removeAt(index);
    });
  }

  void _selectAllDays() {
    setState(() {
      for (int i = 0; i < _notificationDays.length; i++) {
        _notificationDays[i] = true;
      }
    });
  }

  Future<void> _selectTime(BuildContext context, int index) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _notificationTimes[index],
    );
    if (picked != null && picked != _notificationTimes[index]) {
      setState(() {
        _notificationTimes[index] = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.editJournalTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveJournal,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: localizations.journalNameLabel,
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return localizations.journalNameValidator;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Text(
                localizations.notificationsTitle,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              SwitchListTile(
                title: Text(localizations.enableNotificationsLabel),
                value: _notificationsEnabled,
                onChanged: (bool value) {
                  setState(() {
                    _notificationsEnabled = value;
                  });
                },
              ),
              if (_notificationsEnabled) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notificationPhraseController,
                  decoration: InputDecoration(
                    labelText: localizations.notificationPhraseLabel,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (_notificationsEnabled &&
                        (value == null || value.isEmpty)) {
                      return localizations.notificationPhraseValidator;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      localizations.notificationDaysLabel,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    TextButton(
                      onPressed: _selectAllDays,
                      child: Text(localizations.selectAllButton),
                    )
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8.0,
                  children: List.generate(7, (index) {
                    return FilterChip(
                      label: Text(localizations.daysOfWeek.split(',')[index]),
                      selected: _notificationDays[index],
                      onSelected: (bool selected) {
                        setState(() {
                          _notificationDays[index] = selected;
                        });
                      },
                    );
                  }),
                ),
                const SizedBox(height: 24),
                Text(
                  localizations.notificationTimesLabel,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                ..._notificationTimes.asMap().entries.map((entry) {
                  int index = entry.key;
                  TimeOfDay time = entry.value;
                  return ListTile(
                    title: Text(time.format(context)),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () => _removeNotificationTime(index),
                    ),
                    onTap: () => _selectTime(context, index),
                  );
                }),
                if (_notificationTimes.length < 12)
                  Center(
                    child: IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: _addNotificationTime,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}