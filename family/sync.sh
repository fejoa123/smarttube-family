#!/usr/bin/env bash
# SmartTube Family: pull upstream SmartTube, re-apply our changes, build, sign, write the update feed.
#
#   family/sync.sh            build only if upstream released a new version since the last build
#   family/sync.sh --force    build now (after changing our own code: bump family.properties first)
#
# Exit codes: 0 = built or nothing to do, 2 = upstream merge conflict (nothing shipped), 3 = build failed.
# Output: family/out/ (APKs + smarttube_family.json). Publishing is done by family/publish.sh.
# Our changes live on branch `family`; see FAMILY.md for the list and the rules that keep merges clean.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
OUT="$ROOT/family/out"
STATE="$ROOT/family/.last-upstream"
FORCE="${1:-}"

export JAVA_HOME="/c/Users/joetm/.jdks/jdk-17"
export PATH="$JAVA_HOME/bin:$PATH"
export JAVA_TOOL_OPTIONS="-Djavax.net.ssl.trustStoreType=Windows-ROOT"  # this PC's TLS needs the Windows store

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
upstream_version() { git show "$1:smarttubetv/build.gradle" | sed -n 's/.*versionName "\([^"]*\)".*/\1/p' | head -1; }

[ "$(git rev-parse --abbrev-ref HEAD)" = "family" ] || { log "not on branch family"; exit 1; }
[ -z "$(git status --porcelain --untracked-files=no)" ] || { log "working tree has uncommitted changes; commit them first"; exit 1; }

git fetch origin --quiet
UP_VER="$(upstream_version origin/master)"
LAST="$(cat "$STATE" 2>/dev/null || true)"

if [ "$UP_VER" = "$LAST" ] && [ "$FORCE" != "--force" ]; then
    log "upstream still $UP_VER, nothing to do"
    exit 0
fi

log "upstream $UP_VER (last built: ${LAST:-none}), merging"
if ! git merge --no-edit origin/master >/dev/null; then
    git merge --abort || true
    log "MERGE CONFLICT with upstream $UP_VER; family branch left as it was, nothing built"
    exit 2
fi
git submodule update --init --recursive --quiet

log "building"
if ! ./gradlew.bat --no-daemon -q assembleStfamilyRelease; then
    log "BUILD FAILED for upstream $UP_VER"
    exit 3
fi

APK_DIR="$ROOT/smarttubetv/build/outputs/apk/stfamily/release"
VERSION_NAME="$(ls "$APK_DIR" | sed -n 's/^SmartTube_family_\(.*\)_universal\.apk$/\1/p')"
VERSION_CODE="$(python -c "import json,sys;d=json.load(open(sys.argv[1]));print(d['elements'][0]['versionCode'])" "$APK_DIR/output-metadata.json")"

rm -rf "$OUT"; mkdir -p "$OUT"
cp "$APK_DIR"/*.apk "$OUT/"
python "$ROOT/family/make_feed.py" "$OUT" "$VERSION_NAME" "$VERSION_CODE" "$UP_VER"

echo "$UP_VER" > "$STATE"
log "built $VERSION_NAME ($VERSION_CODE) -> $OUT"
