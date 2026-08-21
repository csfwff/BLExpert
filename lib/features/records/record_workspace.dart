part of '../home/home_screen.dart';

class _RecordWorkspace extends StatefulWidget {
  const _RecordWorkspace({
    required this.logs,
    required this.l10n,
    required this.onExport,
    required this.onToggleBookmark,
  });

  final List<SessionLogRecord> logs;
  final AppLocalizations l10n;
  final ValueChanged<List<SessionLogRecord>> onExport;
  final ValueChanged<SessionLogRecord> onToggleBookmark;

  @override
  State<_RecordWorkspace> createState() => _RecordWorkspaceState();
}

class _RecordWorkspaceState extends State<_RecordWorkspace> {
  final TextEditingController _filterController = TextEditingController();
  SessionLogKind? _kindFilter;
  String? _characteristicFilter;
  String? _commandFilter;
  String? _transactionFilter;
  bool _bookmarksOnly = false;

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  List<SessionLogRecord> _filteredLogs() {
    final String query = _filterController.text.trim().toLowerCase();
    return widget.logs
        .where((SessionLogRecord log) {
          if (_kindFilter != null && log.kind != _kindFilter) return false;
          if (_characteristicFilter != null &&
              log.characteristicId != _characteristicFilter) {
            return false;
          }
          if (_commandFilter != null && log.commandName != _commandFilter) {
            return false;
          }
          if (_transactionFilter != null &&
              log.transactionId != _transactionFilter) {
            return false;
          }
          if (_bookmarksOnly && !log.bookmarked) return false;
          if (query.isEmpty) return true;
          final String payload = log.message ?? _toHex(log.data);
          return payload.toLowerCase().contains(query) ||
              log.kind.name.toLowerCase().contains(query) ||
              (log.characteristicId?.toLowerCase().contains(query) ?? false) ||
              (log.commandName?.toLowerCase().contains(query) ?? false) ||
              (log.transactionId?.toLowerCase().contains(query) ?? false);
        })
        .toList(growable: false);
  }

  List<String> _metadataValues(String? Function(SessionLogRecord log) valueOf) {
    final List<String> values =
        widget.logs
            .map(valueOf)
            .whereType<String>()
            .where((String value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return values;
  }

  @override
  Widget build(BuildContext context) {
    final List<SessionLogRecord> filteredLogs = _filteredLogs();
    final bool hasMetadataFilters =
        _metadataValues(
          (SessionLogRecord log) => log.characteristicId,
        ).isNotEmpty ||
        _metadataValues((SessionLogRecord log) => log.commandName).isNotEmpty ||
        _metadataValues((SessionLogRecord log) => log.transactionId).isNotEmpty;
    return Column(
      children: <Widget>[
        const _PanelHeading(title: '会话记录'),
        _RecordFilterToolbar(
          filterController: _filterController,
          kindFilter: _kindFilter,
          bookmarksOnly: _bookmarksOnly,
          filteredCount: filteredLogs.length,
          totalCount: widget.logs.length,
          onExport: filteredLogs.isEmpty
              ? null
              : () => widget.onExport(filteredLogs),
          onFilterChanged: () => setState(() {}),
          onKindChanged: (SessionLogKind? value) =>
              setState(() => _kindFilter = value),
          onBookmarksOnlyChanged: (bool value) =>
              setState(() => _bookmarksOnly = value),
        ),
        if (hasMetadataFilters)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final List<Widget> metadataFilters = <Widget>[
                  if (_metadataValues(
                    (SessionLogRecord log) => log.characteristicId,
                  ).isNotEmpty)
                    _metadataFilter(
                      label: '特征',
                      allLabel: '全部特征',
                      value: _characteristicFilter,
                      values: _metadataValues(
                        (SessionLogRecord log) => log.characteristicId,
                      ),
                      maxWidth: constraints.maxWidth,
                      onChanged: (String? value) =>
                          setState(() => _characteristicFilter = value),
                    ),
                  if (_metadataValues(
                    (SessionLogRecord log) => log.commandName,
                  ).isNotEmpty)
                    _metadataFilter(
                      label: '指令',
                      allLabel: '全部指令',
                      value: _commandFilter,
                      values: _metadataValues(
                        (SessionLogRecord log) => log.commandName,
                      ),
                      maxWidth: constraints.maxWidth,
                      onChanged: (String? value) =>
                          setState(() => _commandFilter = value),
                    ),
                  if (_metadataValues(
                    (SessionLogRecord log) => log.transactionId,
                  ).isNotEmpty)
                    _metadataFilter(
                      label: '事务',
                      allLabel: '全部事务',
                      value: _transactionFilter,
                      values: _metadataValues(
                        (SessionLogRecord log) => log.transactionId,
                      ),
                      maxWidth: constraints.maxWidth,
                      onChanged: (String? value) =>
                          setState(() => _transactionFilter = value),
                    ),
                ];
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    alignment: WrapAlignment.start,
                    runAlignment: WrapAlignment.start,
                    spacing: 8,
                    runSpacing: 8,
                    children: metadataFilters,
                  ),
                );
              },
            ),
          ),
        if (hasMetadataFilters)
          const shad.Divider(
            key: ValueKey<String>('session-record-metadata-divider'),
            height: 1,
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool compact =
                  constraints.maxWidth < _LogLine.compactBreakpoint;
              return filteredLogs.isEmpty
                  ? Center(child: Text(widget.l10n.noData))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                      itemCount: filteredLogs.length,
                      separatorBuilder: (_, _) => const shad.Divider(height: 1),
                      itemBuilder: (_, int index) => _LogLine(
                        entry: filteredLogs[index],
                        l10n: widget.l10n,
                        compact: compact,
                        onToggleBookmark: widget.onToggleBookmark,
                      ),
                    );
            },
          ),
        ),
      ],
    );
  }

  Widget _metadataFilter({
    required String label,
    required String allLabel,
    required String? value,
    required List<String> values,
    required double maxWidth,
    required ValueChanged<String?> onChanged,
  }) => SizedBox(
    width: maxWidth < 520 ? maxWidth : 220,
    height: 24,
    child: Row(
      children: <Widget>[
        Text(label, style: AppTheme.textStylesOf(context).labelSmall),
        const SizedBox(width: 6),
        Expanded(
          child: ToolSelect<String>(
            value: value ?? '',
            label: label,
            showLabel: false,
            options: <ToolSelectOption<String>>[
              ToolSelectOption<String>(value: '', label: allLabel),
              for (final String item in values)
                ToolSelectOption<String>(value: item, label: item),
            ],
            onChanged: (String next) => onChanged(next.isEmpty ? null : next),
          ),
        ),
      ],
    ),
  );
}

