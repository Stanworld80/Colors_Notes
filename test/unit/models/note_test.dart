// test/unit/models/note_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:colors_notes/models/note.dart';
import 'package:uuid/uuid.dart';

void main() {
  group('Note Model Tests', () {
    final Timestamp now = Timestamp.now();
    final testUserId = 'userNoteTest';
    final testJournalId = 'journalNoteTest';
    final testPaletteElementId = 'colorElementForNote';

    test('Constructeur devrait assigner les valeurs et générer un ID si non fourni', () {
      final note = Note(
        journalId: testJournalId,
        userId: testUserId,
        content: 'Contenu de la note',
        paletteElementId: testPaletteElementId,
        eventTimestamp: now,
        createdAt: now,
        lastUpdatedAt: now,
      );

      expect(note.id, isNotEmpty);
      expect(Uuid.isValidUUID(fromString: note.id), isTrue);
      expect(note.journalId, testJournalId);
      expect(note.userId, testUserId);
      expect(note.content, 'Contenu de la note');
      expect(note.paletteElementId, testPaletteElementId);
      expect(note.eventTimestamp, now);
      expect(note.createdAt, now);
      expect(note.lastUpdatedAt, now);

      final noteWithId = Note(
        id: 'custom-note-id',
        journalId: testJournalId,
        userId: testUserId,
        content: 'Autre contenu',
        paletteElementId: testPaletteElementId,
        eventTimestamp: now,
        createdAt: now,
        lastUpdatedAt: now,
      );
      expect(noteWithId.id, 'custom-note-id');
    });

    test('toMap devrait retourner une map correcte', () {
      final note = Note(
        id: 'noteX',
        journalId: testJournalId,
        userId: testUserId,
        content: 'Contenu X',
        paletteElementId: testPaletteElementId,
        eventTimestamp: now,
        createdAt: now,
        lastUpdatedAt: now,
      );
      final map = note.toMap();

      expect(map['journalId'], testJournalId);
      expect(map['userId'], testUserId);
      expect(map['content'], 'Contenu X');
      expect(map['paletteElementId'], testPaletteElementId);
      expect(map['eventTimestamp'], now);
      expect(map['createdAt'], now);
      expect(map['lastUpdatedAt'], now);
      expect(map.containsKey('id'), isFalse);
    });

    test('fromMap devrait créer une instance Note correcte', () {
      final Map<String, dynamic> map = { // Explicitement typé
        'journalId': testJournalId,
        'userId': testUserId,
        'content': 'Note depuis Map',
        'paletteElementId': testPaletteElementId,
        'eventTimestamp': now,
        'createdAt': now,
        'lastUpdatedAt': now,
      };
      final documentId = 'note-from-map-id';
      final note = Note.fromMap(map, documentId);

      expect(note.id, documentId);
      expect(note.journalId, testJournalId);
      expect(note.userId, testUserId);
      expect(note.content, 'Note depuis Map');
      expect(note.paletteElementId, testPaletteElementId);
      expect(note.eventTimestamp, now);
      expect(note.createdAt, now);
      expect(note.lastUpdatedAt, now);
    });

    test('fromMap devrait gérer les champs nuls et fournir des valeurs par défaut', () {
      final Map<String, dynamic> map = {}; // Explicitement typé et vide
      final documentId = 'note-defaults';
      final note = Note.fromMap(map, documentId);

      expect(note.id, documentId);
      expect(note.journalId, '');
      expect(note.userId, '');
      expect(note.content, '');
      expect(note.paletteElementId, '');
      expect(note.eventTimestamp.toDate().difference(DateTime.now()).inSeconds.abs(), lessThan(5));
      expect(note.createdAt.toDate().difference(DateTime.now()).inSeconds.abs(), lessThan(5));
      expect(note.lastUpdatedAt.toDate().difference(DateTime.now()).inSeconds.abs(), lessThan(5));
    });

    test('copyWith devrait copier l\'instance avec/sans nouvelles valeurs', () {
      final originalNote = Note(
        id: 'orig-note-id',
        journalId: testJournalId,
        userId: testUserId,
        content: 'Contenu Original',
        paletteElementId: 'orig-color-id',
        eventTimestamp: now,
        createdAt: now,
        lastUpdatedAt: now,
      );

      final copiedIdentical = originalNote.copyWith();
      expect(copiedIdentical.id, originalNote.id);
      expect(copiedIdentical.content, originalNote.content);
      expect(copiedIdentical.paletteElementId, originalNote.paletteElementId);
      expect(copiedIdentical.journalId, originalNote.journalId);
      expect(copiedIdentical.userId, originalNote.userId);
      expect(copiedIdentical.eventTimestamp, originalNote.eventTimestamp);
      expect(copiedIdentical.createdAt, originalNote.createdAt);
      expect(copiedIdentical.lastUpdatedAt, originalNote.lastUpdatedAt);


      final newEventTime = Timestamp.fromMillisecondsSinceEpoch(now.millisecondsSinceEpoch + 10000);
      final copiedModified = originalNote.copyWith(
          content: 'Contenu Modifié',
          eventTimestamp: newEventTime,
          paletteElementId: 'new-color-id'
      );

      expect(copiedModified.id, originalNote.id);
      expect(copiedModified.content, 'Contenu Modifié');
      expect(copiedModified.eventTimestamp, newEventTime);
      expect(copiedModified.paletteElementId, 'new-color-id');
      expect(copiedModified.lastUpdatedAt, originalNote.lastUpdatedAt);
    });
  });
}
