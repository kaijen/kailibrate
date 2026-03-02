import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _exportLoading = false;
  bool _sharingExportLoading = false;

  Future<void> _export() async {
    setState(() => _exportLoading = true);
    try {
      final db = ref.read(appDatabaseProvider);
      final data = await db.exportAll();
      final jsonString = const JsonEncoder.withIndent('  ').convert(data);

      final now = DateTime.now();
      final date =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final filename = 'calibrate_export_$date.json';

      await Share.shareXFiles(
        [
          XFile.fromData(
            utf8.encode(jsonString),
            name: filename,
            mimeType: 'application/json',
          ),
        ],
        subject: 'Calibrate-Export',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export fehlgeschlagen: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exportLoading = false);
    }
  }

  Future<void> _exportForSharing() async {
    final db = ref.read(appDatabaseProvider);
    final all = await db.getResolvedPredictionViews();
    if (!mounted) return;

    if (all.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keine aufgelösten Vorhersagen vorhanden.')),
      );
      return;
    }

    final selectedCategory = await showDialog<_CategoryChoice>(
      context: context,
      builder: (ctx) => _SharingFilterDialog(total: all.length),
    );
    if (selectedCategory == null || !mounted) return;

    setState(() => _sharingExportLoading = true);
    try {
      final data = await db.exportForSharing(
        category: selectedCategory.value,
      );
      final jsonString = const JsonEncoder.withIndent('  ').convert(data);

      final now = DateTime.now();
      final date =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final filename = 'calibrate_aufgaben_$date.json';

      await Share.shareXFiles(
        [
          XFile.fromData(
            utf8.encode(jsonString),
            name: filename,
            mimeType: 'application/json',
          ),
        ],
        subject: 'Calibrate-Aufgaben',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export fehlgeschlagen: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharingExportLoading = false);
    }
  }

  Future<void> _launchDocs() async {
    final info = await PackageInfo.fromPlatform();
    final version = info.version.replaceFirst(RegExp(r'^v'), '');
    final uri = Uri.parse('https://kaijen.github.io/calibrate/$version/');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dokumentation konnte nicht geöffnet werden.')),
        );
      }
    }
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Datenbank zurücksetzen?'),
        content: const Text(
          'Alle Vorhersagen, Schätzungen und Auflösungen werden unwiderruflich gelöscht.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final db = ref.read(appDatabaseProvider);
    await db.resetDatabase();
    ref.invalidate(predictionsStreamProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Datenbank zurückgesetzt.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              'Daten',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Daten exportieren'),
            subtitle: const Text('Alle Vorhersagen als JSON-Datei teilen'),
            trailing: _exportLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: _exportLoading ? null : _export,
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Aufgaben teilen'),
            subtitle: const Text(
                'Aufgelöste Fragen ohne eigene Schätzungen exportieren'),
            trailing: _sharingExportLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: _sharingExportLoading ? null : _exportForSharing,
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'Hilfe',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: const Text('Dokumentation'),
            subtitle: const Text('kaijen.github.io/calibrate'),
            onTap: _launchDocs,
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'Gefahrenzone',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: Icon(Icons.delete_forever, color: colorScheme.error),
            title: Text(
              'Datenbank zurücksetzen',
              style: TextStyle(color: colorScheme.error),
            ),
            subtitle: const Text('Löscht alle Vorhersagen unwiderruflich'),
            onTap: _confirmReset,
          ),
        ],
      ),
    );
  }
}

class _CategoryChoice {
  final String? value; // null = alle
  const _CategoryChoice(this.value);
}

class _SharingFilterDialog extends StatefulWidget {
  final int total;
  const _SharingFilterDialog({required this.total});

  @override
  State<_SharingFilterDialog> createState() => _SharingFilterDialogState();
}

class _SharingFilterDialogState extends State<_SharingFilterDialog> {
  String? _category; // null = alle

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Aufgaben teilen'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.total} aufgelöste Vorhersagen verfügbar.\n'
            'Eigene Schätzungen werden nicht exportiert.',
          ),
          const SizedBox(height: 16),
          const Text('Kategorie'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Alle'),
                selected: _category == null,
                onSelected: (_) => setState(() => _category = null),
              ),
              ChoiceChip(
                label: const Text('Epistemisch'),
                selected: _category == 'epistemic',
                onSelected: (_) =>
                    setState(() => _category = 'epistemic'),
              ),
              ChoiceChip(
                label: const Text('Aleatorisch'),
                selected: _category == 'aleatory',
                onSelected: (_) =>
                    setState(() => _category = 'aleatory'),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(_CategoryChoice(_category)),
          child: const Text('Exportieren'),
        ),
      ],
    );
  }
}
