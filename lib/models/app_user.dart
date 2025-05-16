import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an application user.
///
/// This class encapsulates the user's unique identifier ([id]), email,
/// display name, and their registration date.
class AppUser {
  /// The unique identifier of the user.
  final String id;

  /// The email address of the user. Can be null.
  final String? email;

  /// The display name of the user. Can be null.
  final String? displayName;

  /// The timestamp of when the user registered.
  final Timestamp registrationDate;

  /// Creates an instance of [AppUser].
  ///
  /// The [id] and [registrationDate] are required.
  /// The [email] and [displayName] are optional.
  AppUser({
    required this.id,
    this.email,
    this.displayName,
    required this.registrationDate,
  });

  /// Converts this [AppUser] instance to a map.
  ///
  /// This is typically used when saving user data. The [id] is not
  /// part of the returned map as it's often used as the document ID elsewhere.
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'registrationDate': registrationDate,
    };
  }

  /// Creates an [AppUser] instance from a map (typically from Firestore) and a document ID.
  ///
  /// The [map] contains the user data, and [documentId] is used as the user's [id].
  /// If 'registrationDate' is missing or null in the map, it defaults to the current time.
  factory AppUser.fromMap(Map<String, dynamic> map, String documentId) {
    return AppUser(
      id: documentId,
      email: map['email'] as String?,
      displayName: map['displayName'] as String?,
      registrationDate: map['registrationDate'] as Timestamp? ?? Timestamp.now(),
    );
  }
}
