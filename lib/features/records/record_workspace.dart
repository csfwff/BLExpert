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
    return Column(
      children: <Widget>[
        _PanelHeading(
          title: '会话记录',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '${filteredLogs.length}/${widget.logs.length} 条',
                style: AppTheme.textStylesOf(context).labelSmall,
              ),
              const SizedBox(width: 4),
              ToolIconButton(
                tooltip: '导出会话记录',
                onPressed: filteredLogs.isEmpty
                    ? null
                    : () => widget.onExport(filteredLogs),
                icon: const Icon(AppIcons.downloadOutlined, size: 18),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: SizedBox(
            height: 32,
            child: ToolTextField(
              key: const ValueKey<String>('session-record-filter'),
              controller: _filterController,
              label: '搜索文本或 HEX',
              hintText: '搜索文本或 HEX',
              showLabel: false,
              onChanged: (_) => setState(() {}),
              prefix: const Icon(AppIcons.search, size: 18),
              suffix: _filterController.text.isEmpty
                  ? null
                  : ToolIconButton(
                      tooltip: '清除筛选',
                      touchSize: 24,
                      onPressed: () {
                        _filterController.clear();
                        setState(() {});
                      },
                      icon: const Icon(AppIcons.clear, size: 18),
                    ),
            ),
          ),
        ),
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            children: <Widget>[
              _filterChip('全部', null),
              _filterChip('TX', SessionLogKind.sent),
              _filterChip('RX', SessionLogKind.received),
              _filterChip('SYS', SessionLogKind.system),
              _filterChip('ERR', SessionLogKind.error),
              _bookmarkFilterChip(),
            ],
          ),
        ),
        if (_metadataValues(
              (SessionLogRecord log) => log.characteristicId,
            ).isNotEmpty ||
            _metadataValues(
              (SessionLogRecord log) => log.commandName,
            ).isNotEmpty ||
            _metadataValues(
              (SessionLogRecord log) => log.transactionId,
            ).isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) =>
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
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
                    ],
                  ),
            ),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool compact =
                  constraints.maxWidth < _LogLine.compactBreakpoint;
              return filteredLogs.isEmpty
                  ? Center(child: Text(widget.l10n.noData))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
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

  Widget _filterChip(String label, SessionLogKind? kind) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: ToolSelectedButton(
      value: _kindFilter == kind,
      onChanged: (_) => setState(() => _kindFilter = kind),
      child: Text(label),
    ),
  );

  Widget _bookmarkFilterChip() => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: ToolSelectedButton(
      value: _bookmarksOnly,
      onChanged: (bool selected) => setState(() => _bookmarksOnly = selected),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(AppIcons.bookmarkOutline, size: 16),
          SizedBox(width: 4),
          Text('书签'),
        ],
      ),
    ),
  );

  Widget _metadataFilter({
    required String label,
    required String allLabel,
    required String? value,
    required List<String> values,
    required double maxWidth,
    required ValueChanged<String?> onChanged,
  }) => SizedBox(
    width: maxWidth < 520 ? maxWidth : 260,
    child: ToolSelect<String>(
      value: value ?? '',
      label: label,
      options: <ToolSelectOption<String>>[
        ToolSelectOption<String>(value: '', label: allLabel),
        for (final String item in values)
          ToolSelectOption<String>(value: item, label: item),
      ],
      onChanged: (String next) => onChanged(next.isEmpty ? null : next),
    ),
  );
}
