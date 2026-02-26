import 'package:flutter/material.dart';

class StatusCard extends StatelessWidget {
  const StatusCard({
    super.key,
    required this.status,
    this.isLoading = false,
    this.isSuccess = false,
  });

  final String status;
  final bool isLoading;
  final bool isSuccess;

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color iconColor;
    if (isSuccess) {
      icon = Icons.check_circle;
      iconColor = Colors.green;
    } else if (isLoading) {
      icon = Icons.info_outline;
      iconColor = Theme.of(context).colorScheme.primary;
    } else {
      icon = Icons.info_outline;
      iconColor = Theme.of(context).colorScheme.primary;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: iconColor),
                const SizedBox(width: 8),
                Text('Status',
                    style: Theme.of(context).textTheme.titleSmall),
                if (isLoading) ...[
                  const SizedBox(width: 12),
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(
              status,
              style: isSuccess
                  ? const TextStyle(
                      color: Colors.green, fontWeight: FontWeight.w600)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
