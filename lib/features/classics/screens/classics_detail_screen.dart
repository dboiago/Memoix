import 'package:flutter/material.dart';

import 'classics_entry_screen.dart';

class ClassicsDetailScreen extends StatelessWidget {
  const ClassicsDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const ClassicsEntryScreen(),
        ),
      );
    });
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
