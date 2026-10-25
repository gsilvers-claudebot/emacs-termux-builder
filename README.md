# emacs-termux-builder

GitHub Actions builds of [GNU Emacs for Android][emacs-android] and
[Termux][termux-app], signed with the same key so that Emacs can share
Termux's user ID (`com.termux`) and run Termux programs. Only arm64 is
built, which covers Pixel phones running GrapheneOS.

Each release holds two APKs:

| File                                        | What                                                       |
|---------------------------------------------|------------------------------------------------------------|
| `emacs-<ver>-29-arm64-v8a.apk`              | Emacs stable release, `--with-shared-user-id=com.termux`, Android 10+ |
| `termux-app_<tag>+emacs-termux-builder_arm64-v8a.apk` | Termux app release, apt-android-7 bootstrap      |

Releases are tagged `emacs-<ver>+termux-<ver>`, e.g.
`emacs-31.1+termux-0.118.3`.

## How it works

`.github/workflows/build.yml` runs daily and on demand:

1. **resolve**: finds the newest stable Emacs tag on
   [emacs-mirror][emacs-mirror] (`emacs-MAJOR.MINOR`, skipping pretests
   and release candidates) and the latest [Termux release][termux-app].
   The scheduled run stops here if a release for that pair already
   exists.
2. **emacs**: builds Emacs with NDK r27 (16 KB page size safe), the
   API 36 `android.jar`, and the ndk-build dependency ports from the
   [Android ports for GNU Emacs][sf] project: GnuTLS (with gmp, nettle,
   libtasn1, p11-kit), libxml2, tree-sitter, HarfBuzz, giflib,
   libjpeg-turbo, libpng and libtiff. The ports are pinned by SHA-256
   in [`ports.sha256`](ports.sha256). The build is a release
   (non-debuggable) build unless you ask for a debug one.
3. **termux**: builds Termux's release variant with Gradle, split to
   arm64 only. Gradle downloads the bootstrap packages from
   termux-packages and checks their hashes.
4. **package**: re-signs both APKs with `apksigner` using one key,
   checks that the two certificates match, and publishes a GitHub
   release whose notes link the exact upstream commits and port
   tarballs (which is also how the GPL source offer is met).

Pull requests that touch the workflow or scripts run the full build
but don't publish anything; the signed APKs are kept as a workflow
artifact.

To build on demand, open **Actions → Build Emacs + Termux → Run
workflow**. You can pin an Emacs tag (e.g. `emacs-30.2`) or Termux tag,
force a rebuild of an existing release, or build a debuggable Emacs.

The scripts in `scripts/` also run outside Actions on an x86-64 Linux
machine with the Android SDK, NDK and a JDK installed; read the
workflow for the exact versions.

## Signing key

Android only lets two apps share a user ID if they're signed with the
same key, and only lets an update install if it's signed with the same
key as the installed app. Pick one:

### Private key (recommended on GrapheneOS)

Nobody else can make an update that installs over your apps or joins
the `com.termux` user ID. Generate a key and store it as repository
secrets:

```sh
scripts/make-keystore.sh ~/secure/emacs-termux.jks
```

This needs `keytool` (any JDK) and an authenticated `gh`, and sets
`SIGNING_KEYSTORE_BASE64`, `SIGNING_KEYSTORE_PASSWORD` and
`SIGNING_KEY_ALIAS`. (`SIGNING_KEY_PASSWORD` is also read, if the key
password differs from the keystore password.) **Back up the keystore
and password offline.** Losing them means you can never update your
installs again without a wipe.

Costs:

- Every app in the `com.termux` shared user ID must carry this key.
  Termux:API, Termux:Widget, Termux:Boot, etc. from F-Droid or GitHub
  won't install alongside these builds; they'd have to be built here
  too (not done yet).
- Moving from apps signed with any other key means uninstalling both
  apps once (see below).

### Public `emacs.keystore` (the fallback)

If no `SIGNING_KEYSTORE_BASE64` secret is set, the workflow signs with
the `emacs.keystore` that ships in the Emacs source tree, the same key
the SourceForge Termux builds of Emacs use. Existing installs signed
with that key upgrade in place, and SourceForge builds can be mixed
in. The catch: the key is public, so anyone can sign an app that
installs over yours or joins the shared user ID and reads your Termux
and Emacs data. Releases signed this way say so in their notes, and
every release lists its certificate SHA-256.

## Installing

### First install, or switching keys

Android fixes an app's shared user ID at install time, and refuses
updates signed by a different key, so a key switch means a clean
install.

1. Back up Termux `$HOME` (e.g. `tar` it to shared storage after
   `termux-setup-storage`) and anything under Emacs's `~`.
2. Uninstall Emacs, then Termux.
3. Install **Termux first**, open it once so it unpacks its bootstrap.
4. Install **Emacs second**.
5. Restore your files.

### Updates with Obtainium

[Obtainium][obtainium] installs and updates straight from GitHub
releases. Add this repository twice:

| App    | Source URL                          | "Filter APKs by regular expression" |
|--------|-------------------------------------|-------------------------------------|
| Termux | `https://github.com/<you>/emacs-termux-builder` | `^termux-app_.*\.apk$`  |
| Emacs  | `https://github.com/<you>/emacs-termux-builder` | `^emacs-.*\.apk$`       |

Emacs keeps the same `versionCode` (30) across releases and every
release rebuilds Termux too, so Obtainium can't compare APK versions.
For both entries, leave "Use release tag/name as version"-style
detection on (the default for GitHub sources) and **turn off "Verify
version string extracted from APK"** if Obtainium complains that the
APK version doesn't match the tag.

## After installing

Put this in `early-init.el` so Emacs finds Termux's programs:

```elisp
(setenv "PATH" (format "%s:%s" "/data/data/com.termux/files/usr/bin"
                       (getenv "PATH")))
(push "/data/data/com.termux/files/usr/bin" exec-path)
```

Don't set `LD_LIBRARY_PATH`; the port's FAQ notes that it causes
library conflicts.

[emacs-android]: https://github.com/emacs-mirror/emacs/blob/master/java/INSTALL
[emacs-mirror]: https://github.com/emacs-mirror/emacs
[termux-app]: https://github.com/termux/termux-app
[sf]: https://sourceforge.net/projects/android-ports-for-gnu-emacs/files/
[obtainium]: https://github.com/ImranR98/Obtainium
