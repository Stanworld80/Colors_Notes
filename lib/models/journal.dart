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

  Journal({
    String? id,
    required this.userId,
    required this.name,
    required this.palette,
    required this.createdAt,
    required this.lastUpdatedAt,
  }) : id = id ?? _uuid.v4();

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'palette': palette.toMap(),
      'createdAt': createdAt,
      'lastUpdatedAt': lastUpdatedAt,
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
    );
  }

  Journal copyWith({
    String? id,
    String? userId,
    String? name,
    Palette? palette,
    Timestamp? createdAt,
    Timestamp? lastUpdatedAt,
  }) {
    return Journal(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      palette: palette ?? this.palette.copyWith(),
      createdAt: createdAt ?? this.createdAt,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }
}
