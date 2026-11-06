import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:ikrili/data/datasources/app_database.dart';
import 'package:ikrili/data/services/local_auth_service.dart';

class DebugDatabasePage extends StatefulWidget {
  const DebugDatabasePage({super.key});

  @override
  State<DebugDatabasePage> createState() => _DebugDatabasePageState();
}

class _DebugDatabasePageState extends State<DebugDatabasePage> {
  Future<Map<String, dynamic>> _loadDump() async {
    final db = await AppDatabase.instance.database;
    final users = await db.query(
      AppDatabase.tableUsers,
      orderBy: 'created_at DESC',
    );
    final cars = await db.query(
      AppDatabase.tableCars,
      orderBy: 'created_at DESC',
    );
    final reservedDates = await db.query(
      AppDatabase.tableReservedDates,
      orderBy: 'date ASC',
    );
    final reservations = await db.query(
      AppDatabase.tableReservations,
      orderBy: 'created_at DESC',
    );
    final notifications = await db.query(
      AppDatabase.tableNotifications,
      orderBy: 'created_at DESC',
    );
    return {
      'currentUser': LocalAuthService.instance.currentUser == null
          ? null
          : {
              'id': LocalAuthService.instance.currentUser!.id,
              'name': LocalAuthService.instance.currentUser!.name,
              'email': LocalAuthService.instance.currentUser!.email,
              'role': LocalAuthService.instance.currentUser!.role,
            },
      'users': users,
      'cars': cars,
      'reserved_dates': reservedDates,
      'reservations': reservations,
      'notifications': notifications,
    };
  }

  String _prettyJson(Object? data) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(data);
  }

  Future<void> _showExportDialog() async {
    if (!mounted) return;
    final dump = await _loadDump();
    if (!mounted) return;
    final jsonText = _prettyJson(dump);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('SQLite Export'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              jsonText,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Debug Database')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loadDump(),
        builder: (context, snapshot) {
          final dump = snapshot.data;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'SQLite data overview',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('Current user'),
                  subtitle: Text(
                    dump?['currentUser'] == null
                        ? 'No signed-in user'
                        : _prettyJson(dump!['currentUser']),
                  ),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.people),
                  title: const Text('Users'),
                  subtitle: Text(
                    '${(dump?['users'] as List?)?.length ?? 0} rows',
                  ),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.directions_car),
                  title: const Text('Cars'),
                  subtitle: Text(
                    '${(dump?['cars'] as List?)?.length ?? 0} rows',
                  ),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.event),
                  title: const Text('Reserved dates'),
                  subtitle: Text(
                    '${(dump?['reserved_dates'] as List?)?.length ?? 0} rows',
                  ),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.assignment_turned_in_outlined),
                  title: const Text('Reservations'),
                  subtitle: Text(
                    '${(dump?['reservations'] as List?)?.length ?? 0} rows',
                  ),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('Notifications'),
                  subtitle: Text(
                    '${(dump?['notifications'] as List?)?.length ?? 0} rows',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _showExportDialog,
                icon: const Icon(Icons.code),
                label: const Text('Export JSON'),
              ),
            ],
          );
        },
      ),
    );
  }
}
