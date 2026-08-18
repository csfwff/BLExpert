part of '../../main.dart';

enum _ConsoleLogFilter { all, tx, rx, system, error }

class _ConsoleLogFilterBar extends StatelessWidget {
  const _ConsoleLogFilterBar({
    required this.filter,
    required this.onChanged,
    required this.l10n,
  });

  final _ConsoleLogFilter filter;
  final ValueChanged<_ConsoleLogFilter> onChanged;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_ConsoleLogFilter>(
      tooltip: l10n.filterLogs,
      initialValue: filter,
      onSelected: onChanged,
      itemBuilder: (BuildContext context) =>
          <PopupMenuEntry<_ConsoleLogFilter>>[
            _item(_ConsoleLogFilter.all, l10n.allFilter),
            _item(_ConsoleLogFilter.tx, l10n.txFilter),
            _item(_ConsoleLogFilter.rx, l10n.rxFilter),
            _item(_ConsoleLogFilter.system, l10n.systemFilter),
            _item(_ConsoleLogFilter.error, l10n.errorFilter),
          ],
      icon: const Icon(Icons.filter_list_outlined, size: 18),
    );
  }

  PopupMenuItem<_ConsoleLogFilter> _item(
    _ConsoleLogFilter value,
    String label,
  ) {
    return PopupMenuItem<_ConsoleLogFilter>(
      value: value,
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 22,
            child: value == filter ? const Icon(Icons.check, size: 16) : null,
          ),
          Text(label),
        ],
      ),
    );
  }
}
