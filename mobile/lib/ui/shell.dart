import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_update.dart';
import '../core/session.dart';
import '../l10n/gen/app_localizations.dart';
import '../theme/theme.dart';
import '../theme/tokens.g.dart';
import 'expressive.dart';
import 'kit.dart';

/// What the signed-in shell (HomeScreen) offers to the screens inside it: global search and the
/// account page, opened above the navigation bar. Screens used on their own (tests, pickers) find
/// no shell and simply show no such actions.
class AppShell extends InheritedWidget {
  const AppShell({
    super.key,
    required this.session,
    required this.onSearch,
    required this.onAccount,
    this.updater,
    required super.child,
  });

  final Session session;
  final VoidCallback onSearch;
  final VoidCallback onAccount;

  /// Shows a dot on the avatar when an app update is available.
  final AppUpdater? updater;

  static AppShell? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppShell>();

  @override
  bool updateShouldNotify(AppShell old) =>
      session != old.session ||
      updater != old.updater ||
      onSearch != old.onSearch ||
      onAccount != old.onAccount;
}

/// The trailing actions every main screen shares: search, then the account avatar (left out on
/// screens deeper in a tab). Empty outside the shell.
List<Widget> shellActions(BuildContext context, {bool account = true}) {
  final shell = AppShell.maybeOf(context);
  if (shell == null) return const [];
  final l = AppLocalizations.of(context);
  return [
    IconButton(
      key: const Key('globalSearch'),
      tooltip: l.searchTitle,
      icon: const Icon(Icons.search),
      onPressed: shell.onSearch,
    ),
    if (account) AccountButton(shell: shell),
  ];
}

/// The user's initials on the Expressive "cookie", opening the account page. A dot tells about an
/// available app update.
class AccountButton extends StatelessWidget {
  const AccountButton({super.key, required this.shell});

  final AppShell shell;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final user = shell.session.user;
    final avatar = ExcludeSemantics(
      child: AlcoveAvatar(
        name: user?.getStringValue('name') ?? '',
        email: user?.getStringValue('email') ?? '',
        size: 34,
      ),
    );
    final updater = shell.updater;
    return Tooltip(
      message: l.tabAccount,
      child: Semantics(
        button: true,
        label: l.tabAccount,
        child: InkResponse(
          key: const Key('accountButton'),
          onTap: shell.onAccount,
          radius: 24,
          child: SizedBox.square(
            dimension: 48,
            child: Center(
              child: updater == null
                  ? avatar
                  : ListenableBuilder(
                      listenable: updater,
                      builder: (_, child) => Badge(
                        isLabelVisible: updater.hasUpdate,
                        smallSize: 10,
                        child: child,
                      ),
                      child: avatar,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One destination of the [FloatingNavBar].
class NavItem {
  const NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.key,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Key? key;
}

/// The app's navigation, M3 Expressive "floating toolbar" style: a raised pill over the content.
/// Every destination shows its icon; the selected one also shows its label on a soft accent pill
/// (the others name themselves on long press and to screen readers).
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
  });

  /// Height of the pill; the shell keeps this much room (plus a margin) under the content.
  static const double height = 64;

  final List<NavItem> items;
  final int selected;
  final ValueChanged<int> onSelected;

  Widget _button(int i) => _NavButton(
    key: items[i].key,
    item: items[i],
    selected: i == selected,
    onTap: () {
      HapticFeedback.selectionClick();
      onSelected(i);
    },
  );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: c.surfaceRaised,
          shape: StadiumBorder(side: BorderSide(color: c.border)),
          shadows: c.shadowMD,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: height),
          child: Padding(
            padding: const EdgeInsets.all(AlcoveSpace.s1 + 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < items.length; i++)
                  // Only the selected destination grows (and gives up its label first when the
                  // screen is narrow or the text is large).
                  if (i == selected) Flexible(child: _button(i)) else _button(i),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({super.key, required this.item, required this.selected, required this.onTap});

  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final duration = AlcoveSprings.of(context, AlcoveSprings.medium);
    final fg = selected ? c.accent : c.textMuted;
    return Tooltip(
      message: item.label,
      // The selected one already shows its label.
      triggerMode: selected ? TooltipTriggerMode.manual : TooltipTriggerMode.longPress,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        selected: selected,
        label: item.label,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: AnimatedContainer(
              duration: duration,
              curve: AlcoveSprings.spatial,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 52),
              padding: const EdgeInsets.symmetric(horizontal: AlcoveSpace.s3),
              decoration: ShapeDecoration(
                color: selected ? c.accentSubtle : c.accentSubtle.withValues(alpha: 0),
                shape: const StadiumBorder(),
              ),
              // The visuals repeat the label: hidden from screen readers (the tap stays).
              child: ExcludeSemantics(
                child: AnimatedSize(
                  duration: duration,
                  curve: AlcoveSprings.spatial,
                  alignment: AlignmentDirectional.centerStart,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(selected ? item.selectedIcon : item.icon, color: fg, size: 24),
                      if (selected) ...[
                        const SizedBox(width: AlcoveSpace.s2),
                        Flexible(
                          child: Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            softWrap: false,
                            style: sansStyle(AlcoveFont.sizeSm, c.text, AlcoveFont.semibold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A two or three way switch on a sunken track (Photos / Albums, Agenda / Month): the chosen
/// segment is a raised pill. Each segment is a 48dp target with its own label.
class SegmentedSwitch<T> extends StatelessWidget {
  const SegmentedSwitch({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
  });

  final List<(T, String, Key?)> segments;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final duration = AlcoveSprings.of(context, AlcoveSprings.fast);
    return DecoratedBox(
      decoration: ShapeDecoration(color: c.surfaceSunken, shape: const StadiumBorder()),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (v, label, key) in segments)
              Semantics(
                key: key,
                button: true,
                selected: v == value,
                inMutuallyExclusiveGroup: true,
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: v == value
                      ? null
                      : () {
                          HapticFeedback.selectionClick();
                          onChanged(v);
                        },
                  child: AnimatedContainer(
                    duration: duration,
                    curve: AlcoveSprings.fastSpatial,
                    constraints: const BoxConstraints(minHeight: 48, minWidth: 64),
                    padding: const EdgeInsets.symmetric(horizontal: AlcoveSpace.s4),
                    alignment: Alignment.center,
                    decoration: ShapeDecoration(
                      color: v == value ? c.surface : c.surface.withValues(alpha: 0),
                      shape: const StadiumBorder(),
                      shadows: v == value ? c.shadowSM : const [],
                    ),
                    child: Text(
                      label,
                      style: sansStyle(
                        AlcoveFont.sizeSm,
                        v == value ? c.text : c.textMuted,
                        AlcoveFont.medium,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
