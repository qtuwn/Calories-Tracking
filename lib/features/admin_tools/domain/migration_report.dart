/// Immutable report for migration operations
class MigrationReport {
  final int templatesScanned;
  final int templatesUpdated;
  final int slotsUpdated;
  final List<String> updatedDocPaths;
  final List<String> warnings;

  const MigrationReport({
    required this.templatesScanned,
    required this.templatesUpdated,
    required this.slotsUpdated,
    required this.updatedDocPaths,
    required this.warnings,
  });

  @override
  String toString() {
    final buffer = StringBuffer('MigrationReport:\n');
    buffer.writeln('  Templates scanned: $templatesScanned');
    buffer.writeln('  Templates updated: $templatesUpdated');
    buffer.writeln('  Slots updated: $slotsUpdated');
    buffer.writeln('  Updated doc paths: ${updatedDocPaths.length}');
    if (updatedDocPaths.isNotEmpty) {
      for (final path in updatedDocPaths) {
        buffer.writeln('    - $path');
      }
    }
    if (warnings.isNotEmpty) {
      buffer.writeln('  Warnings: ${warnings.length}');
      for (final warning in warnings) {
        buffer.writeln('    - $warning');
      }
    }
    return buffer.toString();
  }
}

/// Immutable report for repair operations
class RepairReport {
  final int plansScanned;
  final int daysScanned;
  final int daysRepaired;
  final int activePlansFixed;
  final List<String> repairedDocPaths;
  final List<String> warnings;

  const RepairReport({
    required this.plansScanned,
    required this.daysScanned,
    required this.daysRepaired,
    required this.activePlansFixed,
    required this.repairedDocPaths,
    required this.warnings,
  });

  @override
  String toString() {
    final buffer = StringBuffer('RepairReport:\n');
    buffer.writeln('  Plans scanned: $plansScanned');
    buffer.writeln('  Days scanned: $daysScanned');
    buffer.writeln('  Days repaired: $daysRepaired');
    buffer.writeln('  Active plans fixed: $activePlansFixed');
    buffer.writeln('  Repaired doc paths: ${repairedDocPaths.length}');
    if (repairedDocPaths.isNotEmpty) {
      for (final path in repairedDocPaths) {
        buffer.writeln('    - $path');
      }
    }
    if (warnings.isNotEmpty) {
      buffer.writeln('  Warnings: ${warnings.length}');
      for (final warning in warnings) {
        buffer.writeln('    - $warning');
      }
    }
    return buffer.toString();
  }
}
