import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/activities/activity.dart';

/// Data Transfer Object for Activity
/// 
/// Handles conversion between Firestore documents and domain Activity entities.
class ActivityDto {
  final String id;
  final String name;
  final String category;
  final double met;
  final String intensity;
  final String? description;
  final String? iconName;
  final bool isActive;
  final Timestamp createdAt;
  final Timestamp? updatedAt;
  final Timestamp? deletedAt;

  ActivityDto({
    required this.id,
    required this.name,
    required this.category,
    required this.met,
    required this.intensity,
    this.description,
    this.iconName,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  /// Create DTO from Firestore document
  factory ActivityDto.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ActivityDto(
      id: doc.id,
      name: data['name'] as String? ?? '',
      category: data['category'] as String? ?? 'other',
      met: (data['met'] as num?)?.toDouble() ?? 0.0,
      intensity: data['intensity'] as String? ?? 'moderate',
      description: data['description'] as String?,
      iconName: data['iconName'] as String?,
      isActive: data['isActive'] as bool? ?? true,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      updatedAt: data['updatedAt'] as Timestamp?,
      deletedAt: data['deletedAt'] as Timestamp?,
    );
  }

  /// Convert DTO to Firestore map
  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{
      'name': name,
      'category': category,
      'met': met,
      'intensity': intensity,
      'isActive': isActive,
      'createdAt': createdAt,
    };

    if (description != null) map['description'] = description;
    if (iconName != null) map['iconName'] = iconName;
    if (updatedAt != null) map['updatedAt'] = updatedAt;
    if (deletedAt != null) map['deletedAt'] = deletedAt;

    return map;
  }

  /// Convert DTO to domain entity
  Activity toDomain() {
    return Activity(
      id: id,
      name: name,
      category: ActivityCategory.fromString(category),
      met: met,
      intensity: ActivityIntensity.fromString(intensity),
      description: description,
      iconName: iconName,
      isActive: isActive,
      createdAt: createdAt.toDate(),
      updatedAt: updatedAt?.toDate(),
      deletedAt: deletedAt?.toDate(),
    );
  }

  /// Create DTO from domain entity
  factory ActivityDto.fromDomain(Activity activity) {
    return ActivityDto(
      id: activity.id,
      name: activity.name,
      category: activity.category.name,
      met: activity.met,
      intensity: activity.intensity.name,
      description: activity.description,
      iconName: activity.iconName,
      isActive: activity.isActive,
      createdAt: Timestamp.fromDate(activity.createdAt),
      updatedAt: activity.updatedAt != null
          ? Timestamp.fromDate(activity.updatedAt!)
          : null,
      deletedAt: activity.deletedAt != null
          ? Timestamp.fromDate(activity.deletedAt!)
          : null,
    );
  }
}

