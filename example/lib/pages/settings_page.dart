import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:dolphin/dolphin.dart';

import '../fake_server.dart';

/// Everything an app usually needs around a guide: rewatch, reset a section,
/// turn tips off, see progress, and sync with a server.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Dolphin.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Guide settings')),
      body: ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          final summaries = c.summaries().values.toList()
            ..sort((a, b) => a.scope.compareTo(b.scope));
          return ListView(
            children: [
              SwitchListTile(
                title: const Text('Show tips automatically'),
                value: c.enabled,
                onChanged: c.setEnabled,
              ),
              ListTile(
                leading: const Icon(Icons.replay),
                title: const Text('Rewatch the whole walkthrough'),
                onTap: () async {
                  await c.resetAll();
                  if (context.mounted) Navigator.pop(context);
                },
              ),
              const Divider(),
              const ListTile(title: Text('Sections')),
              for (final s in summaries)
                ListTile(
                  title: Text(s.scope),
                  subtitle: Text(
                      '${s.status.name} · ${s.seen.length}/${s.total} seen'
                      '${s.pending.isEmpty ? '' : ' · pending: ${s.pending.join(', ')}'}'),
                  trailing: TextButton(
                    onPressed: () => c.resetScope(s.scope),
                    child: const Text('Reset'),
                  ),
                ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.upload),
                title: const Text('Show progress JSON (what you store)'),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (_) => AlertDialog(
                    content: SingleChildScrollView(
                      child: SelectableText(const JsonEncoder.withIndent('  ')
                          .convert(c.exportProgress())),
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.phone_android),
                title: const Text('Simulate a new device'),
                subtitle: const Text(
                    'Clear local data, then restore from the server copy'),
                onTap: () async {
                  final server = await FakeServer.instance.fetch();
                  await c.resetAll(restart: false);
                  await c.importProgress(server,
                      useProvidedData: true,
                      updateLocal: true,
                      strategy: MergeStrategy.remoteWins);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Restored: only unseen tips will show')));
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
