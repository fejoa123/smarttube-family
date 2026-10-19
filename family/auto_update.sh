#!/usr/bin/env bash
# Daily job (Windows Task Scheduler "SmartTube Family Update", runs as joetm, catches up if the PC was off):
# sync.sh, then publish.sh when it built something, then a phone push through ntfy.sh (same topic as the
# HA watchdog, C:\Users\joetm\ha-tools\.ntfy-topic). Silent when there is nothing new.
#
# Pushes: updated (devices will offer it on next launch), merge conflict / build / publish failure
# (needs an agent: open A:\smarttube, read FAMILY.md). "Uncommitted changes" (someone is mid-work) only logs.
# Log: family/auto_update.log (kept to the last 3000 lines).
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
LOG="$ROOT/family/auto_update.log"
NTFY_TOPIC_FILE="C:/Users/joetm/ha-tools/.ntfy-topic"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }

notify() {
    # python, not curl: AVG intercepts HTTPS and only the Windows store (which python uses) trusts it.
    # The topic file has a UTF-8 BOM, hence utf-8-sig.
    python - "$NTFY_TOPIC_FILE" "$1" <<'EOF' >> "$LOG" 2>&1 || log "ntfy push failed"
import sys, urllib.request
topic = open(sys.argv[1], encoding="utf-8-sig").read().strip()
req = urllib.request.Request("https://ntfy.sh/" + topic, data=sys.argv[2].encode("utf-8"),
                             headers={"Title": "SmartTube Family", "Tags": "tv"})
urllib.request.urlopen(req, timeout=20).read()
EOF
}

log "---- auto update"
OUT="$(bash family/sync.sh 2>&1)"; RC=$?
echo "$OUT" | grep -vE '^(Note: |warning: )' | tail -25 >> "$LOG"
BUILT="$(echo "$OUT" | sed -n 's/^BUILT //p' | tail -1)"

# A build whose publish failed on an earlier run: sync now says "up to date", so publish what is in family/out
if [ "$RC" = 0 ] && [ -z "$BUILT" ] && [ -f family/out/smarttube_family.json ]; then
    PENDING="$(python -c "import json;d=json.load(open('family/out/smarttube_family.json'));print([k for k in d if k!='package'][0])")"
    if ! gh release view "v$PENDING" --repo fejoa123/smarttube-family >/dev/null 2>&1; then
        log "found unpublished build $PENDING, publishing it"
        BUILT="$PENDING"
    fi
fi

case "$RC" in
    0)
        if [ -n "$BUILT" ]; then
            if bash family/publish.sh "Automatic build." >> "$LOG" 2>&1; then
                log "published $BUILT"
                notify "Updated to $BUILT. The TV and car will offer it next time the app opens."
            else
                log "PUBLISH FAILED for $BUILT"
                notify "Built $BUILT but publishing it failed. Log: A:\\smarttube\\family\\auto_update.log"
            fi
        fi
        ;;
    1) log "sync not runnable (see above); no push" ;;
    2) notify "New SmartTube release clashes with our changes (merge conflict). Nothing shipped; ask Claude to fix it in A:\\smarttube." ;;
    3) notify "New SmartTube release merged but the build failed. Nothing shipped; ask Claude to fix it in A:\\smarttube." ;;
    *) notify "Update job failed (exit $RC). Log: A:\\smarttube\\family\\auto_update.log" ;;
esac

tail -n 3000 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
exit "$RC"
