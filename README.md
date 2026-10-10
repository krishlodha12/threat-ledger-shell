# Threat Ledger shell

A small native iPhone app that shows [Threat Ledger](https://krishlodha12.github.io/cyber-intel-scraper/)
full screen.

- Links to other sites open in Safari. Pull down to refresh. The page reloads itself after
  30 minutes in the background.
- It works offline once it has been opened online one time. The app turns on WebKit
  service workers for this one domain (`WKAppBoundDomains`), so the site's own offline cache
  works inside the app.
- Dark theme to match the site. Shows on the Home Screen as **Ledger+** so it is not
  confused with the Home Screen web app.

## Build

GitHub Actions builds it on a free macOS runner (`.github/workflows/build.yml`):

- `swiftc` directly, without an Xcode project, using the newest stable Xcode on the runner.
- The output is **unsigned**. This repo holds no certificates, profiles, Apple ID or secrets.
- The workflow builds twice from separate folders and fails if the two `.ipa` files differ.
- The artifact `TLShell-unsigned` contains the `.ipa`, `SHA256SUMS` and `BUILD-INFO.txt`,
  which records the Xcode and SDK versions.

To build on a Mac yourself: `bash scripts/build-unsigned.sh build`.

## Install

Signing happens on your own PC with your own free Apple ID, using forge, the companion
Windows tool:

```
forge install TLShell-unsigned.ipa
```

Free signing lasts 7 days, and forge refreshes it automatically. Never upload a signed
copy anywhere: it carries the signer's name and device IDs.

## Details

| | |
|---|---|
| Bundle ID | `dev.forge.tlshell`. The signer adds `.<TEAMID>` when signing. |
| Minimum iOS | 17.0 |
| Devices | iPhone, portrait |
| Icon | The site's own icon, at 120 and 180 px |

MIT license.
