import 'package:flutter/material.dart';

import '../../core/brand.dart';
import '../../core/session.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key, required this.session, required this.version});

  final Session session;
  final String version;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.colors;
    final user = session.user;
    final name = user?.getStringValue('name') ?? '';
    final email = user?.getStringValue('email') ?? '';
    final initials = (name.trim().isNotEmpty ? name : email)
        .split(RegExp(r'[\s@._-]+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();

    return Scaffold(
      appBar: AppBar(title: Text(l.tabAccount)),
      body: ListView(
        padding: const EdgeInsets.all(AlcoveSpace.s4),
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: colors.accentSubtle,
              foregroundColor: colors.accent,
              child: Text(initials),
            ),
            title: Text(name.isNotEmpty ? name : email),
            subtitle: name.isNotEmpty ? Text(email) : Text(l.signedInAs),
          ),
          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: Text(l.serverLabel),
            subtitle: Text(session.server?.toString() ?? ''),
          ),
          const SizedBox(height: AlcoveSpace.s4),
          OutlinedButton.icon(
            onPressed: session.signOut,
            icon: const Icon(Icons.logout),
            label: Text(l.signOut),
          ),
          const SizedBox(height: AlcoveSpace.s7),
          Text(
            '$kProductName · ${l.versionLabel(version)}\n${l.madeBy(kAuthor)}',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textMuted, fontSize: AlcoveFont.sizeXs),
          ),
        ],
      ),
    );
  }
}
