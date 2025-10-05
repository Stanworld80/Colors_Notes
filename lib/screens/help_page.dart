import 'package:flutter/material.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: const [
          HelpTopic(
            title: 'Managing Journals',
            icon: Icons.book,
            content:
                'Journals are like notebooks where you can group your notes.\n\n'
                'To create a new journal, go to the Journal Management screen and tap the "Add" button.\n\n'
                'You can rename or delete journals from the same screen with a long press on the journal entry.',
          ),
          SizedBox(height: 16),
          HelpTopic(
            title: 'Creating and Editing Notes',
            icon: Icons.note_add,
            content:
                'To create a new note, open a journal and tap the "Add" button.\n\n'
                'Write your thoughts, ideas, or anything you want to remember.\n\n'
                'Your notes are saved automatically as you type. To go back, use the back arrow.',
          ),
          SizedBox(height: 16),
          HelpTopic(
            title: 'Using Colors',
            icon: Icons.color_lens,
            content:
                'You can assign a color to each note to categorize or prioritize them.\n\n'
                'When creating or editing a note, tap on the color palette icon to choose a color that best fits your note.',
          ),
          SizedBox(height: 16),
          HelpTopic(
            title: 'Your Account',
            icon: Icons.account_circle,
            content:
                'Your notes are securely stored and synced across your devices with your account.\n\n'
                'You can sign out from the options menu in the app bar. This will take you back to the sign-in screen.',
          ),
        ],
      ),
    );
  }
}

class HelpTopic extends StatelessWidget {
  final String title;
  final IconData icon;
  final String content;

  const HelpTopic({
    super.key,
    required this.title,
    required this.icon,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2.0,
      child: ExpansionTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(content),
          ),
        ],
      ),
    );
  }
}
