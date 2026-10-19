# SmartTube Family

Joe's build of SmartTube (upstream: yuliskov/SmartTube, MIT). Branch `family` = upstream `master` + the changes below.
Installs beside the official app as **SmartTube Family** (`nz.joe.smarttube`).

## What it adds

- **Who's watching? picker** (`common/.../presenters/dialogs/ProfilePickerPresenter.java`).
  One press on the top-bar account button opens it (upstream cycled to the next account instead).
  Rows: YouTube Kids (only if the official Kids app is installed; opens it and stops any SmartTube video),
  every signed-in account with its avatar, Guest. Also shown at launch when Settings > Accounts >
  "Select account on boot" is on.
- Flavor `stfamily` (`smarttubetv/build.gradle`, `smarttubetv/src/stfamily/`): own package, FAMILY banner,
  `<queries>` for the Kids packages (Android 11+ package visibility), own search authority
  (`nz.joe.smarttube.search_provider`, overrides the hard-coded fdroid value from leanbackassistant).

## Keeping merges clean (rules)

- New behaviour goes in NEW files. Upstream files get one-line hooks marked `// family build`.
  Current hooks: `SplashPresenter.showAccountSelectionIfNeeded`, `NavigateTitleView` account orb click.
- Library modules have no `stfamily` flavor; the app falls back to their `stfdroid` variant
  (`matchingFallbacks`). So `BuildConfig.FLAVOR` inside `common` is `stfdroid` - never branch on it.
- Strings for our features: `common/src/main/res/values/family_strings.xml`.

## Versioning

versionCode = upstream versionCode * 100 + `familyRevision` (`family.properties`); versionName gets `-family.N`.
Bump `familyRevision` when OUR code changes without an upstream release; keep it < 100.

## Build / update

- `family/sync.sh` - merge new upstream release, build, write `family/out/` (APKs + `smarttube_family.json`).
  `--force` rebuilds now. Exit 2 = merge conflict (nothing built), 3 = build failed.
- Update feed format: `family/make_feed.py` (base URL in `family/feed_base_url.txt`).
- Toolchain: JDK 17 `~/.jdks/jdk-17`, SDK platform 34 + build-tools 30.0.3, Gradle 7.5 via wrapper.
  `JAVA_TOOL_OPTIONS=-Djavax.net.ssl.trustStoreType=Windows-ROOT` is required on this PC.
  `local.properties` must use forward slashes (`sdk.dir=C:/Users/...`); backslashes are eaten as escapes.
- AVG blocked `gradle-launcher-7.5.jar` on first run (2026-10-19); Joe added an exception.

## Signing key

`C:\Users\joetm\.android-signing\smarttube-family\` (jks + keystore.properties). `keystore.properties` in the
repo root is a copy and is excluded via `.git/info/exclude`. **Losing the key = every device must uninstall
and reinstall (settings lost unless backed up).**

## Moving from the official SmartTube

Official app: Settings > Backup > Backup. Family app: Settings > Backup > Restore (it scans every
`data/<package>/` backup folder). Accounts, settings and history come across.
