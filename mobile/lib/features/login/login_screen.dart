import 'package:flutter/material.dart';

import '../../core/brand.dart';
import '../../core/session.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';

/// Email and password, then the second factor when the account has one (authenticator app or
/// email code), like the web login.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.session, required this.onChangeServer});

  final Session session;
  final VoidCallback onChangeServer;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum _Step { password, totp, emailCode }

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  _Step _step = _Step.password;
  bool _recovery = false;
  EmailCodeSent? _emailStep;
  String? _error;
  bool _busy = false;
  bool _submitted = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    setState(() => _submitted = true);
    if (_email.text.trim().isEmpty || _password.text.isEmpty) return;
    if (_step != _Step.password && _code.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = switch (_step) {
      _Step.password => await widget.session.signIn(_email.text, _password.text),
      _Step.totp => await widget.session.signIn(_email.text, _password.text, totp: _code.text),
      _Step.emailCode => await widget.session.verifyEmailCode(_emailStep!, _code.text),
    };
    if (!mounted) return;
    setState(() {
      _busy = false;
      switch (result) {
        case SignedIn():
          break; // the app shows the home screen
        case TotpRequired(:final invalid):
          if (_step == _Step.totp && invalid) _error = l.errorBadCode;
          _step = _Step.totp;
        case EmailCodeSent():
          _emailStep = result;
          _step = _Step.emailCode;
          _code.clear();
        case SignInFailed(:final failure):
          _error = switch (failure) {
            SignInFailure.badCredentials =>
              _step == _Step.password ? l.errorBadCredentials : l.errorBadCode,
            SignInFailure.tooManyAttempts => l.errorTooMany,
            SignInFailure.network => l.errorNetwork,
            SignInFailure.unexpected => l.errorUnexpected,
          };
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.colors;
    final server = widget.session.server?.host ?? '';
    final (title, body) = switch (_step) {
      _Step.password => (l.signInTitle, l.signInSubtitle(server)),
      _Step.totp => (l.totpTitle, _recovery ? l.totpRecoveryBody : l.totpBody),
      _Step.emailCode => (l.emailCodeTitle, l.emailCodeBody(_email.text.trim())),
    };
    String? required(String v) => _submitted && v.trim().isEmpty ? l.errorRequired : null;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AlcoveSpace.s5),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const BrandHeader(name: kProductName),
                    const SizedBox(height: AlcoveSpace.s8),
                    Text(title, style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: AlcoveSpace.s2),
                    Text(body, style: TextStyle(color: colors.textMuted)),
                    const SizedBox(height: AlcoveSpace.s6),
                    if (_step == _Step.password) ...[
                      TextField(
                        controller: _email,
                        decoration: InputDecoration(
                          labelText: l.emailLabel,
                          errorText: required(_email.text),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.email, AutofillHints.username],
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: AlcoveSpace.s4),
                      TextField(
                        controller: _password,
                        decoration: InputDecoration(
                          labelText: l.passwordLabel,
                          errorText: required(_password.text),
                        ),
                        obscureText: true,
                        autofillHints: const [AutofillHints.password],
                        onSubmitted: (_) => _submit(),
                      ),
                    ] else
                      TextField(
                        key: ValueKey('code-$_step-$_recovery'),
                        controller: _code,
                        autofocus: true,
                        decoration: InputDecoration(labelText: l.codeLabel),
                        keyboardType: _recovery ? TextInputType.text : TextInputType.number,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        onSubmitted: (_) => _submit(),
                      ),
                    if (_error != null) ...[
                      const SizedBox(height: AlcoveSpace.s4),
                      Semantics(
                        liveRegion: true,
                        child: Text(_error!, style: TextStyle(color: colors.danger)),
                      ),
                    ],
                    const SizedBox(height: AlcoveSpace.s5),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_step == _Step.password ? l.signInButton : l.verifyButton),
                    ),
                    const SizedBox(height: AlcoveSpace.s2),
                    if (_step == _Step.totp)
                      TextButton(
                        onPressed: () => setState(() {
                          _recovery = !_recovery;
                          _code.clear();
                          _error = null;
                        }),
                        child: Text(_recovery ? l.useAuthenticator : l.useRecoveryCode),
                      ),
                    if (_step == _Step.password)
                      TextButton(onPressed: widget.onChangeServer, child: Text(l.changeServer)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
