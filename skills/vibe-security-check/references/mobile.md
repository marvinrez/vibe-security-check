# Mobile

An installed app is a binary in the attacker's hands. Everything shipped inside it is readable, and
everything it does can be observed and modified. That single fact drives this whole file.

Applies to native iOS and Android, React Native, Flutter and Expo.

## Nothing secret ships in the binary

There is no such thing as a hidden constant in a mobile app. Strings extract in seconds; obfuscation
raises the cost by minutes.

- API keys, service credentials, signing secrets: none of them belong in the app. If the app needs
  a privileged action, the app calls **your** server and your server holds the credential.
- In React Native and Expo, remember the JavaScript bundle is shipped in full, including anything
  prefixed `EXPO_PUBLIC_`. `scripts/bundle-secrets.sh` works on mobile bundles.
- Keys that must exist client-side (a Maps key, an analytics key) are restricted at the provider by
  bundle identifier and by API, so a copied key is useless elsewhere.

## Storage on the device

- **Credentials and tokens go in the platform keystore** — Keychain on iOS, Keystore on Android, via
  the framework's secure storage wrapper. Not `AsyncStorage`, not `localStorage`, not
  `UserDefaults`, not `SharedPreferences`, and not a plain file.
- **Assume the device may be rooted or jailbroken.** Secure storage raises the bar; it does not make
  extraction impossible. Keep long-lived, high-authority tokens off the device entirely — short
  sessions with refresh are the pattern.
- **Caches leak too.** Response caches, image caches, logs and crash reports accumulate personal
  data in places nobody audits.

## The server does not trust the client

Every check the app performs is advisory. Jailbreak detection, root detection, tamper checks and
certificate pinning are all speed bumps — worth having, never a control.

The consequences: purchase receipts are validated with the store's server, not accepted from the
app. Feature entitlements are decided server-side. "The app would never send that" is not an
argument, because the attacker is not using your app — they are using `curl` against your API, which
is why every check in `authorization.md` applies here unchanged.

## Transport

- **TLS everywhere, with no exception for development.** Look for cleartext exemptions left enabled:
  `NSAllowsArbitraryLoads` on iOS, `usesCleartextTraffic` or a permissive network security config on
  Android. These get switched on to make a local server work and are never switched back.
- **Certificate pinning** is worth it for high-value apps, with a planned rotation — a pinned
  certificate that expires bricks the installed base until people update.

## Biometrics

Biometric prompts authorize a *local* action. They do not authenticate to your server on their own.

The correct pattern: biometrics unlock a key held in the platform keystore, and that key releases a
credential the server can verify. An app that treats "the fingerprint check returned true" as
authorization has a client-side-only check wearing better clothes.

## Platform surface

- **Deep links and custom URL schemes** are an input channel any other app can invoke. Validate
  parameters, and never let a link perform a state change without confirmation.
- **Exported Android components** (activities, services, receivers) with `exported="true"` are
  callable by any installed app. Export only what must be.
- **Screenshots and the app switcher** capture whatever is on screen, including account balances and
  personal data. Mask sensitive screens on backgrounding.
- **Clipboard** is readable by other apps on older platforms. Copying a token or a password to it is
  a leak.

## Updates

Mobile has no instant rollback: a vulnerable version stays installed until people update, and some
never will. That changes the calculus for anything you might need to fix urgently — build a
server-side switch to disable a feature, because you cannot rely on shipping a patch quickly.
