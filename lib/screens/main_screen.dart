// lib/screens/main_screen.dart
import 'package:flutter/material.dart';
import 'logged_homepage.dart';
import 'note_list_page.dart';
import 'journal_management_page.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // La liste des widgets reste la même
  static const List<Widget> _widgetOptions = <Widget>[LoggedHomepage(), NoteListPage(), JournalManagementPage()];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // MODIFICATION ICI : Utiliser IndexedStack
      body: IndexedStack(
        index: _selectedIndex, // Indique quel enfant afficher
        children: _widgetOptions, // Fournir tous les enfants
      ),
      // La BottomNavigationBar reste identique
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Accueil'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt_outlined), activeIcon: Icon(Icons.list_alt), label: 'Notes'),
          BottomNavigationBarItem(icon: Icon(Icons.book_outlined), activeIcon: Icon(Icons.book), label: 'Journals'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}
