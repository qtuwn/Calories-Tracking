import 'package:flutter_test/flutter_test.dart';
import 'package:calories_app/features/admin_tools/domain/migration_report.dart';

void main() {
  group('MigrationReport', () {
    test('construction stores all fields correctly', () {
      const report = MigrationReport(
        templatesScanned: 10,
        templatesUpdated: 5,
        slotsUpdated: 20,
        updatedDocPaths: ['path1', 'path2'],
        warnings: ['warning1'],
      );

      expect(report.templatesScanned, 10);
      expect(report.templatesUpdated, 5);
      expect(report.slotsUpdated, 20);
      expect(report.updatedDocPaths, ['path1', 'path2']);
      expect(report.warnings, ['warning1']);
    });

    test('toString contains key fields', () {
      const report = MigrationReport(
        templatesScanned: 10,
        templatesUpdated: 5,
        slotsUpdated: 20,
        updatedDocPaths: ['path1', 'path2'],
        warnings: ['warning1'],
      );

      final str = report.toString();

      expect(str, contains('MigrationReport:'));
      expect(str, contains('Templates scanned: 10'));
      expect(str, contains('Templates updated: 5'));
      expect(str, contains('Slots updated: 20'));
      expect(str, contains('path1'));
      expect(str, contains('path2'));
      expect(str, contains('warning1'));
    });

    test('empty report prints correctly', () {
      const report = MigrationReport(
        templatesScanned: 0,
        templatesUpdated: 0,
        slotsUpdated: 0,
        updatedDocPaths: [],
        warnings: [],
      );

      final str = report.toString();

      expect(str, contains('MigrationReport:'));
      expect(str, contains('Templates scanned: 0'));
      expect(str, contains('Templates updated: 0'));
      expect(str, contains('Slots updated: 0'));
    });
  });

  group('RepairReport', () {
    test('construction stores all fields correctly', () {
      const report = RepairReport(
        plansScanned: 15,
        daysScanned: 30,
        daysRepaired: 5,
        activePlansFixed: 3,
        repairedDocPaths: ['path1', 'path2'],
        warnings: ['warning1'],
      );

      expect(report.plansScanned, 15);
      expect(report.daysScanned, 30);
      expect(report.daysRepaired, 5);
      expect(report.activePlansFixed, 3);
      expect(report.repairedDocPaths, ['path1', 'path2']);
      expect(report.warnings, ['warning1']);
    });

    test('toString contains key fields', () {
      const report = RepairReport(
        plansScanned: 15,
        daysScanned: 30,
        daysRepaired: 5,
        activePlansFixed: 3,
        repairedDocPaths: ['path1', 'path2'],
        warnings: ['warning1'],
      );

      final str = report.toString();

      expect(str, contains('RepairReport:'));
      expect(str, contains('Plans scanned: 15'));
      expect(str, contains('Days scanned: 30'));
      expect(str, contains('Days repaired: 5'));
      expect(str, contains('Active plans fixed: 3'));
      expect(str, contains('path1'));
      expect(str, contains('path2'));
      expect(str, contains('warning1'));
    });

    test('empty report prints correctly', () {
      const report = RepairReport(
        plansScanned: 0,
        daysScanned: 0,
        daysRepaired: 0,
        activePlansFixed: 0,
        repairedDocPaths: [],
        warnings: [],
      );

      final str = report.toString();

      expect(str, contains('RepairReport:'));
      expect(str, contains('Plans scanned: 0'));
      expect(str, contains('Days scanned: 0'));
      expect(str, contains('Days repaired: 0'));
      expect(str, contains('Active plans fixed: 0'));
    });
  });
}
