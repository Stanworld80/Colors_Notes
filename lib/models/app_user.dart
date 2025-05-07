import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String id;
  final String? email;
  final String? displayName;
  final Timestamp registrationDate;

  AppUser({
    required this.id,
    this.email,
    this.displayName,
    required this.registrationDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'registrationDate': registrationDate,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map, String documentId) {
    return AppUser(
      id: documentId,
      email: map['email'] as String?,
      displayName: map['displayName'] as String?,
      registrationDate: map['registrationDate'] as Timestamp? ?? Timestamp.now(),
    );
  }
}
