import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(title: Text(l.backupTitle)),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final s = controller.state;
          final p = controller.progress;
          final failed = controller.lastReport?.progress.failed ?? 0;
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: AlcoveSpace.s3),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AlcoveSpace.s4),
                child: Text(l.backupIntro, style: TextStyle(color: colors.textMuted)),
              ),
              const SizedBox(height: AlcoveSpace.s3),
              SwitchListTile(
                title: Text(l.backupEnable),
                value: s.enabled,
                onChanged: (on) async {
                  final ok = await controller.setEnabled(on, folderName: l.backupFolderDefault);
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(l.backupNoAccess)));
                  }
                },
              ),
              SwitchListTile(
                title: Text(l.backupVideos),
                value: s.videos,
                onChanged: s.enabled ? controller.setVideos : null,
              ),
              SwitchListTile(
                title: Text(l.backupWifiOnly),
                value: s.wifiOnly,
                onChanged: s.enabled ? controller.setWifiOnly : null,
              ),
              if (s.enabled) ...[
                ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(
                    l.backupFolder(s.folderName.isEmpty ? l.backupFolderDefault : s.folderName),
                  ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(AlcoveSpace.s4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(liveRegion: true, child: Text(status(context, controller))),
                      if (controller.running && p != null && p.total > 0) ...[
                        const SizedBox(height: AlcoveSpace.s3),
                        LinearProgressIndicator(
                          value: (p.processed + p.currentFraction) / p.total,
                          semanticsLabel: l.backupTitle,
                        ),
                      ],
                      if (!controller.running && failed > 0) ...[
                        const SizedBox(height: AlcoveSpace.s2),
                        Text(l.backupSomeFailed(failed), style: TextStyle(color: colors.textMuted)),
                      ],
                      const SizedBox(height: AlcoveSpace.s4),
                      controller.running
                          ? OutlinedButton(onPressed: controller.cancel, child: Text(l.backupStop))
                          : FilledButton.icon(
                              onPressed: controller.runNow,
                              icon: const Icon(Icons.cloud_upload_outlined),
                              label: Text(l.backupNow),
                            ),
                      const SizedBox(height: AlcoveSpace.s4),
                      Text(
                        l.backupBackground,
                        style: TextStyle(color: colors.textMuted, fontSize: AlcoveFont.sizeXs),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
