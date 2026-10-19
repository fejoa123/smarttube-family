#!/usr/bin/env bash
# SmartTube Family: pull the latest upstream SmartTube release, re-apply our changes, build, sign, write the update feed.
#
#   family/sync.sh            build only if upstream released a newer version (on our channel) than the one merged
#   family/sync.sh --force    build now even without a new upstream release (after changing our own code:
#                             bump familyRevision in family.properties first)
#
# Follows upstream RELEASE TAGS, not master (master can hold unreleased work):
# upstreamChannel=stable -> tags like 32.56s, beta -> every release (32.68 and 32.56s alike). See family.properties.
#
# Exit codes: 0 = built or nothing to do (last line "BUILT <versionName>" when it built),
#             1 = not runnable (wrong branch / uncommitted changes), 2 = upstream merge conflict (nothing built),
#             3 = build failed.
# Output: family/out/ (APKs + smarttube_family.json). Publishing is done by family/publish.sh.
# Our changes live on branch `family`; see FAMILY.md for the list and the rules that keep merges clean.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
OUT="$ROOT/family/out"
FORCE="${1:-}"

export JAVA_HOME="/c/Users/joetm/.jdks/jdk-17"
export PATH="$JAVA_HOME/bin:$PATH"
export JAVA_TOOL_OPTIONS="-Djavax.net.ssl.trustStoreType=Windows-ROOT"  # this PC's TLS needs the Windows store

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
prop() { sed -n "s/^$1=//p" family.properties | tr -d '\r' | head -1; }
# versionCode / versionName from defaultConfig of smarttubetv/build.gradle at a commit or tag
gradle_field() { git show "$1:smarttubetv/build.gradle" | sed -n "s/^ *$2 \"\{0,1\}\([^\" ]*\)\"\{0,1\} *\r\{0,1\}$/\1/p" | head -1; }

[ "$(git rev-parse --abbrev-ref HEAD)" = "family" ] || { log "not on branch family"; exit 1; }
[ -z "$(git status --porcelain --untracked-files=no)" ] || { log "working tree has uncommitted changes; commit them first"; exit 1; }

CHANNEL="$(prop upstreamChannel)"; CHANNEL="${CHANNEL:-stable}"
case "$CHANNEL" in
    stable) TAG_RE='^[0-9]+\.[0-9]+s$' ;;
    beta)   TAG_RE='^[0-9]+\.[0-9]+s?$' ;;
    *)      log "unknown upstreamChannel '$CHANNEL' in family.properties"; exit 1 ;;
esac

git fetch origin --tags --force --quiet
# Highest release on the channel by upstream versionCode (tag names alone don't order 32.68 vs 32.68s)
TAG=""; TAG_CODE=0
for t in $(git tag -l | grep -E "$TAG_RE"); do
    c="$(gradle_field "$t" versionCode)"
    if [ -n "$c" ] && [ "$c" -gt "$TAG_CODE" ]; then TAG="$t"; TAG_CODE="$c"; fi
done
[ -n "$TAG" ] || { log "no upstream release tags found for channel $CHANNEL"; exit 1; }

HEAD_CODE="$(gradle_field HEAD versionCode)"

if [ "$TAG_CODE" -gt "$HEAD_CODE" ]; then
    UP_VER="$(gradle_field "$TAG" versionName)"
    log "upstream $CHANNEL release $TAG ($UP_VER) is newer than ours ($HEAD_CODE), merging"
    if ! git merge --no-edit -m "Merge upstream release $TAG into family" "$TAG" >/dev/null; then
        git merge --abort || true
        log "MERGE CONFLICT with upstream $TAG; family branch left as it was, nothing built"
        exit 2
    fi
    git submodule update --init --recursive --quiet
elif [ "$FORCE" = "--force" ]; then
    UP_VER="$(gradle_field HEAD versionName)"
    log "no newer upstream $CHANNEL release (latest $TAG); rebuilding $UP_VER as asked"
else
    log "up to date: latest upstream $CHANNEL release is $TAG, ours is versionCode $HEAD_CODE"
    exit 0
fi

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

log "built $VERSION_NAME ($VERSION_CODE) -> $OUT"
echo "BUILT $VERSION_NAME"
