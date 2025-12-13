/// Typed exceptions for migration and repair operations
/// 
/// Includes full context for debugging and audit trails.
class MigrationException implements Exception {
  final String message;
  final String? userId;
  final String? templateId;
  final String? planId;
  final int? dayIndex;
  final String? docPath;
  final Map<String, dynamic>? details;

  MigrationException(
    this.message, {
    this.userId,
    this.templateId,
    this.planId,
    this.dayIndex,
    this.docPath,
    this.details,
  });

  @override
  String toString() {
    final parts = <String>['MigrationException: $message'];
    if (userId != null) parts.add('userId=$userId');
    if (templateId != null) parts.add('templateId=$templateId');
    if (planId != null) parts.add('planId=$planId');
    if (dayIndex != null) parts.add('dayIndex=$dayIndex');
    if (docPath != null) parts.add('docPath=$docPath');
    if (details != null && details!.isNotEmpty) {
      parts.add('details=$details');
    }
    return parts.join(', ');
  }
}
