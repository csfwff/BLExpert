part of '../home/home_screen.dart';

class _LogLine extends StatelessWidget {
  const _LogLine({
    required this.entry,
    required this.l10n,
    required this.compact,
    this.selected = false,
    this.onTap,
    this.onToggleBookmark,
  });
  final SessionLogRecord entry;
  final AppLocalizations l10n;
  final bool compact;
  final bool selected;
  final VoidCallback? onTap;
  final ValueChanged<SessionLogRecord>? onToggleBookmark;

  static const double compactBreakpoint = 520;

  @override
  Widget build(BuildContext context) {
    final shad.ColorScheme colors = AppTheme.colorsOf(context);
    final Color color = switch (entry.kind) {
      SessionLogKind.received => colors.chart2,
      SessionLogKind.sent => colors.primary,
      SessionLogKind.system => AppTheme.colorsOf(context).secondary,
      SessionLogKind.error => AppTheme.colorsOf(context).destructive,
    };
    final String payload = entry.message ?? _toHex(entry.data);
    final String timestamp = entry.timestamp.toIso8601String().split('T').last;
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
    final Widget content = shad.SelectableText(
      payload,
      style: TextStyle(
        fontFamily: AppFonts.mono,
        package: AppFonts.shadcnPackage,
        fontSize: 12,
        height: 1.45,
        color: entry.kind == SessionLogKind.error ? color : null,
      ),
    );
    final Widget? bookmarkButton = onToggleBookmark == null
        ? null
        : ToolIconButton(
            tooltip: entry.bookmarked ? '取消书签' : '添加书签',
            onPressed: () => onToggleBookmark!(entry),
            icon: Icon(
              entry.bookmarked ? AppIcons.bookmark : AppIcons.bookmarkOutline,
              size: 19,
              color: entry.bookmarked ? colors.primary : null,
            ),
            touchSize: 44,
          );
    final Widget? detailsButton = onTap == null
        ? null
        : ToolIconButton(
            key: const ValueKey<String>('console-log-details-button'),
            tooltip: l10n.viewLogDetails,
            onPressed: onTap,
            icon: const Icon(AppIcons.subjectOutlined, size: 16),
            touchSize: 32,
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
            color: selected ? colors.secondary.withValues(alpha: 0.45) : null,
            border: Border(left: BorderSide(color: color, width: 2)),
          ),
          child: compact
              ? Column(
                  key: const ValueKey<String>('log-line-compact'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          timestamp,
                          style: TextStyle(
                            fontFamily: AppFonts.mono,
                            package: AppFonts.shadcnPackage,
                            fontSize: 11,
                            color: colors.border,
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
                                fontFamily: AppFonts.mono,
                                package: AppFonts.shadcnPackage,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                        if (entry.data.isNotEmpty) ...<Widget>[
                          const SizedBox(width: 8),
                          Text(
                            '${entry.data.length} B',
                            style: AppTheme.textStylesOf(context).labelSmall,
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
                )
              : Row(
                  key: const ValueKey<String>('log-line-wide'),
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    SizedBox(
                      width: 90,
                      child: Text(
                        timestamp,
                        style: TextStyle(
                          fontFamily: AppFonts.mono,
                          package: AppFonts.shadcnPackage,
                          fontSize: 11,
                          color: colors.border,
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
                            fontFamily: AppFonts.mono,
                            package: AppFonts.shadcnPackage,
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
                          style: AppTheme.textStylesOf(context).labelSmall,
                        ),
                      ),
                    ],
                    const SizedBox(width: 10),
                    Expanded(child: content),
                    ?detailsButton,
                    ?bookmarkButton,
                  ],
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

IconData _themeModeIcon(shad.ThemeMode mode) => switch (mode) {
  shad.ThemeMode.system => AppIcons.brightnessAuto,
  shad.ThemeMode.light => AppIcons.lightMode,
  shad.ThemeMode.dark => AppIcons.darkMode,
};

String _toHex(List<int> bytes) => bytes
    .map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase())
    .join(' ');
