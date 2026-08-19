part of '../home/home_screen.dart';

class _LogLine extends StatelessWidget {
  const _LogLine({
    required this.entry,
    required this.l10n,
    this.selected = false,
    this.onTap,
    this.onToggleBookmark,
  });
  final SessionLogRecord entry;
  final AppLocalizations l10n;
  final bool selected;
  final VoidCallback? onTap;
  final ValueChanged<SessionLogRecord>? onToggleBookmark;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color color = switch (entry.kind) {
      SessionLogKind.received => colors.tertiary,
      SessionLogKind.sent => colors.primary,
      SessionLogKind.system => Theme.of(context).colorScheme.secondary,
      SessionLogKind.error => Theme.of(context).colorScheme.error,
    };
    final String payload = entry.message ?? _toHex(entry.data);
    final String timestamp = entry.timestamp.toIso8601String().split('T').last;
    final Widget? bookmarkButton = onToggleBookmark == null
        ? null
        : ToolIconButton(
            tooltip: entry.bookmarked ? '取消书签' : '添加书签',
            onPressed: () => onToggleBookmark!(entry),
            icon: Icon(
              entry.bookmarked ? Icons.bookmark : Icons.bookmark_outline,
              size: 19,
              color: entry.bookmarked ? colors.primary : null,
            ),
            touchSize: 44,
          );
    final Widget? detailsButton = onTap == null
        ? null
        : ToolIconButton(
            tooltip: l10n.viewLogDetails,
            onPressed: onTap,
            icon: const Icon(Icons.subject_outlined, size: 18),
            touchSize: 44,
          );
    return Semantics(
      label: '${entry.directionLabel(l10n)} $timestamp，$payload',
      child: GestureDetector(
        key: ValueKey<String>('console-log-${entry.kind.name}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
          decoration: BoxDecoration(
            color: selected
                ? colors.primaryContainer.withValues(alpha: 0.45)
                : null,
            border: Border(left: BorderSide(color: color, width: 2)),
          ),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool compact = constraints.maxWidth < 520;
              final Widget direction = Container(
                width: 34,
                padding: const EdgeInsets.symmetric(vertical: 2),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  entry.shortDirection,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              );
              final Widget content = SelectableText(
                payload,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.45,
                  color: entry.kind == SessionLogKind.error ? color : null,
                ),
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          timestamp,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: colors.outline,
                          ),
                        ),
                        const SizedBox(width: 8),
                        direction,
                        if (entry.characteristicId != null) ...<Widget>[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _shortUuid(entry.characteristicId!),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                        if (entry.data.isNotEmpty) ...<Widget>[
                          const SizedBox(width: 8),
                          Text(
                            '${entry.data.length} B',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                        if (bookmarkButton != null) ...<Widget>[
                          const Spacer(),
                          ?detailsButton,
                          bookmarkButton,
                        ] else if (detailsButton != null) ...<Widget>[
                          const Spacer(),
                          detailsButton,
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    content,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 90,
                    child: Text(
                      timestamp,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: colors.outline,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  direction,
                  if (entry.characteristicId != null) ...<Widget>[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 66,
                      child: Text(
                        _shortUuid(entry.characteristicId!),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                  if (entry.data.isNotEmpty) ...<Widget>[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 32,
                      child: Text(
                        '${entry.data.length} B',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ],
                  const SizedBox(width: 10),
                  Expanded(child: content),
                  ?detailsButton,
                  ?bookmarkButton,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

extension _SessionLogRecordLabels on SessionLogRecord {
  String directionLabel(AppLocalizations l10n) => switch (kind) {
    SessionLogKind.received => l10n.received,
    SessionLogKind.sent => l10n.sendData,
    SessionLogKind.system => l10n.system,
    SessionLogKind.error => l10n.error,
  };

  String get shortDirection => switch (kind) {
    SessionLogKind.received => 'RX',
    SessionLogKind.sent => 'TX',
    SessionLogKind.system => 'SYS',
    SessionLogKind.error => 'ERR',
  };
}

List<int>? _parseHex(String value) {
  final compact = value.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
  if (compact.isEmpty || compact.length.isOdd) return null;
  return <int>[
    for (var i = 0; i < compact.length; i += 2)
      int.parse(compact.substring(i, i + 2), radix: 16),
  ];
}

IconData _themeModeIcon(ThemeMode mode) => switch (mode) {
  ThemeMode.system => Icons.brightness_auto_outlined,
  ThemeMode.light => Icons.light_mode_outlined,
  ThemeMode.dark => Icons.dark_mode_outlined,
};

String _toHex(List<int> bytes) => bytes
    .map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase())
    .join(' ');
