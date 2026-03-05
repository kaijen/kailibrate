import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers.dart';
import '../../../core/database/app_database.dart';
import 'prediction_card.dart';

enum FilterTab { all, pending, needsResolution, resolved }

class PredictionsScreen extends ConsumerStatefulWidget {
  final FilterTab initialFilter;

  const PredictionsScreen({
    super.key,
    this.initialFilter = FilterTab.all,
  });

  @override
  ConsumerState<PredictionsScreen> createState() => _PredictionsScreenState();
}

class _PredictionsScreenState extends ConsumerState<PredictionsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final Set<String> _selectedTags = {};
  final Set<int> _selectedIds = {};
  bool _sortReversed = false;
  bool _sortByDeadline = false;
  bool _showOverdueOnly = false;
  bool _filterUntagged = false;

  // Wird in build() aktualisiert – für Select-All ohne extra State.
  List<PredictionView> _currentPredictions = [];

  bool get _isSelecting => _selectedIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialFilter.index,
    );
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  void _startSelect(int id) => setState(() => _selectedIds.add(id));

  void _toggleSelect(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _clearSelection() => setState(() => _selectedIds.clear());

  bool get _allVisibleSelected {
    final tab = FilterTab.values[_tabController.index];
    final filtered = _filteredForTab(_currentPredictions, tab);
    if (filtered.isEmpty) return false;
    return filtered.every((p) => _selectedIds.contains(p.question.id));
  }

  void _toggleSelectAll() {
    final tab = FilterTab.values[_tabController.index];
    final filtered = _filteredForTab(_currentPredictions, tab);
    final allIds = filtered.map((p) => p.question.id);
    setState(() {
      if (_allVisibleSelected) {
        _selectedIds.removeAll(allIds);
      } else {
        _selectedIds.addAll(allIds);
      }
    });
  }

  List<PredictionView> _filteredForTab(
      List<PredictionView> predictions, FilterTab tab) {
    var list = switch (tab) {
      FilterTab.all => predictions.toList(),
      FilterTab.pending =>
        predictions.where((p) => p.status == PredictionStatus.pending).toList(),
      FilterTab.needsResolution => predictions
          .where((p) => p.status == PredictionStatus.needsResolution)
          .toList(),
      FilterTab.resolved => predictions
          .where((p) => p.status == PredictionStatus.resolved)
          .toList(),
    };
    if (_selectedTags.isNotEmpty || _filterUntagged) {
      list = list.where((p) {
        if (_filterUntagged && p.tagList.isEmpty) return true;
        return p.tagList.any(_selectedTags.contains);
      }).toList();
    }
    if (_showOverdueOnly && tab != FilterTab.resolved) {
      final now = DateTime.now();
      list = list
          .where((p) =>
              p.question.deadline != null &&
              p.question.deadline!.isBefore(now))
          .toList();
    }
    if (tab == FilterTab.resolved) {
      list.sort((a, b) {
        final cmp = a.resolution!.resolvedAt
            .compareTo(b.resolution!.resolvedAt);
        return _sortReversed ? cmp : -cmp; // default: newest first
      });
    } else if (tab == FilterTab.needsResolution && _sortByDeadline) {
      list.sort((a, b) {
        final da = a.question.deadline;
        final db = b.question.deadline;
        if (da == null && db == null) return 0;
        if (da == null) return 1;  // nulls always last
        if (db == null) return -1;
        final cmp = da.compareTo(db);
        return _sortReversed ? -cmp : cmp; // default: earliest deadline first
      });
    } else {
      list.sort((a, b) {
        final cmp =
            a.question.createdAt.compareTo(b.question.createdAt);
        return _sortReversed ? -cmp : cmp; // default: oldest first
      });
    }
    return list;
  }

  Set<String> _collectTags(List<PredictionView> predictions) {
    return {for (final p in predictions) ...p.tagList};
  }

  Future<void> _deleteSelected() async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Einträge löschen'),
        content: Text(
          '$count ${count == 1 ? 'Vorhersage wird' : 'Vorhersagen werden'} '
          'endgültig gelöscht. Diese Aktion kann nicht rückgängig gemacht werden.',
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

    final db = ref.read(appDatabaseProvider);
    await db.deleteQuestions(_selectedIds.toList());
    ref.invalidate(predictionsStreamProvider);
    setState(() => _selectedIds.clear());
  }

  Future<void> _editTags() async {
    final selected = _currentPredictions
        .where((p) => _selectedIds.contains(p.question.id))
        .toList();
    final suggestions = {for (final p in selected) ...p.tagList}.toList()
      ..sort();

    final newTags = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => _TagEditDialog(
        count: _selectedIds.length,
        suggestions: suggestions,
      ),
    );
    if (newTags == null || !mounted) return;

    final db = ref.read(appDatabaseProvider);
    for (final id in _selectedIds.toList()) {
      await db.updateQuestionTags(id, newTags);
    }
    ref.invalidate(predictionsStreamProvider);
    setState(() => _selectedIds.clear());
  }

  @override
  Widget build(BuildContext context) {
    final predictionsAsync = ref.watch(predictionsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        leading: _isSelecting
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Auswahl aufheben',
                onPressed: _clearSelection,
              )
            : null,
        title: _isSelecting
            ? Text('${_selectedIds.length} ausgewählt')
            : const Text('Vorhersagen'),
        actions: _isSelecting
            ? [
                IconButton(
                  icon: Icon(_allVisibleSelected
                      ? Icons.deselect
                      : Icons.select_all),
                  tooltip: _allVisibleSelected
                      ? 'Alle abwählen'
                      : 'Alle auswählen',
                  onPressed: _toggleSelectAll,
                ),
                IconButton(
                  icon: const Icon(Icons.label_outline),
                  tooltip: 'Tags bearbeiten',
                  onPressed: _editTags,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Auswahl löschen',
                  onPressed: _deleteSelected,
                ),
              ]
            : [
                if (_tabController.index == FilterTab.needsResolution.index)
                  IconButton(
                    icon: Icon(
                      _sortByDeadline ? Icons.event : Icons.event_outlined,
                      color: _sortByDeadline
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    tooltip: _sortByDeadline
                        ? 'Nach Erstelldatum sortieren'
                        : 'Nach Fälligkeitsdatum sortieren',
                    onPressed: () =>
                        setState(() => _sortByDeadline = !_sortByDeadline),
                  ),
                IconButton(
                  icon: Icon(_sortReversed
                      ? Icons.arrow_upward
                      : Icons.arrow_downward),
                  tooltip: 'Sortierung umkehren',
                  onPressed: () =>
                      setState(() => _sortReversed = !_sortReversed),
                ),
              ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Alle'),
            Tab(text: 'Offen'),
            Tab(text: 'Ausstehend'),
            Tab(text: 'Aufgelöst'),
          ],
        ),
      ),
      body: predictionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (predictions) {
          _currentPredictions = predictions;
          final allTags = _collectTags(predictions);
          final hasUntagged = predictions.any((p) => p.tagList.isEmpty);
          _selectedTags.removeWhere((tag) => !allTags.contains(tag));
          return Column(
            children: [
              _buildTagFilter(allTags, hasUntagged: hasUntagged),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: FilterTab.values.map((tab) {
                    return _PredictionList(
                      predictions: _filteredForTab(predictions, tab),
                      selectedIds: _selectedIds,
                      onToggleSelect: _toggleSelect,
                      onStartSelect: _startSelect,
                    );
                  }).toList(),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: _isSelecting
          ? null
          : FloatingActionButton(
              onPressed: () => context.push('/new'),
              tooltip: 'Neue Vorhersage',
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildTagFilter(Set<String> allTags, {required bool hasUntagged}) {
    final tags = allTags.toList()..sort();
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('Überfällig'),
              avatar: const Icon(Icons.warning_amber, size: 16),
              selected: _showOverdueOnly,
              onSelected: (_) =>
                  setState(() => _showOverdueOnly = !_showOverdueOnly),
              visualDensity: VisualDensity.compact,
            ),
          ),
          if (hasUntagged)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: const Text('Ohne Tag'),
                avatar: const Icon(Icons.label_off_outlined, size: 16),
                selected: _filterUntagged,
                onSelected: (_) =>
                    setState(() => _filterUntagged = !_filterUntagged),
                visualDensity: VisualDensity.compact,
                selectedColor:
                    Theme.of(context).colorScheme.secondaryContainer,
                checkmarkColor:
                    Theme.of(context).colorScheme.onSecondaryContainer,
                side: BorderSide(
                  color: Theme.of(context)
                      .colorScheme
                      .secondary
                      .withValues(alpha: 0.6),
                ),
              ),
            ),
          for (final tag in tags)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(tag),
                selected: _selectedTags.contains(tag),
                onSelected: (_) => _toggleTag(tag),
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }
}

