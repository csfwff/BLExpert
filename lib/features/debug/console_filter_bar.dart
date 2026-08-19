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

  @override
  Widget build(BuildContext context) {
    return ToolIconButton(
      tooltip: l10n.filterLogs,
      onPressed: () => shad
          .showDropdown<void>(
            context: context,
            widthConstraint: shad.PopoverConstraint.flexible,
            builder: (BuildContext context) => shad.DropdownMenu(
              children: <shad.MenuItem>[
                shad.MenuRadioGroup<_ConsoleLogFilter>(
                  value: filter,
                  onChanged: (BuildContext context, _ConsoleLogFilter value) =>
                      onChanged(value),
                  children: <shad.MenuRadio<_ConsoleLogFilter>>[
                    _item(_ConsoleLogFilter.all, l10n.allFilter),
                    _item(_ConsoleLogFilter.tx, l10n.txFilter),
                    _item(_ConsoleLogFilter.rx, l10n.rxFilter),
                    _item(_ConsoleLogFilter.system, l10n.systemFilter),
                    _item(_ConsoleLogFilter.error, l10n.errorFilter),
                  ],
                ),
              ],
            ),
          )
          .future,
      icon: const Icon(AppIcons.filterList, size: 18),
    );
  }

  shad.MenuRadio<_ConsoleLogFilter> _item(
    _ConsoleLogFilter value,
    String label,
  ) {
    return shad.MenuRadio<_ConsoleLogFilter>(value: value, child: Text(label));
  }
}
