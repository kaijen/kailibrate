import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
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
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _packageInfo = info);
    });
  }

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

    final availableTags = all
        .expand((v) => v.tagList)
        .toSet()
        .toList()
      ..sort();

    final choice = await showDialog<_ExportChoice>(
      context: context,
      builder: (ctx) =>
          _SharingFilterDialog(total: all.length, availableTags: availableTags),
    );
    if (choice == null || !mounted) return;

    setState(() => _sharingExportLoading = true);
    try {
      final data = await db.exportForSharing(
        category: choice.category,
        tags: choice.tags.isEmpty ? null : choice.tags,
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

  Future<void> _shareDebugInfo() async {
    final info = _packageInfo ?? await PackageInfo.fromPlatform();
    final devicePlugin = DeviceInfoPlugin();
    Map<String, dynamic> deviceMap;
    try {
      final android = await devicePlugin.androidInfo;
      deviceMap = {
        'platform': 'android',
        'version': android.version.release,
        'sdkInt': android.version.sdkInt,
        'manufacturer': android.manufacturer,
        'model': android.model,
        'brand': android.brand,
        'isPhysicalDevice': android.isPhysicalDevice,
      };
    } catch (_) {
      deviceMap = {
        'platform': Platform.operatingSystem,
        'version': Platform.operatingSystemVersion,
      };
    }

    final debugInfo = {
      'app': {
        'name': info.appName,
        'packageName': info.packageName,
        'version': info.version,
        'buildNumber': info.buildNumber,
      },
      'device': deviceMap,
      'exportedAt': DateTime.now().toIso8601String(),
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(debugInfo);
    await Share.share(jsonString, subject: 'Calibrate Debug-Info');
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
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Version'),
            subtitle: Text(_packageInfo != null
                ? '${_packageInfo!.version} (Build ${_packageInfo!.buildNumber})'
                : '…'),
            trailing: IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Debug-Info teilen',
              onPressed: _shareDebugInfo,
            ),
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

class _ExportChoice {
  final String? category; // null = alle
  final List<String> tags; // leer = alle
  const _ExportChoice({this.category, this.tags = const []});
}

class _SharingFilterDialog extends StatefulWidget {
  final int total;
  final List<String> availableTags;
  const _SharingFilterDialog(
      {required this.total, required this.availableTags});

  @override
  State<_SharingFilterDialog> createState() => _SharingFilterDialogState();
}

class _SharingFilterDialogState extends State<_SharingFilterDialog> {
  String? _category;
  final Set<String> _selectedTags = {};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Aufgaben teilen'),
      content: SingleChildScrollView(
        child: Column(
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
            if (widget.availableTags.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Tags'),
              const SizedBox(height: 4),
              const Text(
                'Kein Tag gewählt = alle Tags',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: widget.availableTags.map((tag) {
                  final selected = _selectedTags.contains(tag);
                  return FilterChip(
                    label: Text(tag),
                    selected: selected,
                    onSelected: (v) => setState(() {
                      if (v) {
                        _selectedTags.add(tag);
                      } else {
                        _selectedTags.remove(tag);
                      }
                    }),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            _ExportChoice(
              category: _category,
              tags: _selectedTags.toList(),
            ),
          ),
          child: const Text('Exportieren'),
        ),
      ],
    );
  }
}
