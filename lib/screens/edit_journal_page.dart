import 'dart:async';
import 'dart:io';

import 'package:colors_notes/l10n/app_localizations.dart';
import 'package:colors_notes/models/journal.dart';
import 'package:colors_notes/services/firestore_service.dart';
import 'package:colors_notes/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

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
  bool _isXiaomi = false;

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

    _checkXiaomi();
  }

  Future<void> _checkXiaomi() async {
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      // Check for common Xiaomi identifiers
      if (androidInfo.manufacturer.toLowerCase().contains('xiaomi') ||
          androidInfo.brand.toLowerCase().contains('xiaomi') ||
          androidInfo.brand.toLowerCase().contains('redmi') ||
          androidInfo.brand.toLowerCase().contains('poco')) {
        setState(() {
          _isXiaomi = true;
        });
      }
    }
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
              if (_isXiaomi)
                Card(
                  color: Colors.orange.shade50,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Xiaomi / Redmi / HyperOS Setup:",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.deepOrange),
                        ),
                        const SizedBox(height: 8),
                        const Text("1. Tap 'Open Settings' below.",
                            style: TextStyle(fontSize: 13)),
                        const Text(
                            "2. Find 'Battery Saver' -> Select 'No restrictions'.",
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold)),
                        const Text("3. Find 'Autostart' and turn it ON.",
                            style: TextStyle(fontSize: 13)),
                        const Text(
                            "4. If missing, look in 'Other permissions' -> 'Start in background'.",
                            style: TextStyle(fontSize: 13)),
                        TextButton(
                          onPressed: () async {
                            // We can't link directly to autostart, but we can open settings
                            await openAppSettings();
                          },
                          child: const Text("Open Settings"),
                        )
                      ],
                    ),
                  ),
                ),
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
                onChanged: (bool value) async {
                  if (value) {
                    final notificationService =
                        Provider.of<NotificationService>(context,
                            listen: false);
                    final granted =
                        await notificationService.requestPermissions();
                    if (granted) {
                      setState(() {
                        _notificationsEnabled = true;
                      });
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text("Permission required for notifications"),
                          ),
                        );
                      }
                      setState(() {
                        _notificationsEnabled = false;
                      });
                    }
                  } else {
                    setState(() {
                      _notificationsEnabled = false;
                    });
                  }
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
                const SizedBox(height: 24),
                // --- TEST BUTTON START ---
                Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.notifications_active),
                    label: const Text("Test: Notify in 10s"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amberAccent,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () async {
                      if (!_notificationsEnabled) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text("Enable notifications switch first!")),
                        );
                        return;
                      }
                      final notificationService =
                          Provider.of<NotificationService>(context,
                              listen: false);

                      // Request permission just in case
                      await notificationService.requestPermissions();

                      // Schedule query
                      try {
                        final scheduleInfo = await notificationService
                            .scheduleTestNotification();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Success! $scheduleInfo")),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text("Error: $e"),
                                backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.notifications),
                    label: const Text("Test: Immediate"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () async {
                      if (!_notificationsEnabled) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text("Enable notifications switch first!")),
                        );
                        return;
                      }
                      final notificationService =
                          Provider.of<NotificationService>(context,
                              listen: false);

                      try {
                        await notificationService.showTestNotification();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Sent immediate notification!")),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text("Error: $e"),
                                backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                  ),
                ),
                // --- TEST BUTTON END ---
                Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.battery_alert),
                    label: const Text("Fix Battery Restrictions"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      final notificationService =
                          Provider.of<NotificationService>(context,
                              listen: false);
                      bool granted = await notificationService
                          .requestBatteryOptimizations();
                      if (context.mounted) {
                        if (granted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Battery restrictions removed!")),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    "Please remove battery restrictions in settings.")),
                          );
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
