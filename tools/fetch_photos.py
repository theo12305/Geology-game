"""Download a photo for every mineral and rock from Wikipedia/Wikimedia Commons.

Uses each entry's "wiki" article (its lead image) or an explicit "photo" Commons file name, saves a
320 px wide image to images/<id>.jpg (or .png) and records author and license in data/image_credits.json.
Runs in GitHub Actions (tools/../.github/workflows/photos.yml); needs only the Python standard library.
"""
import html
import json
import re
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
UA = {"User-Agent": "DeepStrataGeologyGame/1.0 (https://github.com/theo12305/Geology-game)"}
WIDTH = 320


def get(url: str) -> bytes:
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read()


def get_json(url: str) -> dict:
    return json.loads(get(url))


def lead_image_file(article: str) -> str:
    q = urllib.parse.urlencode({"action": "query", "titles": article, "prop": "pageimages",
                                "piprop": "name", "redirects": 1, "format": "json"})
    pages = get_json(f"https://en.wikipedia.org/w/api.php?{q}")["query"]["pages"]
    page = next(iter(pages.values()))
    return page.get("pageimage", "")


def commons_info(file_name: str) -> dict:
    q = urllib.parse.urlencode({"action": "query", "titles": f"File:{file_name}", "prop": "imageinfo",
                                "iiprop": "url|extmetadata", "iiurlwidth": WIDTH, "format": "json"})
    pages = get_json(f"https://commons.wikimedia.org/w/api.php?{q}")["query"]["pages"]
    page = next(iter(pages.values()))
    return page["imageinfo"][0]


def plain(text: str) -> str:
    return html.unescape(re.sub(r"<[^>]+>", "", text or "")).strip()


def main() -> int:
    credits_path = ROOT / "data" / "image_credits.json"
    credits = json.loads(credits_path.read_text()) if credits_path.exists() else {}
    entries = json.loads((ROOT / "data" / "minerals.json").read_text())["minerals"]
    entries += json.loads((ROOT / "data" / "rocks.json").read_text())["rocks"]
    failed = []
    for e in entries:
        try:
            file_name = e.get("photo") or lead_image_file(e["wiki"])
            if not file_name or file_name.lower().endswith(".svg"):
                failed.append(f"{e['id']}: no photo on '{e['wiki']}' (lead image: {file_name or 'none'})")
                continue
            info = commons_info(file_name)
            meta = info.get("extmetadata", {})
            ext = ".png" if info["thumburl"].lower().endswith(".png") else ".jpg"
            for old in (ROOT / "images").glob(f"{e['id']}.*"):
                old.unlink()
            (ROOT / "images" / f"{e['id']}{ext}").write_bytes(get(info["thumburl"]))
            author = plain(meta.get("Artist", {}).get("value", "")).splitlines()
            credits[e["id"]] = {
                "image": f"res://images/{e['id']}{ext}",
                "file": file_name,
                "author": (author[0].strip() if author else "") or "Unknown",
                "license": plain(meta.get("LicenseShortName", {}).get("value", "")),
                "source": info.get("descriptionurl", ""),
            }
            print(f"ok {e['id']}: {file_name} ({credits[e['id']]['license']})")
            time.sleep(0.3)
        except Exception as ex:  # keep going; report at the end
            failed.append(f"{e['id']}: {ex}")
    credits_path.write_text(json.dumps(credits, indent=2, ensure_ascii=False) + "\n")
    for f in failed:
        print("MISSING", f)
    return 0


if __name__ == "__main__":
    sys.exit(main())
