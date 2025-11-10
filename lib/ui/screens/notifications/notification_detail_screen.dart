import 'package:flutter/material.dart';
import '../../../models/notification_item.dart';

class NotificationDetailScreen extends StatelessWidget {
  final NotificationItem item;
  const NotificationDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(item.title)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(item.body, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            if (item.deepLink != null) Text('Deep link: ${item.deepLink}'),
            const SizedBox(height: 20),
            Text('Received: ${item.timestamp.toLocal().toString()}'),
          ],
        ),
      ),
    );
  }
}
