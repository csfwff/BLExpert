part of '../home/home_screen.dart';

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

  static const double _menuWidth = 136;

  @override
  Widget build(BuildContext context) {
    return ToolIconButton(
      tooltip: l10n.filterLogs,
      onPressed: () => shad
          .showDropdown<void>(
            context: context,
            widthConstraint: shad.PopoverConstraint.flexible,
            builder: (BuildContext context) => SizedBox(
              key: const ValueKey<String>('console-log-filter-menu'),
              width: _menuWidth,
              child: shad.MenuGroup(
                direction: Axis.vertical,
                onDismissed: () => shad.closeOverlay(context),
                builder: (BuildContext context, List<Widget> children) =>
                    shad.MenuPopup(
                      padding: const EdgeInsets.all(2),
                      children: children,
                    ),
                children: <shad.MenuItem>[
                  _item(_ConsoleLogFilter.all, l10n.allFilter),
                  _item(_ConsoleLogFilter.tx, l10n.txFilter),
                  _item(_ConsoleLogFilter.rx, l10n.rxFilter),
                  _item(_ConsoleLogFilter.system, l10n.systemFilter),
                  _item(_ConsoleLogFilter.error, l10n.errorFilter),
                ],
              ),
            ),
          )
          .future,
      icon: const Icon(AppIcons.filterList, size: 18),
    );
  }

  shad.MenuButton _item(_ConsoleLogFilter value, String label) {
    final bool selected = filter == value;
    return shad.MenuButton(
      key: ValueKey<String>('console-log-filter-option-${value.name}'),
      onPressed: (_) => onChanged(value),
      child: Semantics(
        selected: selected,
        inMutuallyExclusiveGroup: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ExcludeSemantics(
              child: shad.Radio(
                key: ValueKey<String>(
                  'console-log-filter-indicator-${value.name}',
                ),
                value: selected,
                size: 12,
              ),
            ),
            const SizedBox(width: 4),
            Text(label, maxLines: 1, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
