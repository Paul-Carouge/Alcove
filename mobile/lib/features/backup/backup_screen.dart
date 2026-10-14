import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import 'backup_controller.dart';
import 'photo_backup.dart';

class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key, required this.controller});

  final BackupController controller;

  /// One line describing where backup stands, for this screen and the Account tab.
  static String status(BuildContext context, BackupController c) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    if (!c.state.enabled) return l.backupOff;
    final p = c.progress;
    if (c.running && p != null) {
      return p.total == 0 || p.current.isEmpty
          ? l.backupPreparing
          : l.backupRunning(p.current, p.processed + 1, p.total);
    }
    final report = c.lastReport;
    if (report != null) {
      switch (report.stop) {
        case BackupStop.noAccess:
          return l.backupNoAccess;
        case BackupStop.notOnWifi:
          return l.backupNotOnWifi;
        case BackupStop.offline:
          return l.backupOffline;
        case BackupStop.serverRefused:
          return l.backupRefused(report.error);
        default:
      }
    }
    final last = c.state.lastRun;
    return [
      l.backupUpToDate(c.uploadedCount),
      if (last != null) l.backupLastRun(DateFormat.yMMMd(locale).add_Hm().format(last)),
    ].join('\n');
  }

  Future<void> _toggle(BuildContext context, bool on) async {
    final l = AppLocalizations.of(context);
    final ok = await controller.setEnabled(on, folderName: l.backupFolderDefault);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.backupNoAccess)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final s = controller.state;
          return CustomScrollView(
            slivers: [
              LargeTitleAppBar(title: l.backupTitle),
              SliverToBoxAdapter(child: _StatusCard(controller: controller)),
              SliverToBoxAdapter(
                child: InsetGroup(
                  title: l.backupSettings,
                  footer: s.enabled ? l.backupBackground : l.backupIntro,
                  children: [
                    _SwitchTile(
                      icon: Icons.photo_library_outlined,
                      title: l.backupEnable,
                      value: s.enabled,
                      onChanged: (on) => _toggle(context, on),
                    ),
                    _SwitchTile(
                      icon: Icons.videocam_outlined,
                      title: l.backupVideos,
                      value: s.videos,
                      onChanged: s.enabled ? controller.setVideos : null,
                    ),
                    _SwitchTile(
                      icon: Icons.wifi,
                      title: l.backupWifiOnly,
                      value: s.wifiOnly,
                      onChanged: s.enabled ? controller.setWifiOnly : null,
                    ),
                    if (s.enabled)
                      GroupTile(
                        icon: Icons.folder_outlined,
                        title: l.backupFolder(
                          s.folderName.isEmpty ? l.backupFolderDefault : s.folderName,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final change = onChanged;
    return MergeSemantics(
      child: GroupTile(
        icon: icon,
        title: title,
        trailing: Switch(value: value, onChanged: change),
        onTap: change == null ? null : () => change(!value),
      ),
    );
  }
}

/// The ring shows the current run, or a full ring when everything is backed up.
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.controller});
  final BackupController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final s = controller.state;
    final p = controller.progress;
    final running = controller.running;
    final failed = controller.lastReport?.progress.failed ?? 0;
    final fraction = running && p != null && p.total > 0
        ? (p.processed + p.currentFraction) / p.total
        : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AlcoveSpace.s4,
        AlcoveSpace.s2,
        AlcoveSpace.s4,
        AlcoveSpace.s5,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AlcoveSpace.s5,
          AlcoveSpace.s6,
          AlcoveSpace.s5,
          AlcoveSpace.s5,
        ),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AlcoveRadius.xl),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: ProgressRing(
                size: 128,
                stroke: 8,
                value: !s.enabled ? 0 : (running ? fraction : 1),
                child: running && fraction != null
                    ? Text(
                        '${(fraction * 100).round()} %',
                        style: context.text.headlineSmall,
                        semanticsLabel: l.backupTitle,
                      )
                    : Icon(
                        !s.enabled
                            ? Icons.cloud_off_outlined
                            : running
                            ? Icons.cloud_sync_outlined
                            : Icons.cloud_done_outlined,
                        size: 40,
                        color: s.enabled ? c.accent : c.textMuted,
                      ),
              ),
            ),
            const SizedBox(height: AlcoveSpace.s5),
            Semantics(
              liveRegion: true,
              child: Text(
                BackupScreen.status(context, controller),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: c.text,
                  fontWeight: AlcoveFont.medium,
                  height: AlcoveFont.leadingNormal,
                ),
              ),
            ),
            if (!running && failed > 0) ...[
              const SizedBox(height: AlcoveSpace.s2),
              Text(
                l.backupSomeFailed(failed),
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textMuted),
              ),
            ],
            if (s.enabled) ...[
              const SizedBox(height: AlcoveSpace.s5),
              running
                  ? OutlinedButton(onPressed: controller.cancel, child: Text(l.backupStop))
                  : FilledButton.icon(
                      onPressed: controller.runNow,
                      icon: const Icon(Icons.cloud_upload_outlined),
                      label: Text(l.backupNow),
                    ),
            ],
          ],
        ),
      ),
    );
  }
}
