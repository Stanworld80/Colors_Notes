import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'palette.dart';

const Uuid _uuid = Uuid();

class Journal {
  final String id;
  final String userId;
  String name;
  Palette palette;
  final Timestamp createdAt;
  Timestamp lastUpdatedAt;
  final bool notificationsEnabled;
  final String notificationPhrase;
  final List<bool> notificationDays;
  final List<String> notificationTimes;

  Journal({
    String? id,
    required this.userId,
    required this.name,
    required this.palette,
    required this.createdAt,
    required this.lastUpdatedAt,
    this.notificationsEnabled = false,
    this.notificationPhrase = '',
    List<bool>? notificationDays,
    List<String>? notificationTimes,
  })  : id = id ?? _uuid.v4(),
        notificationDays = notificationDays ?? List.filled(7, false),
        notificationTimes = notificationTimes ?? [];

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'palette': palette.toMap(),
      'createdAt': createdAt,
      'lastUpdatedAt': lastUpdatedAt,
      'notificationsEnabled': notificationsEnabled,
      'notificationPhrase': notificationPhrase,
      'notificationDays': notificationDays,
      'notificationTimes': notificationTimes,
    };
  }

  factory Journal.fromMap(Map<String, dynamic> map, String documentId) {
    return Journal(
      id: documentId,
      userId: map['userId'] as String? ?? '',
      name: map['name'] as String? ?? 'Journal sans nom',
      palette: map['palette'] != null
          ? Palette.fromEmbeddedMap(map['palette'] as Map<String, dynamic>)
          : Palette(id: _uuid.v4(), name: "Palette par défaut", colors: [], userId: map['userId'] as String?),
      createdAt: map['createdAt'] as Timestamp? ?? Timestamp.now(),
      lastUpdatedAt: map['lastUpdatedAt'] as Timestamp? ?? Timestamp.now(),
      notificationsEnabled: map['notificationsEnabled'] as bool? ?? false,
      notificationPhrase: map['notificationPhrase'] as String? ?? '',
      notificationDays: (map['notificationDays'] as List<dynamic>? ?? List.filled(7, false)).map((e) => e as bool).toList(),
      notificationTimes: (map['notificationTimes'] as List<dynamic>? ?? []).map((e) => e as String).toList(),
    );
  }

  Journal copyWith({
    String? id,
    String? userId,
    String? name,
    Palette? palette,
    Timestamp? createdAt,
    Timestamp? lastUpdatedAt,
    bool? notificationsEnabled,
    String? notificationPhrase,
    List<bool>? notificationDays,
    List<String>? notificationTimes,
  }) {
    return Journal(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      palette: palette ?? this.palette.copyWith(),
      createdAt: createdAt ?? this.createdAt,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      notificationPhrase: notificationPhrase ?? this.notificationPhrase,
      notificationDays: notificationDays ?? this.notificationDays,
      notificationTimes: notificationTimes ?? this.notificationTimes,
    );
  }
}
