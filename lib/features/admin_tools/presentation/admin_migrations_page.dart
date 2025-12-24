import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../state/admin_guard_provider.dart';
import '../state/admin_tools_providers.dart';
import '../domain/migration_report.dart';
import '../domain/migration_exceptions.dart';

/// Admin-only page for running migrations and repairs
class AdminMigrationsPage extends ConsumerStatefulWidget {
  static const String routeName = '/admin/migrations';

  const AdminMigrationsPage({super.key});

  @override
  ConsumerState<AdminMigrationsPage> createState() =>
      _AdminMigrationsPageState();
}

class _AdminMigrationsPageState extends ConsumerState<AdminMigrationsPage> {
  // UI state
  bool _dryRun = true; // Safe default
  bool _strictMode = true; // Safe default
  double _defaultServingSize = 1.0;
  double _epsilon = 0.0001;
  int? _limitUsers;
  int? _limitTemplates;
  int? _limitPlansPerUser;

  // Running state
  bool _isRunning = false;
  String? _currentOperation;

  // Latest report (either MigrationReport or RepairReport)
  Object? _latestReport;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    // Check admin guard
    final adminGuardAsync = ref.watch(adminGuardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Tools: Migrations & Repairs'),
      ),
      body: adminGuardAsync.when(
        data: (isAdmin) {
          if (!isAdmin) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'Access Denied',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'This page is only accessible to administrators.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          return _buildToolsUI();
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 64, color: Colors.red),
                SizedBox(height: 16),
                Text(
                  'Access Denied',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Error checking admin status. Access denied by default.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolsUI() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Warning banner if dryRun is false
          if (!_dryRun)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.red),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Writes enabled. This will mutate Firestore.',
                      style: TextStyle(
                        color: Colors.red.shade900,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Controls
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Dry Run'),
                    subtitle: const Text(
                      'Calculate changes without writing to Firestore',
                    ),
                    value: _dryRun,
                    onChanged: (value) => setState(() => _dryRun = value),
                  ),
                  SwitchListTile(
                    title: const Text('Strict Mode'),
                    subtitle: const Text(
                      'Throw errors on invalid slot structure (migration only)',
                    ),
                    value: _strictMode,
                    onChanged: (value) => setState(() => _strictMode = value),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Default Serving Size',
                      helperText: 'For migration: backfill value for missing servingSize',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (value) {
                      final parsed = double.tryParse(value);
                      if (parsed != null && parsed > 0) {
                        setState(() => _defaultServingSize = parsed);
                      }
                    },
                    controller: TextEditingController(
                      text: _defaultServingSize.toString(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Epsilon',
                      helperText: 'For repair: tolerance for floating point comparisons',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (value) {
                      final parsed = double.tryParse(value);
                      if (parsed != null && parsed >= 0) {
                        setState(() => _epsilon = parsed);
                      }
                    },
                    controller: TextEditingController(
                      text: _epsilon.toString(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Limit Users (optional)',
                      helperText: 'Limit number of users to process',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      final parsed = int.tryParse(value);
                      setState(() =>
                          _limitUsers = parsed != null && parsed > 0 ? parsed : null);
                    },
                    controller: TextEditingController(
                      text: _limitUsers?.toString() ?? '',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Limit Templates (optional)',
                      helperText: 'Limit number of templates to process',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      final parsed = int.tryParse(value);
                      setState(() => _limitTemplates =
                          parsed != null && parsed > 0 ? parsed : null);
                    },
                    controller: TextEditingController(
                      text: _limitTemplates?.toString() ?? '',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Limit Plans Per User (optional)',
                      helperText: 'Limit number of plans per user to process',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      final parsed = int.tryParse(value);
                      setState(() => _limitPlansPerUser =
                          parsed != null && parsed > 0 ? parsed : null);
                    },
                    controller: TextEditingController(
                      text: _limitPlansPerUser?.toString() ?? '',
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Actions
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Actions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: _isRunning && _currentOperation == 'migration'
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_upload),
                    label: Text(
                      _dryRun
                          ? 'Dry Run: Backfill Explore Template servingSize'
                          : 'Run: Backfill Explore Template servingSize',
                    ),
                    onPressed: _isRunning
                        ? null
                        : () => _runMigration(),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    icon: _isRunning && _currentOperation == 'repair_totals'
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.build),
                    label: Text(
                      _dryRun
                          ? 'Dry Run: Repair Day Totals'
                          : 'Run: Repair Day Totals',
                    ),
                    onPressed: _isRunning
                        ? null
                        : () => _repairDayTotals(),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    icon: _isRunning && _currentOperation == 'repair_active'
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.build_circle),
                    label: Text(
                      _dryRun
                          ? 'Dry Run: Repair Multiple Active Plans'
                          : 'Run: Repair Multiple Active Plans',
                    ),
                    onPressed: _isRunning
                        ? null
                        : () => _repairActivePlans(),
                  ),
                ],
              ),
            ),
          ),

          // Report display
          if (_latestReport != null || _errorMessage != null) ...[
            const SizedBox(height: 16),
            _buildReportCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildReportCard() {
    if (_errorMessage != null) {
      return Card(
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.error, color: Colors.red),
                  const SizedBox(width: 8),
                  const Text(
                    'Error',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(_errorMessage!),
            ],
          ),
        ),
      );
    }

    final report = _latestReport;
    if (report == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Report',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // Summary
            if (report is MigrationReport) ...[
              Text('Templates scanned: ${report.templatesScanned}'),
              Text('Templates updated: ${report.templatesUpdated}'),
              Text('Slots updated: ${report.slotsUpdated}'),
            ] else if (report is RepairReport) ...[
              Text('Plans scanned: ${report.plansScanned}'),
              Text('Days scanned: ${report.daysScanned}'),
              Text('Days repaired: ${report.daysRepaired}'),
              Text('Active plans fixed: ${report.activePlansFixed}'),
            ],
            const SizedBox(height: 16),
            // Updated paths
            if (report is MigrationReport && report.updatedDocPaths.isNotEmpty) ...[
              _buildExpandableSection(
                'Updated Doc Paths (${report.updatedDocPaths.length})',
                report.updatedDocPaths,
              ),
            ] else if (report is RepairReport &&
                report.repairedDocPaths.isNotEmpty) ...[
              _buildExpandableSection(
                'Repaired Doc Paths (${report.repairedDocPaths.length})',
                report.repairedDocPaths,
              ),
            ],
            // Warnings
            if ((report is MigrationReport && report.warnings.isNotEmpty) ||
                (report is RepairReport && report.warnings.isNotEmpty)) ...[
              const SizedBox(height: 16),
              _buildExpandableSection(
                report is MigrationReport
                    ? 'Warnings (${report.warnings.length})'
                    : 'Warnings (${(report as RepairReport).warnings.length})',
                report is MigrationReport
                    ? report.warnings
                    : (report as RepairReport).warnings,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExpandableSection(String title, List<String> items) {
    return ExpansionTile(
      title: Text(title),
      children: [
        Container(
          constraints: const BoxConstraints(maxHeight: 300),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: items.length > 50 ? 50 : items.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 4.0,
                ),
                child: Text(
                  items[index],
                  style: const TextStyle(fontSize: 12),
                ),
              );
            },
          ),
        ),
        if (items.length > 50)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('... and ${items.length - 50} more'),
          ),
      ],
    );
  }

  Future<void> _runMigration() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() {
        _errorMessage = 'User not authenticated';
        _isRunning = false;
        _currentOperation = null;
      });
      return;
    }

    setState(() {
      _isRunning = true;
      _currentOperation = 'migration';
      _errorMessage = null;
      _latestReport = null;
    });

    try {
      final repo = ref.read(exploreTemplateMigrationRepoProvider);
      final report = await repo.backfillServingSize(
        defaultServingSize: _defaultServingSize,
        dryRun: _dryRun,
        strict: _strictMode,
        limitTemplates: _limitTemplates,
        adminUserId: currentUser.uid,
      );

      setState(() {
        _latestReport = report;
        _isRunning = false;
        _currentOperation = null;
      });
    } on MigrationException catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isRunning = false;
        _currentOperation = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '${e.runtimeType}: ${e.toString()}';
        _isRunning = false;
        _currentOperation = null;
      });
    }
  }

  Future<void> _repairDayTotals() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() {
        _errorMessage = 'User not authenticated';
        _isRunning = false;
        _currentOperation = null;
      });
      return;
    }

    setState(() {
      _isRunning = true;
      _currentOperation = 'repair_totals';
      _errorMessage = null;
      _latestReport = null;
    });

    try {
      final repo = ref.read(userPlanConsistencyRepairRepoProvider);
      final report = await repo.repairDayTotals(
        dryRun: _dryRun,
        epsilon: _epsilon,
        limitUsers: _limitUsers,
        limitPlansPerUser: _limitPlansPerUser,
        adminUserId: currentUser.uid,
      );

      setState(() {
        _latestReport = report;
        _isRunning = false;
        _currentOperation = null;
      });
    } on MigrationException catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isRunning = false;
        _currentOperation = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '${e.runtimeType}: ${e.toString()}';
        _isRunning = false;
        _currentOperation = null;
      });
    }
  }

  Future<void> _repairActivePlans() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() {
        _errorMessage = 'User not authenticated';
        _isRunning = false;
        _currentOperation = null;
      });
      return;
    }

    setState(() {
      _isRunning = true;
      _currentOperation = 'repair_active';
      _errorMessage = null;
      _latestReport = null;
    });

    try {
      final repo = ref.read(activePlanRepairRepoProvider);
      final report = await repo.repairMultipleActivePlans(
        dryRun: _dryRun,
        limitUsers: _limitUsers,
        adminUserId: currentUser.uid,
      );

      setState(() {
        _latestReport = report;
        _isRunning = false;
        _currentOperation = null;
      });
    } on MigrationException catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isRunning = false;
        _currentOperation = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '${e.runtimeType}: ${e.toString()}';
        _isRunning = false;
        _currentOperation = null;
      });
    }
  }
}
