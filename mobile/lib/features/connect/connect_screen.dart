import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../core/api_compat.dart';
import '../../core/brand.dart';
import '../../core/secure_store.dart';
import '../../core/server_checker.dart';
import '../../core/server_url.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';

/// First screen: the user enters (later: scans) the URL of their server,
/// which is validated against GET /health before going further.
class ConnectScreen extends StatefulWidget {
  const ConnectScreen({
    super.key,
    required this.checker,
    required this.store,
    this.onConnected,
    this.allowInsecure = kDebugMode,
  });

  final ServerChecker checker;
  final SecureStore store;

  /// Called with the checked server when the user continues.
  final void Function(Uri server)? onConnected;

  /// Accept http:// URLs. Debug builds only, for a local dev server.
  final bool allowInsecure;

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _controller = TextEditingController();
  ServerUrlError? _urlError;
  ServerCheckResult? _result;
  Uri? _checked;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    widget.store
        .readServerUrl()
        .then((url) {
          if (url != null && mounted && _controller.text.isEmpty) _controller.text = url.toString();
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final parsed = parseServerUrl(_controller.text, allowInsecure: widget.allowInsecure);
    if (parsed case InvalidServerUrl(:final error)) {
      setState(() {
        _urlError = error;
        _result = null;
      });
      return;
    }
    final uri = (parsed as ValidServerUrl).uri;
    setState(() {
      _urlError = null;
      _result = null;
      _checking = true;
    });
    final result = await widget.checker.check(uri);
    if (!mounted) return;
    setState(() {
      _checking = false;
      _result = result;
      _checked = uri;
    });
    // Screen readers: announce the outcome, which appears below the fold.
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        _statusText(AppLocalizations.of(context), result),
        Directionality.of(context),
      ),
    );
    if (result is ServerCompatible) {
      await widget.store.writeServerUrl(uri).catchError((_) {});
    }
  }

  String? _urlErrorText(AppLocalizations l) => switch (_urlError) {
    null => null,
    ServerUrlError.empty => l.errorEmpty,
    ServerUrlError.invalid => l.errorInvalidUrl,
    ServerUrlError.httpsRequired => l.errorHttpsRequired,
  };

  String _statusText(AppLocalizations l, ServerCheckResult r) => switch (r) {
    ServerCompatible(:final health) => l.connectedTo(health.name, health.version),
    ServerIncompatible(:final health, compatibility: Compatibility.clientTooOld) =>
      l.errorClientTooOld(health.api.min, health.api.max),
    ServerIncompatible(:final health) => l.errorServerTooOld(health.api.min, health.api.max),
    ServerCheckFailed(failure: ServerFailure.unreachable) => l.errorUnreachable,
    ServerCheckFailed(failure: ServerFailure.tls) => l.errorTls,
    ServerCheckFailed(failure: ServerFailure.invalidResponse) => l.errorInvalidResponse,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = context.colors;
    final result = _result;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AlcoveSpace.s5),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(l.connectTitle, style: theme.textTheme.headlineSmall),
                  ),
                  const SizedBox(height: AlcoveSpace.s2),
                  Text(
                    l.connectSubtitle,
                    style: theme.textTheme.bodyLarge?.copyWith(color: colors.textMuted),
                  ),
                  const SizedBox(height: AlcoveSpace.s5),
                  TextField(
                    key: const Key('serverUrl'),
                    controller: _controller,
                    enabled: !_checking,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.go,
                    autofillHints: const [AutofillHints.url],
                    inputFormatters: [LengthLimitingTextInputFormatter(2048)],
                    onSubmitted: (_) => _check(),
                    decoration: InputDecoration(
                      labelText: l.serverUrlLabel,
                      hintText: l.serverUrlHint,
                      prefixIcon: const Icon(Icons.dns_outlined),
                      errorText: _urlErrorText(l),
                    ),
                  ),
                  const SizedBox(height: AlcoveSpace.s4),
                  FilledButton(
                    key: const Key('checkButton'),
                    onPressed: _checking ? null : _check,
                    child: _checking
                        ? Semantics(
                            label: l.checking,
                            child: const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : Text(l.checkButton),
                  ),
                  const SizedBox(height: AlcoveSpace.s3),
                  Tooltip(
                    message: l.comingSoon,
                    child: OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: Text(l.scanQrButton),
                    ),
                  ),
                  if (result != null) ...[
                    const SizedBox(height: AlcoveSpace.s5),
                    _ResultCard(
                      text: _statusText(l, result),
                      result: result,
                      insecure: _checked?.scheme == 'http',
                      onContinue: widget.onConnected == null || _checked == null
                          ? null
                          : () => widget.onConnected!(_checked!),
                    ),
                  ],
                  const SizedBox(height: AlcoveSpace.s6),
                  Text(
                    l.madeBy(kAuthor),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: colors.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.text,
    required this.result,
    this.onContinue,
    this.insecure = false,
  });

  final String text;

  /// The address uses plain http (private network).
  final bool insecure;
  final ServerCheckResult result;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.colors;
    final ok = result is ServerCompatible;
    final setupRequired = switch (result) {
      ServerCompatible(:final health) => health.setupRequired,
      _ => false,
    };

    return Container(
      key: const Key('result'),
      padding: const EdgeInsets.all(AlcoveSpace.s4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AlcoveRadius.lg),
        border: Border.all(color: colors.border),
        boxShadow: colors.shadowSM,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                ok ? Icons.check_circle_outline : Icons.error_outline,
                color: ok ? colors.success : colors.danger,
                semanticLabel: null,
              ),
              const SizedBox(width: AlcoveSpace.s2),
              Expanded(child: Text(text)),
            ],
          ),
          if (setupRequired) ...[
            const SizedBox(height: AlcoveSpace.s3),
            Text(l.setupRequired, style: TextStyle(color: colors.textMuted)),
          ],
          if (ok && insecure) ...[
            const SizedBox(height: AlcoveSpace.s3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_open, size: 18, color: colors.warning),
                const SizedBox(width: AlcoveSpace.s2),
                Expanded(
                  child: Text(l.insecureWarning, style: TextStyle(color: colors.textMuted)),
                ),
              ],
            ),
          ],
          if (ok && !setupRequired) ...[
            const SizedBox(height: AlcoveSpace.s4),
            FilledButton(
              key: const Key('continueButton'),
              onPressed: onContinue,
              child: Text(l.continueButton),
            ),
          ],
        ],
      ),
    );
  }
}
