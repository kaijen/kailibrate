import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/providers.dart';
import '../../../core/services/api_key_service.dart';
import '../../../core/services/prompt_template_service.dart';
import '../../ai_generator/presentation/ai_generator_screen.dart'
    show TemplateEditorDialog;

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _exportLoading = false;
  bool _sharingExportLoading = false;
  PackageInfo? _packageInfo;

  // AI generator settings
  final _apiKeyController = TextEditingController();
  final _modelsController = TextEditingController();
  bool _hasApiKey = false;
  bool _apiKeyEditing = false;
  bool _apiKeyLoaded = false;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _packageInfo = info);
    });
    _loadAiSettings();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _modelsController.dispose();
    super.dispose();
  }

  Future<void> _loadAiSettings() async {
    final hasKey = await ApiKeyService.hasKey();
    final models = await ApiKeyService.getModelList();
    if (!mounted) return;

    setState(() {
      _hasApiKey = hasKey;
      _modelsController.text = models.join('\n');
      _apiKeyLoaded = true;
    });
  }

  Future<void> _saveApiKey() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      await ApiKeyService.deleteKey();
      if (mounted) setState(() { _hasApiKey = false; _apiKeyEditing = false; });
    } else {
      await ApiKeyService.saveKey(key);
      _apiKeyController.clear();
      if (mounted) setState(() { _hasApiKey = true; _apiKeyEditing = false; });
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API-Key gespeichert.')),
      );
    }
  }

  Future<void> _saveModels() async {
    final lines = _modelsController.text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    await ApiKeyService.saveModelList(lines);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Modellliste gespeichert.')),
      );
    }
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
      final filename = 'kailibrate_export_$date.json';

      await Share.shareXFiles(
        [
          XFile.fromData(
            utf8.encode(jsonString),
            name: filename,
            mimeType: 'application/json',
          ),
        ],
        subject: 'Kailibrate-Export',
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
      final filename = 'kailibrate_aufgaben_$date.json';

      await Share.shareXFiles(
        [
          XFile.fromData(
            utf8.encode(jsonString),
            name: filename,
            mimeType: 'application/json',
          ),
        ],
        subject: 'Kailibrate-Aufgaben',
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
    await Share.share(jsonString, subject: 'Kailibrate Debug-Info');
  }

  Future<void> _launchDocs() async {
    final info = await PackageInfo.fromPlatform();
    final version = info.version.replaceFirst(RegExp(r'^v'), '');
    final uri = Uri.parse('https://kaijen.github.io/kailibrate/$version/');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dokumentation konnte nicht geöffnet werden.')),
        );
      }
    }
  }

  Future<void> _showTemplateManager(BuildContext context) async {
    final templates = await PromptTemplateService.loadAll();
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (_) => _TemplateManagerDialog(templates: templates),
    );
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
              'KI-Generator',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          if (_apiKeyLoaded) ...[
            if (_hasApiKey && !_apiKeyEditing)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.key, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('API-Key gespeichert  ••••••••')),
                    TextButton(
                      onPressed: () => setState(() => _apiKeyEditing = true),
                      child: const Text('Ändern'),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _apiKeyController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'OpenRouter API-Key',
                          hintText: 'sk-or-…',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_apiKeyEditing)
                      TextButton(
                        onPressed: () => setState(() {
                          _apiKeyEditing = false;
                          _apiKeyController.clear();
                        }),
                        child: const Text('Abbrechen'),
                      ),
                    FilledButton(
                      onPressed: _saveApiKey,
                      child: const Text('Speichern'),
                    ),
                  ],
                ),
              ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Modelle',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.copy_outlined, size: 18),
                        tooltip: 'Liste kopieren',
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: _modelsController.text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('In Zwischenablage kopiert.')),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.info_outline, size: 18),
                        tooltip: 'Verfügbare Modelle auf openrouter.ai',
                        onPressed: () => launchUrl(
                          Uri.parse('https://openrouter.ai/models'),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    'Ein Modell pro Zeile. Erstes wird als Standard verwendet.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _modelsController,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      hintText:
                          'google/gemini-2.5-flash-preview\ngoogle/gemini-2.0-flash-lite-001\n…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: _saveModels,
                      child: const Text('Speichern'),
                    ),
                  ),
                ],
              ),
            ),
          ] else
            const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            ),
          ListTile(
            leading: const Icon(Icons.list_alt_outlined),
            title: const Text('Vorlagen verwalten'),
            subtitle: const Text('Prompt-Vorlagen ansehen und bearbeiten'),
            onTap: () => _showTemplateManager(context),
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
            subtitle: const Text('kaijen.github.io/kailibrate'),
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

// ---------------------------------------------------------------------------
// Template manager dialog (used from settings)
// ---------------------------------------------------------------------------

class _TemplateManagerDialog extends StatefulWidget {
  final List<PromptTemplate> templates;
  const _TemplateManagerDialog({required this.templates});

  @override
  State<_TemplateManagerDialog> createState() =>
      _TemplateManagerDialogState();
}

class _TemplateManagerDialogState extends State<_TemplateManagerDialog> {
  late List<PromptTemplate> _templates;

  @override
  void initState() {
    super.initState();
    _templates = List.from(widget.templates);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Vorlagen verwalten'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: _templates.length + 1,
          itemBuilder: (ctx, i) {
            if (i == _templates.length) {
              return ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Neue Vorlage erstellen'),
                onTap: () async {
                  final created = await showDialog<PromptTemplate>(
                    context: context,
                    builder: (_) => TemplateEditorDialog(
                      template: PromptTemplate(
                        id: PromptTemplateService.generateId(),
                        name: '',
                        body: '',
                      ),
                    ),
                  );
                  if (created != null && created.name.isNotEmpty) {
                    await PromptTemplateService.save(created);
                    final updated = await PromptTemplateService.loadAll();
                    setState(() => _templates = updated);
                  }
                },
              );
            }
            final t = _templates[i];
            return ListTile(
              title: Text(t.name),
              subtitle: t.isDefault ? const Text('Standardvorlage') : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () async {
                      final edited = await showDialog<PromptTemplate>(
                        context: context,
                        builder: (_) =>
                            TemplateEditorDialog(template: t),
                      );
                      if (edited != null && !t.isDefault) {
                        await PromptTemplateService.save(edited);
                        final updated =
                            await PromptTemplateService.loadAll();
                        setState(() => _templates = updated);
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    color: Theme.of(context).colorScheme.error,
                    onPressed: () async {
                      await PromptTemplateService.delete(t.id);
                      final updated =
                          await PromptTemplateService.loadAll();
                      setState(() => _templates = updated);
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Schließen'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

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

