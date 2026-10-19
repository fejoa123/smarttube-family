#!/usr/bin/env bash
# Publish family/out/ (from sync.sh) as GitHub release v<versionName> on fejoa123/smarttube-family
# and push branch `family`. Devices pick it up through the feed in releases/latest (update_urls.xml).
#
#   family/publish.sh "optional extra release note"
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
OUT="$ROOT/family/out"
REPO="fejoa123/smarttube-family"

VERSION_NAME="$(python -c "import json;d=json.load(open('family/out/smarttube_family.json'));print([k for k in d if k!='package'][0])")"
TAG="v$VERSION_NAME"
CHANGES="$(python -c "import json,sys;d=json.load(open('family/out/smarttube_family.json',encoding='utf-8'));print('\n'.join('- '+l for l in d[sys.argv[1]]['changelog']))" "$VERSION_NAME")"
NOTES="SmartTube Family $VERSION_NAME (upstream yuliskov/SmartTube + Who's watching? picker).${1:+ $1}

$CHANGES

Install by hand: the universal APK works everywhere; Google TV Streamer = armeabi-v7a."

if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
    echo "release $TAG already exists; bump familyRevision in family.properties and rebuild"; exit 1
fi

git push --quiet "https://github.com/$REPO.git" family:family
gh release create "$TAG" --repo "$REPO" --target family --title "SmartTube Family $VERSION_NAME" --notes "$NOTES" \
    "$OUT"/*.apk "$OUT/smarttube_family.json"
echo "published $TAG"
