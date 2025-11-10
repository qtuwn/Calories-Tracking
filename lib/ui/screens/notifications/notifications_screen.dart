import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/notifications_provider.dart';
import '../../../ui/components/notification_tile.dart';
import 'notification_detail_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<NotificationsProvider>(context);
    final items = prov.items;
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final it = items[i];
          return NotificationTile(
            item: it,
            onTap: () {
              prov.markRead(it.id);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => NotificationDetailScreen(item: it),
                ),
              );
            },
            onDelete: () => prov.remove(it.id),
          );
        },
      ),
    );
  }
}
