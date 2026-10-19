"""Write smarttube_family.json, the update feed SmartTube's built-in updater reads.

Usage: make_feed.py <out_dir> <version_name> <version_code> <upstream_version>

Format (SharedModules/appupdatechecker2 AppVersionChecker): a "package" object with download urls
(per-ABI lists are tried first, keyed by Build.SUPPORTED_ABIS[0]), plus one object per version.
Download urls are <base>/<apk name>; <base> comes from family/feed_base_url.txt.
"""
import json
import os
import sys

out_dir, version_name, version_code, upstream = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]
here = os.path.dirname(os.path.abspath(__file__))

with open(os.path.join(here, "feed_base_url.txt"), encoding="utf-8") as f:
    base = f.read().strip().rstrip("/")

def url(abi):
    return f"{base}/SmartTube_family_{version_name}_{abi}.apk"

feed = {
    "package": {
        "downloadUrlList": [url("universal")],
        "downloadUrlList_arm64-v8a": [url("arm64-v8a")],
        "downloadUrlList_armeabi-v7a": [url("armeabi-v7a")],
        "downloadUrlList_x86": [url("x86")],
    },
    version_name: {
        "versionCode": version_code,
        "changelog": [
            f"SmartTube {upstream} from upstream",
            "Family: Who's watching? picker (YouTube Kids + accounts)",
        ],
    },
}

with open(os.path.join(out_dir, "smarttube_family.json"), "w", encoding="utf-8") as f:
    json.dump(feed, f, indent=2, ensure_ascii=False)
