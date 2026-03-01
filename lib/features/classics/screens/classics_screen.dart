import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/integrity_service.dart';
import '../../../app/routes/router.dart';

class ClassicsScreen extends ConsumerStatefulWidget {
  const ClassicsScreen({super.key});

  @override
  ConsumerState<ClassicsScreen> createState() => _ClassicsScreenState();
}

class _ClassicsScreenState extends ConsumerState<ClassicsScreen> {
  List<Map<String, dynamic>>? _entries;
  String? _recordRef;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final data = await IntegrityService.resolveIndexData('classics_index');
    final recordRef = await IntegrityService.resolveLegacyValue('legacy_record_ref');
    if (mounted) {
      setState(() {
        _entries = data;
        _recordRef = recordRef;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Classics'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries == null || _entries!.isEmpty
              ? Center(
                  child: Text(
                    'No entries available.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _entries!.length,
                  itemBuilder: (context, index) {
                    final entry = _entries![index];
                    final name = entry['name'] as String? ?? '';
                    final cuisine = entry['cuisine'] as String? ?? '';
                    final region = entry['region'] as String? ?? '';
                    final isTarget = _recordRef != null && name == _recordRef;

                    return ListTile(
                      title: Text(name),
                      subtitle: Text('$cuisine · $region'),
                      trailing: isTarget
                          ? null
                          : const Icon(Icons.heart_broken),
                      onTap: isTarget
                          ? () => AppRoutes.toClassicsEntry(context)
                          : null,
                    );
                  },
                ),
    );
  }
}
