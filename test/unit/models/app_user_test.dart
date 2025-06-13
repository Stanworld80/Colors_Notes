// test/unit/models/app_user_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:colors_notes/models/app_user.dart';

void main() {
  group('AppUser Model Tests', () {
    final Timestamp now = Timestamp.now();

    test('Constructeur devrait assigner les valeurs correctement', () {
      final appUser = AppUser(id: 'user123', email: 'test@example.com', displayName: 'Test User', registrationDate: now);

      expect(appUser.id, 'user123');
      expect(appUser.email, 'test@example.com');
      expect(appUser.displayName, 'Test User');
      expect(appUser.registrationDate, now);
    });

    test('toMap devrait retourner une map correcte', () {
      final appUser = AppUser(id: 'user123', email: 'test@example.com', displayName: 'Test User', registrationDate: now);
      final map = appUser.toMap();

      // L'ID n'est pas inclus dans toMap car il est utilisé comme ID de document
      expect(map['email'], 'test@example.com');
      expect(map['displayName'], 'Test User');
      expect(map['registrationDate'], now);
      expect(map.containsKey('id'), isFalse);
    });

    test('fromMap devrait créer une instance AppUser correcte', () {
      final map = {'email': 'test@example.com', 'displayName': 'Test User', 'registrationDate': now};
      final documentId = 'user123';
      final appUser = AppUser.fromMap(map, documentId);

      expect(appUser.id, documentId);
      expect(appUser.email, 'test@example.com');
      expect(appUser.displayName, 'Test User');
      expect(appUser.registrationDate, now);
    });

    test('fromMap devrait gérer les champs optionnels nuls', () {
      final map = {'email': null, 'displayName': null, 'registrationDate': now};
      final documentId = 'user456';
      final appUser = AppUser.fromMap(map, documentId);

      expect(appUser.id, documentId);
      expect(appUser.email, isNull);
      expect(appUser.displayName, isNull);
      expect(appUser.registrationDate, now);
    });

    test('fromMap devrait utiliser Timestamp.now() si registrationDate est nulle ou manquante', () {
      final mapWithoutDate = {'email': 'test@example.com', 'displayName': 'Test User'};
      final appUser1 = AppUser.fromMap(mapWithoutDate, 'user1');
      // La comparaison exacte des Timestamps peut être délicate,
      // donc nous vérifions qu'elle n'est pas nulle et proche de maintenant.
      expect(appUser1.registrationDate, isNotNull);
      expect(appUser1.registrationDate.toDate().difference(DateTime.now()).inSeconds.abs(), lessThan(5));

      final mapWithNullDate = {'email': 'test@example.com', 'displayName': 'Test User', 'registrationDate': null};
      final appUser2 = AppUser.fromMap(mapWithNullDate, 'user2');
      expect(appUser2.registrationDate, isNotNull);
      expect(appUser2.registrationDate.toDate().difference(DateTime.now()).inSeconds.abs(), lessThan(5));
    });
  });
}