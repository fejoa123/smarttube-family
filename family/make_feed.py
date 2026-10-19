"""Write smarttube_family.json, the update feed SmartTube's built-in updater reads.

Usage: make_feed.py <out_dir> <version_name> <version_code> <upstream_version>

Format (SharedModules/appupdatechecker2 AppVersionChecker): a "package" object with download urls
(per-ABI lists are tried first, keyed by Build.SUPPORTED_ABIS[0]), plus one object per version.
Download urls are <base>/v<version_name>/<apk name> (one GitHub release per version, see publish.sh);
<base> comes from family/feed_base_url.txt.

Changelog (shown in the TV's update dialog): our lines from family/changelog.txt, then the bullet lines of
upstream's GitHub release notes for <upstream_version> (stable tag "<ver>s" first, then beta "<ver>").
Upstream notes are best effort: no network, no notes.
"""
import json
import os
import sys
import urllib.request

out_dir, version_name, version_code, upstream = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]
here = os.path.dirname(os.path.abspath(__file__))
MAX_UPSTREAM_LINES = 8

with open(os.path.join(here, "feed_base_url.txt"), encoding="utf-8") as f:
    base = f.read().strip().rstrip("/")

def url(abi):
    return f"{base}/v{version_name}/SmartTube_family_{version_name}_{abi}.apk"

def family_notes():
    path = os.path.join(here, "changelog.txt")
    if not os.path.exists(path):
        return []
    with open(path, encoding="utf-8-sig") as f:
        return ["Family: " + line.strip() for line in f if line.strip()]

def upstream_notes():
    for tag in (upstream + "s", upstream):
        try:
            req = urllib.request.Request(
                f"https://api.github.com/repos/yuliskov/SmartTube/releases/tags/{tag}",
                headers={"Accept": "application/vnd.github+json", "User-Agent": "smarttube-family"})
            with urllib.request.urlopen(req, timeout=20) as r:
                body = json.load(r).get("body") or ""
        except Exception:
            continue
        lines = [l.strip()[2:].strip() for l in body.splitlines() if l.strip().startswith(("- ", "* "))]
        return lines[:MAX_UPSTREAM_LINES]
    return []

feed = {
    "package": {
        "downloadUrlList": [url("universal")],
        "downloadUrlList_arm64-v8a": [url("arm64-v8a")],
        "downloadUrlList_armeabi-v7a": [url("armeabi-v7a")],
        "downloadUrlList_x86": [url("x86")],
    },
    version_name: {
        "versionCode": version_code,
        "changelog": family_notes() + [f"SmartTube {upstream}:"] + upstream_notes(),
    },
}

with open(os.path.join(out_dir, "smarttube_family.json"), "w", encoding="utf-8") as f:
    json.dump(feed, f, indent=2, ensure_ascii=False)
