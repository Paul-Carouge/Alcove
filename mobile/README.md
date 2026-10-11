# Alcove mobile

Flutter app (Android + iOS). The user enters the URL of *their* server; the app checks `GET /health`
for API compatibility before anything else.

```sh
flutter pub get && flutter gen-l10n
flutter analyze && flutter test
flutter run            # debug builds accept http:// for a local server (Android emulator: http://10.0.2.2:8090)
```

- API client: `alcove_api`, generated from `packages/api-spec` (path dependency, never edit by hand).
- Theme: `lib/theme/tokens.g.dart` is generated from `packages/design-tokens`; widgets use `context.colors`
  and `AlcoveSpace`/`AlcoveRadius`, never literal colors or sizes.
- Strings: `lib/l10n/app_{en,fr}.arb`.
- Secrets (tokens) go through `SecureStore` only (Keystore / Keychain).
- Font: Inter (SIL OFL 1.1, see `assets/fonts/Inter-OFL.txt`), bundled; no runtime font downloads.