class _RecordFilterToolbar extends StatelessWidget {
  const _RecordFilterToolbar({
    required this.filterController,
    required this.kindFilter,
    required this.bookmarksOnly,
    required this.filteredCount,
    required this.totalCount,
    required this.onExport,
    required this.onFilterChanged,
    required this.onKindChanged,
    required this.onBookmarksOnlyChanged,
  });

  final TextEditingController filterController;
  final SessionLogKind? kindFilter;
  final bool bookmarksOnly;
  final int filteredCount;
  final int totalCount;
  final VoidCallback? onExport;
  final VoidCallback onFilterChanged;
  final ValueChanged<SessionLogKind?> onKindChanged;
  final ValueChanged<bool> onBookmarksOnlyChanged;

  @override
  Widget build(BuildContext context) {
    final List<Widget> filters = <Widget>[
      _FilterChip(
        label: '全部',
        selected: kindFilter == null,
        onPressed: () => onKindChanged(null),
      ),
      _FilterChip(
        label: 'TX',
        selected: kindFilter == SessionLogKind.sent,
        onPressed: () => onKindChanged(SessionLogKind.sent),
      ),
      _FilterChip(
        label: 'RX',
        selected: kindFilter == SessionLogKind.received,
        onPressed: () => onKindChanged(SessionLogKind.received),
      ),
      _FilterChip(
        label: 'SYS',
        selected: kindFilter == SessionLogKind.system,
        onPressed: () => onKindChanged(SessionLogKind.system),
      ),
      _FilterChip(
        label: 'ERR',
        selected: kindFilter == SessionLogKind.error,
        onPressed: () => onKindChanged(SessionLogKind.error),
      ),
      _FilterChip(
        label: '书签',
        icon: AppIcons.bookmarkOutline,
        selected: bookmarksOnly,
        onPressed: () => onBookmarksOnlyChanged(!bookmarksOnly),
      ),
    ];
    final Widget statusActions = _RecordToolbarStatus(
      filteredCount: filteredCount,
      totalCount: totalCount,
      onExport: onExport,
    );
    final Widget search = SizedBox(
      height: 32,
      child: ToolTextField(
        key: const ValueKey<String>('session-record-filter'),
        controller: filterController,
        label: '搜索文本或 HEX',
        hintText: '搜索文本或 HEX',
        showLabel: false,
        onChanged: (_) => onFilterChanged(),
        prefix: const Icon(AppIcons.search, size: 16),
        suffix: filterController.text.isEmpty
            ? null
            : ToolIconButton(
                tooltip: '清除筛选',
                touchSize: 24,
                onPressed: () {
                  filterController.clear();
                  onFilterChanged();
                },
                icon: const Icon(AppIcons.clear, size: 16),
              ),
      ),
    );
    return Container(
      key: const ValueKey<String>('session-record-filter-toolbar'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.colorsOf(context).border),
        ),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          if (constraints.maxWidth < 720) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                search,
                const SizedBox(height: 6),
                SizedBox(
                  height: 32,
                  child: ListView(
                    key: const ValueKey<String>('session-record-kind-filters'),
                    scrollDirection: Axis.horizontal,
                    children: filters
                        .followedBy(<Widget>[statusActions])
                        .map(
                          (Widget filter) => Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: filter,
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ],
            );
          }
          return Row(
            children: <Widget>[
              SizedBox(width: 280, child: search),
              const SizedBox(width: 12),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(spacing: 4, children: filters),
                ),
              ),
              const SizedBox(width: 8),
              statusActions,
            ],
          );
        },
      ),
    );
  }
}

class _RecordToolbarStatus extends StatelessWidget {
  const _RecordToolbarStatus({
    required this.filteredCount,
    required this.totalCount,
    required this.onExport,
  });

  final int filteredCount;
  final int totalCount;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) => Row(
    key: const ValueKey<String>('session-record-toolbar-actions'),
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Text(
        '$filteredCount/$totalCount 条',
        style: AppTheme.textStylesOf(context).labelSmall,
      ),
      const SizedBox(width: 4),
      ToolIconButton(
        tooltip: '导出会话记录',
        onPressed: onExport,
        touchSize: 32,
        icon: const Icon(AppIcons.downloadOutlined, size: 18),
      ),
    ],
  );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => ToolSelectedButton(
    value: selected,
    onChanged: (_) => onPressed(),
    minHeight: 32,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, size: 14),
          const SizedBox(width: 4),
        ],
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    ),
  );
}
