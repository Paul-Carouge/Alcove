import 'package:flutter/material.dart';

import '../../core/app_update.dart';
import '../../core/brand.dart';
import '../../core/session.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../backup/backup_controller.dart';
import '../backup/backup_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({
    super.key,
    required this.session,
    required this.version,
    this.backup,
    this.onOpenBackup,
    this.updater,
  });

  final Session session;
  final String version;
  final BackupController? backup;
  final VoidCallback? onOpenBackup;
  final AppUpdater? updater;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final user = session.user;
    final name = user?.getStringValue('name') ?? '';
    final email = user?.getStringValue('email') ?? '';
    final server = session.server;

    return CustomScrollView(
      slivers: [
        LargeTitleAppBar(title: l.tabAccount),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AlcoveSpace.s4,
              AlcoveSpace.s2,
              AlcoveSpace.s4,
              AlcoveSpace.s5,
            ),
            child: Row(
              children: [
                AlcoveAvatar(name: name, email: email, size: 64),
                const SizedBox(width: AlcoveSpace.s4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name.isNotEmpty ? name : email, style: context.text.titleLarge),
                      if (name.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(email, style: TextStyle(color: c.textMuted)),
                      ],
                      const SizedBox(height: AlcoveSpace.s2),
                      if (server != null) _ServerChip(server: server),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (updater case final u?)
          SliverToBoxAdapter(
            child: ListenableBuilder(
              listenable: u,
              builder: (context, _) =>
                  u.hasUpdate ? _UpdateCard(updater: u) : const SizedBox.shrink(),
            ),
          ),
        if (backup case final b?)
          SliverToBoxAdapter(
            child: ListenableBuilder(
              listenable: b,
              builder: (context, _) => InsetGroup(
                title: l.backupTitle,
                children: [
                  GroupTile(
                    icon: b.running ? Icons.cloud_sync_outlined : Icons.cloud_upload_outlined,
                    tint: b.state.enabled ? c.success : c.textMuted,
                    title: l.backupTitle,
                    subtitle: BackupScreen.status(context, b),
                    onTap: onOpenBackup,
                  ),
                ],
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: InsetGroup(
            title: l.appSection,
            children: [
              GroupTile(
                icon: Icons.info_outline,
                title: l.versionLabel(version),
              ),
              if (updater case final u? when u.supported)
                ListenableBuilder(
                  listenable: u,
                  builder: (context, _) => GroupTile(
                    icon: Icons.system_update_outlined,
                    title: l.updateCheck,
                    subtitle: switch (u.phase) {
                      UpdatePhase.checking => l.updateChecking,
                      _ when u.hasUpdate => l.updateAvailableShort(u.latest!),
                      _ => l.updateUpToDate,
                    },
                    trailing: u.phase == UpdatePhase.checking
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                    onTap: u.phase == UpdatePhase.checking ? null : u.check,
                  ),
                ),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: InsetGroup(
            children: [
              GroupTile(icon: Icons.logout, title: l.signOut, danger: true, onTap: session.signOut),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AlcoveSpace.s4,
              AlcoveSpace.s2,
              AlcoveSpace.s4,
              AlcoveSpace.s8,
            ),
            child: Column(
              children: [
                const AlcoveLogo(size: 28),
                const SizedBox(height: AlcoveSpace.s2),
                Text(
                  '$kProductName · ${l.madeBy(kAuthor)}',
                  style: TextStyle(color: c.textMuted, fontSize: AlcoveFont.sizeXs),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ServerChip extends StatelessWidget {
  const _ServerChip({required this.server});
  final Uri server;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final secure = server.scheme == 'https';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AlcoveSpace.s2 + 2, vertical: 4),
      decoration: BoxDecoration(
        color: c.surfaceSunken,
        borderRadius: BorderRadius.circular(AlcoveRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            secure ? Icons.lock_outline : Icons.lock_open,
            size: 14,
            color: secure ? c.success : c.warning,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              server.host + (server.hasPort ? ':${server.port}' : ''),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: AlcoveFont.sizeXs,
                color: c.textMuted,
                fontWeight: AlcoveFont.medium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpdateCard extends StatelessWidget {
  const _UpdateCard({required this.updater});
  final AppUpdater updater;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final u = updater;
    final busy = u.phase == UpdatePhase.downloading;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AlcoveSpace.s4, 0, AlcoveSpace.s4, AlcoveSpace.s5),
      child: Container(
        padding: const EdgeInsets.all(AlcoveSpace.s4),
        decoration: BoxDecoration(
          color: c.accent,
          borderRadius: BorderRadius.circular(AlcoveRadius.lg),
          boxShadow: c.shadowMD,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: c.accentContrast),
                const SizedBox(width: AlcoveSpace.s2),
                Expanded(
                  child: Text(
                    l.updateAvailable(u.latest!),
                    style: TextStyle(
                      color: c.accentContrast,
                      fontWeight: AlcoveFont.semibold,
                      fontSize: AlcoveFont.sizeMd,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AlcoveSpace.s2),
            Text(
              u.phase == UpdatePhase.failed ? l.updateFailed : l.updateBody,
              style: TextStyle(
                color: c.accentContrast.withValues(alpha: 0.85),
                fontSize: AlcoveFont.sizeSm,
              ),
            ),
            const SizedBox(height: AlcoveSpace.s4),
            if (busy)
              ClipRRect(
                borderRadius: BorderRadius.circular(AlcoveRadius.full),
                child: LinearProgressIndicator(
                  value: u.progress > 0 ? u.progress : null,
                  minHeight: 6,
                  color: c.accentContrast,
                  backgroundColor: c.accentContrast.withValues(alpha: 0.25),
                ),
              )
            else
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: c.accentContrast,
                  foregroundColor: c.accent,
                ),
                onPressed: u.phase == UpdatePhase.readyToInstall ? u.install : u.downloadAndInstall,
                child: Text(u.phase == UpdatePhase.readyToInstall ? l.updateInstall : l.updateNow),
              ),
          ],
        ),
      ),
    );
  }
}
