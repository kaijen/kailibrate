import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/providers.dart';
import '../../../core/services/api_key_service.dart';
import '../../../core/services/backup_service.dart';
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
  bool _backupLoading = false;
  bool _restoreLoading = false;
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

  /// Shows a password input dialog. If [confirm] is true, a second field for
  /// confirmation is shown. Returns the entered password, or null if cancelled.
  Future<String?> _showPasswordDialog({required bool confirm}) async {
    final ctrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(confirm ? 'Backup erstellen' : 'Backup wiederherstellen'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: ctrl,
                  obscureText: true,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Passwort',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Passwort eingeben' : null,
                ),
                if (confirm) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirmCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Passwort bestätigen',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v != ctrl.text
                        ? 'Passwörter stimmen nicht überein'
                        : null,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(ctx).pop(ctrl.text);
                }
              },
              child: const Text('Weiter'),
            ),
          ],
        ),
      ),
    );

    ctrl.dispose();
    confirmCtrl.dispose();
    return result;
  }

  Future<void> _createBackup() async {
    final password = await _showPasswordDialog(confirm: true);
    if (password == null || !mounted) return;

    setState(() => _backupLoading = true);
    try {
      final db = ref.read(appDatabaseProvider);
      final json = await BackupService.createBackup(db: db, password: password);

      final now = DateTime.now();
      final date =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final filename = 'kailibrate_backup_$date.kbak';

      await Share.shareXFiles(
        [
          XFile.fromData(
            utf8.encode(json),
            name: filename,
            mimeType: 'application/json',
          ),
        ],
        subject: 'Kailibrate-Backup',
      );
    } on BackupException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup fehlgeschlagen: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _backupLoading = false);
    }
  }

  Future<void> _restoreBackup() async {
    // Step 1: pick file
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['kbak', 'json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;

    final file = result.files.first;
    if (file.bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Datei konnte nicht gelesen werden.')),
      );
      return;
    }

    // Step 2: confirm data reset
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Backup wiederherstellen?'),
        content: const Text(
          'Alle vorhandenen Daten werden unwiderruflich überschrieben.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Wiederherstellen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Step 3: password
    final password = await _showPasswordDialog(confirm: false);
    if (password == null || !mounted) return;

    setState(() => _restoreLoading = true);
    try {
      final db = ref.read(appDatabaseProvider);
      final backupJson = utf8.decode(file.bytes!);
      await BackupService.restoreBackup(
          db: db, backupJson: backupJson, password: password);

      ref.invalidate(predictionsStreamProvider);
      await _loadAiSettings();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup erfolgreich wiederhergestellt.')),
        );
      }
    } on BackupException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Wiederherstellung fehlgeschlagen: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _restoreLoading = false);
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

  Future<void> _showTagManager(BuildContext context) async {
    final db = ref.read(appDatabaseProvider);
    final all = await db.getAllPredictionViews();
    if (!context.mounted) return;

    final tags = {for (final v in all) ...v.tagList}.toList()..sort();

    await showDialog<void>(
      context: context,
      builder: (_) => _TagManagerDialog(
        tags: tags,
        onDelete: (tag) async {
          await db.deleteTagGlobally(tag);
          ref.invalidate(predictionsStreamProvider);
        },
        onRename: (oldTag, newTag) async {
          await db.renameTagGlobally(oldTag, newTag);
          ref.invalidate(predictionsStreamProvider);
        },
      ),
    );
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
            leading: const Icon(Icons.lock_outlined),
            title: const Text('Verschlüsseltes Backup erstellen'),
            subtitle: const Text(
                'Alle Daten inkl. Konfiguration mit Passwort sichern'),
            trailing: _backupLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: _backupLoading ? null : _createBackup,
          ),
          ListTile(
            leading: const Icon(Icons.lock_open_outlined),
            title: const Text('Backup wiederherstellen'),
            subtitle: const Text('Verschlüsselte .kbak-Datei importieren'),
            trailing: _restoreLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: _restoreLoading ? null : _restoreBackup,
          ),
          ListTile(
            leading: const Icon(Icons.label_outlined),
            title: const Text('Tags verwalten'),
            subtitle: const Text('Tags global umbenennen oder löschen'),
            onTap: () => _showTagManager(context),
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
// Tag manager dialog
// ---------------------------------------------------------------------------

class _TagManagerDialog extends StatefulWidget {
  final List<String> tags;
  final Future<void> Function(String tag) onDelete;
  final Future<void> Function(String oldTag, String newTag) onRename;

  const _TagManagerDialog({
    required this.tags,
    required this.onDelete,
    required this.onRename,
  });

  @override
  State<_TagManagerDialog> createState() => _TagManagerDialogState();
}

class _TagManagerDialogState extends State<_TagManagerDialog> {
  late List<String> _tags;

  @override
  void initState() {
    super.initState();
    _tags = List.from(widget.tags);
  }

  Future<void> _confirmRename(String tag) async {
    final controller = TextEditingController(text: tag);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tag umbenennen'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Neuer Name'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Umbenennen'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newName == null || newName.isEmpty || newName == tag || !mounted) return;

    await widget.onRename(tag, newName);
    setState(() {
      final i = _tags.indexOf(tag);
      if (i != -1) _tags[i] = newName;
      _tags.sort();
    });
  }

  Future<void> _confirmDelete(String tag) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tag löschen'),
        content: Text(
          'Der Tag „$tag" wird bei allen Vorhersagen entfernt. '
          'Diese Aktion kann nicht rückgängig gemacht werden.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await widget.onDelete(tag);
    setState(() => _tags.remove(tag));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tags verwalten'),
      content: _tags.isEmpty
          ? const Text('Keine Tags vorhanden.')
          : SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _tags.length,
                itemBuilder: (ctx, i) {
                  final tag = _tags[i];
                  return ListTile(
                    leading: const Icon(Icons.label_outline),
                    title: Text(tag),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Tag umbenennen',
                          onPressed: () => _confirmRename(tag),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          color: Theme.of(context).colorScheme.error,
                          tooltip: 'Tag löschen',
                          onPressed: () => _confirmDelete(tag),
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