class _PredictionList extends StatelessWidget {
  final List<PredictionView> predictions;
  final Set<int> selectedIds;
  final void Function(int id) onToggleSelect;
  final void Function(int id) onStartSelect;

  const _PredictionList({
    required this.predictions,
    required this.selectedIds,
    required this.onToggleSelect,
    required this.onStartSelect,
  });

  bool get _isSelecting => selectedIds.isNotEmpty;

  void _handleTap(BuildContext context, PredictionView prediction) {
    if (_isSelecting) {
      onToggleSelect(prediction.question.id);
      return;
    }
    context.push('/prediction/${prediction.question.id}');
  }

  @override
  Widget build(BuildContext context) {
    if (predictions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'Keine Vorhersagen',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: predictions.length,
      itemBuilder: (context, index) {
        final prediction = predictions[index];
        final id = prediction.question.id;
        return PredictionCard(
          prediction: prediction,
          selected: _isSelecting ? selectedIds.contains(id) : null,
          onTap: () => _handleTap(context, prediction),
          onLongPress: _isSelecting ? null : () => onStartSelect(id),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Tag-Edit-Dialog
// ---------------------------------------------------------------------------

class _TagEditDialog extends StatefulWidget {
  final int count;
  final List<String> suggestions;

  const _TagEditDialog({required this.count, required this.suggestions});

  @override
  State<_TagEditDialog> createState() => _TagEditDialogState();
}

class _TagEditDialogState extends State<_TagEditDialog> {
  final _controller = TextEditingController();
  final List<String> _tags = [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addTag(String tag) {
    final t = tag.trim();
    if (t.isNotEmpty && !_tags.contains(t)) {
      setState(() => _tags.add(t));
    }
  }

  void _addFromController() {
    for (final part in _controller.text.split(',')) {
      _addTag(part);
    }
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Tags für ${widget.count} '
          '${widget.count == 1 ? 'Vorhersage' : 'Vorhersagen'} setzen'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Die eingegebenen Tags ersetzen die bisherigen Tags '
              'aller ausgewählten Vorhersagen.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            if (_tags.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _tags
                    .map((tag) => InputChip(
                          label: Text(tag),
                          onDeleted: () =>
                              setState(() => _tags.remove(tag)),
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(),
              ),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Tag eingeben (kommagetrennt) + Enter',
                isDense: true,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _addFromController,
                ),
              ),
              onSubmitted: (_) => _addFromController(),
              textInputAction: TextInputAction.done,
            ),
            if (widget.suggestions.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Vorhandene Tags:',
                  style: TextStyle(fontSize: 12)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: widget.suggestions
                    .map((tag) => ActionChip(
                          label: Text(tag),
                          onPressed: () => _addTag(tag),
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(),
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
          onPressed: () {
            _addFromController();
            Navigator.of(context).pop(_tags);
          },
          child: const Text('Setzen'),
        ),
      ],
    );
  }
}
