#!/usr/bin/env python3
"""rbk_fixpaths.py — rewrite the track-path prefix inside rekordbox's master.db.

Used by rbk-fixpaths.sh after a restore on a Mac whose user name differs from the old one
(cloud-folder paths contain the user name, e.g. /Users/<name>/Library/CloudStorage/...).

    python3 rbk_fixpaths.py --db ~/Library/Pioneer/rekordbox7/master.db \
        --old /Users/olduser/ --new /Users/newuser/ [--apply]

Dry run by default. With --apply a safety copy master.db.pre-fixpaths_<timestamp> is made first.
Requires:  python3 -m pip install --user pyrekordbox
Exit codes: 0 ok · 1 error · 2 pyrekordbox missing or database could not be opened
"""
import argparse
import datetime
import os
import shutil
import sys


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--db", required=True, help="path to master.db")
    ap.add_argument("--old", required=True, help="old prefix, e.g. /Users/olduser/")
    ap.add_argument("--new", required=True, help="new prefix, e.g. /Users/newuser/")
    ap.add_argument("--apply", action="store_true", help="write the changes (default: dry run)")
    a = ap.parse_args()

    old, new = a.old, a.new
    if not old.endswith("/") or not new.endswith("/"):
        print("   --old and --new must both end with '/'")
        return 1
    if not os.path.isfile(a.db):
        print(f"   database not found: {a.db}")
        return 1

    try:
        from pyrekordbox import Rekordbox6Database  # noqa: WPS433
    except ImportError:
        print("   pyrekordbox is not installed. Install it with:")
        print("      python3 -m pip install --user pyrekordbox")
        print("   then run this tool again.")
        return 2

    try:
        db = Rekordbox6Database(path=a.db)
    except Exception as exc:  # noqa: BLE001 — pyrekordbox raises several types; show its own advice
        print(f"   could not open the database: {exc}")
        print("   If the message mentions a missing key, follow pyrekordbox's instructions")
        print("   (e.g.  python3 -m pyrekordbox download-key ) and retry.")
        return 2

    rows = list(db.get_content())
    to_fix = [c for c in rows if c.FolderPath and c.FolderPath.startswith(old)]
    already = [c for c in rows if c.FolderPath and c.FolderPath.startswith(new)]
    other = len(rows) - len(to_fix) - len(already)

    print(f"   tracks in database:        {len(rows)}")
    print(f"   under old prefix (to fix): {len(to_fix)}")
    print(f"   already under new prefix:  {len(already)}")
    print(f"   under other locations:     {other}   (left untouched)")
    for c in to_fix[:5]:
        print(f"      {c.FolderPath}")
        print(f"   →  {new}{c.FolderPath[len(old):]}")

    if not to_fix:
        print("   nothing to change.")
        return 0
    if not a.apply:
        print("   dry run — nothing written. Re-run with --apply to rewrite these paths.")
        return 0

    stamp = datetime.datetime.now().strftime("%Y-%m-%d_%H%M%S")
    backup = f"{a.db}.pre-fixpaths_{stamp}"
    shutil.copy2(a.db, backup)
    print(f"   safety copy: {backup}")

    for c in to_fix:
        c.FolderPath = new + c.FolderPath[len(old):]
    db.commit()
    try:
        db.close()
    except Exception:  # noqa: BLE001
        pass
    print(f"   ✅ rewrote {len(to_fix)} track paths. Open rekordbox and check that the '!' marks are gone.")
    print("      (if something is wrong, quit rekordbox and copy the safety file back over master.db)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
