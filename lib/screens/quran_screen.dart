import 'package:flutter/material.dart';

class QuranScreen extends StatelessWidget {
  const QuranScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quran Plan'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 30,
        itemBuilder: (context, index) {
          final day = index + 1;
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              title: Text('Day $day'),
              subtitle: const Text('1 Juz (placeholder)'),
              trailing: Icon(
                Icons.check_circle_outline,
                color: theme.colorScheme.primary,
              ),
            ),
          );
        },
      ),
    );
  }
}
