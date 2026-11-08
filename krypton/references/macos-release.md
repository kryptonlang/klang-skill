# macOS Bundles And Distribution

## Bundle First

`kcc source.ks -o binary` creates an ad-hoc-signed native executable, not an
application bundle or a distributable installer. A development `.app`, Developer
ID distribution, and Mac App Store submission are three different states.

The 2.4.9 checkout contains `scripts/build-objk-app.ks`; installed archives may
not ship that script. Locate it in a matching checkout instead of assuming it
exists in `/usr/local/krypton/scripts`.

```sh
export KRYPTON_ROOT="/absolute/path/to/krypton"
KCC="$KRYPTON_ROOT/bootstrap/kcc_driver_macos_aarch64"
"$KCC" -r "$KRYPTON_ROOT/scripts/build-objk-app.ks" \
  /absolute/path/to/app.ks MyApp \
  --out /absolute/path/to/dist/MyApp.app \
  --id org.example.myapp --version 0.1.0 --compiler "$KCC"
```

Optional `--icon /absolute/path/to/app.icns`. The app name must pass the
helper's safe executable-name check; the identifier and three-part numeric
version are validated. The helper creates/validates Info.plist, conditionally
adds icon metadata, checks compilation and ad-hoc signing, stages beside the
destination and preserves an existing bundle when compilation fails.

The basic helper is not a document-type/entitlement/resource deployment system.
Add only metadata/resources actually needed by the app and test them. Its
generic developer-tools category is a default, not a correct category for every
product. `CFBundleDocumentTypes` and file/URL routing need separate work.

If the executable name is `kweb`, the helper also embeds the CLI and compiler,
frontend/backend seeds, stdlib and headers. Do not strip that special payload or
rename the GUI back to `kweb_gui`. kweb's branded purple appearance is dark-mode
only; generic app templates should follow semantic system colors.

Check a built bundle:

```sh
plutil -lint /path/to/MyApp.app/Contents/Info.plist
codesign --verify --deep --strict --verbose=2 /path/to/MyApp.app
otool -L /path/to/MyApp.app/Contents/MacOS/MyApp
open /path/to/MyApp.app
```

The application must open, handle input, retain state correctly and Quit.
Inspect expected Apple system libraries; Objective-K does not mean no libobjc
or AppKit dependency. Verify copied/extracted bundles, not only the build tree.

## Developer ID Distribution

Only when release work is requested and signing identities are available:

1. Select the exact source revision, platform version and matching binaries.
   Record tests/skips and known limitations. Never silently publish a draft,
   push a branch or replace an already released signed asset.
2. Sign nested executables/helpers before the enclosing app, using Developer ID
   Application with hardened runtime and secure timestamps. Validate signatures.
   Do not assume `--deep` signing repairs an unknown bundle structure.
3. Sign installers with Developer ID Installer. The compiler repo's
   `scripts/build_pkg.ks` and `scripts/build_tarball_macos.ks` accept
   `KRYPTON_RELEASE_SIGN=1` and identity environment variables; inspect them before
   running because they stage/replace `releases/` files.
4. Submit pkg or ZIP payloads using `xcrun notarytool` and an existing Keychain
   profile. Never print credentials or embed passwords/API keys in scripts.
   A tar.gz is not the submission container: notarize a ZIP containing its
   signed payload, then staple the app and rebuild the final tarball.
5. Require `Accepted`, staple supported containers/apps, validate staples,
   signatures and Gatekeeper (`spctl --assess --type execute` for apps,
   `--type install` for pkg). A signature alone is not notarization.
6. Extract into a fresh directory. Set `KRYPTON_ROOT` to that extracted/installed
   payload and test its own driver/frontend/stdlib; do not accidentally use the
   conventional home checkout. Exercise kweb's embedded compiler separately.
7. Test pkg postinstall against an isolated target volume and tarball installs
   with temporary `PREFIX`/`BINDIR`/`APPDIR`. Do not overwrite `/Applications`,
   `/usr/local` or a user's existing Homebrew installation just to test packaging.
8. Compute SHA-256 after all signing/stapling/repacking, publish the correct
   platform assets only when authorized, then download and verify them again.

Certificate trust checks may fail in a restricted sandbox despite valid bytes;
diagnose trust access before re-signing, weakening Gatekeeper or changing keys.
Never bypass security warnings or disable validation to obtain a green test.

## Release Channels

macOS 2.4.9 is published at
<https://github.com/t3m3d/krypton/releases/tag/v2.4.9>. Linux remains 2.4.4,
Windows 2.3.0, VSIX 2.4.8. Keep these versions independent in notes, formulae,
download URLs and tests. Homebrew formulae should declare the actual version
and verify the platform's exact archive hash; `arm64` is not a version number.

For kweb deployments, build a project with `dist/`, use the actual FTP host and
username, and have the user supply the password in the secure GUI field. Blank
remote directory means the FTP login root. Do not prepend `public_html` (it may
already be the login root). Deploy only authorized files and verify live bytes;
never publish unrelated pages regenerated by another agent's work.

Mac App Store distribution additionally needs its own sandbox/entitlements,
provisioning, capabilities, identifiers, signing and submission/review work.
Developer ID notarization does not establish Store compliance, especially for
apps that execute arbitrary subprocesses, compile code or access arbitrary files.
