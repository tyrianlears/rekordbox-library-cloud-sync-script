# Rekordbox Library Cloud Sync Script

**Automatic, subscription-free backup and restore of your rekordbox library — to any cloud folder (Google Drive, Dropbox, iCloud Drive, OneDrive, Box, Proton Drive, pCloud, MEGA, Nextcloud, Sync.com…), an external disk or any folder you choose. macOS, rekordbox 7 (and 6).**

rekordbox's own *Cloud Library Sync* needs a paid Creative/Professional plan (the Free plan syncs 20 tracks, or 1,000 with registered hardware). If your music already lives in a cloud folder and you use one Mac, you don't need it: this kit keeps the part a subscription really protects — your **database** (playlists, hot cues, memory cues, beat grids, tags, ratings) and the **analysis data** (waveforms, grids) — mirrored into your cloud folder automatically, with dated snapshots you can go back to, a one-click restore, and a tested path to a new Mac.

It was built in a conversation with Claude for a real library (5,000+ tracks in a cloud folder) and then made universal: nothing in it depends on a particular cloud service — the kit only needs a folder that shows up in Finder.

> The Music folder is never written to — every part of the kit treats it as read-only.

## What it does

| | |
|---|---|
| **Automatic backups** | A background job checks every 30 min and backs up shortly after each rekordbox session; a daily 03:00 run does housekeeping. Runs only when rekordbox is closed. |
| **Notification after every backup** | "rekordbox backup ✓ · 14:32 · 12 files updated + daily snapshot · 4s". Skipped runs stay silent; problems always notify. |
| **`latest/` mirror + `history/` snapshots** | An exact, incremental mirror of the library (incl. analysis data → no re-analysis after a restore) plus dated database snapshots: 14 daily, first-of-month for 6 months, 10 manual. |
| **Small macOS app** | `rekordbox Backup.app`: **Back up now** · **Pause / Resume automatic backups** · **More…** (Restore, Settings, restore drill, rollback, check music, fix paths, self-test, log). Every action also exists as a double-click `.command` file. |
| **Emergency restore** | Puts the library back from `latest` or from any snapshot. Your current library is moved aside first, so a restore can always be undone (**rollback**). |
| **Restore drill** | Restores into a scratch folder and verifies it — proves the backup works without touching the live library. |
| **New-laptop guide** | Same-username trick, cloud folder → *Make available offline* → **Check music** tool (counts online-only placeholder files), rekordbox install, restore, what to verify, **Fix paths** if the username differs. |
| **Settings wizard** | Native folder pickers for the rekordbox library, the backup destination (every cloud folder / external disk found on the Mac is listed) and the optional music folder. Safety rules refuse a destination inside the Music folder, inside the library, or the home folder itself. |

## How it works (in one paragraph)

`rsync` mirrors `~/Library/Pioneer` (database + `USBANLZ` analysis files) and `~/Library/Application Support/Pioneer` (settings) into `<destination>/latest/`. Two `launchd` agents run the backup script (`--auto` every 1800 s, `--auto --daily` at 03:00). The script skips when rekordbox is running (`pgrep -x rekordbox`), when the destination is not mounted, or when nothing changed since the last stamp; otherwise it mirrors, verifies that `master.db` is in the mirror, files a dated snapshot when the database fingerprint changed, prunes old snapshots and posts a notification. Pause/Resume = `launchctl bootout` + `disable` / `enable` + `bootstrap`, so a pause survives reboots. Restore = rename the live folders aside → copy from the mirror → verify → (on failure) undo. Everything is bash 3.2-compatible (the bash that ships with macOS) plus one optional Python helper (`Fix paths`, using [pyrekordbox](https://github.com/dylanljones/pyrekordbox)).

## Quick start

1. **Download** this repository (green *Code* button → *Download ZIP*) or clone it, and unzip.
2. Make sure your cloud app (Google Drive, Dropbox, iCloud, OneDrive, …) is running and signed in, and that your music folder is kept *on this Mac* ("available offline") if it lives in the cloud — see *Supported destinations* below.
3. Quit rekordbox. In Finder open the `kit` folder, **right-click `Install.command` → Open → Open**.
4. Answer the three-dialog wizard: library folder (detected), where backups go, optional music folder. Say **Y** to the first backup.
5. Open `~/Applications/rekordbox Backup.app` → **More… › Restore drill** once, to prove the backup restores cleanly.

That's it — backups now run by themselves. The full guide follows.

**Requirements:** macOS 12 or newer (Apple silicon or Intel), rekordbox 7 or 6 (Free plan is fine), your music in any folder that is on this Mac (a cloud folder that streams files on demand must have the music folder kept offline). No Homebrew, no extra software. Windows is not supported (the scheduler, the app and the folder layout are macOS-specific).

## Supported destinations

Anything that appears as a folder in Finder can hold the backups. The wizard lists what it finds on the Mac and always offers **Other folder…** for everything else (NAS, network share, a second internal disk).

| Destination | Detected automatically | Keep the music folder on the Mac (right-click in Finder) |
|---|---|---|
| Google Drive for desktop | ✅ (Stream and Mirror layouts, localised "My Drive" names) | **Make available offline** |
| Dropbox | ✅ | **Make available offline** (Dropbox › Available offline) |
| iCloud Drive | ✅ | **Download Now**, and **Keep Downloaded** (or turn off *Optimise Mac Storage*) |
| OneDrive | ✅ | **Always Keep on This Device** |
| Box Drive | ✅ | **Make Available Offline** |
| Proton Drive, pCloud, MEGA, Nextcloud, Sync.com | ✅ (default folders) | see the app's own "keep offline" option |
| External disk / USB SSD | ✅ (writable volumes under `/Volumes`) | — (always local; plug it in for backups to run) |
| Any other folder, NAS, network share | via **Other folder…** | — |

Two things matter for every service: the cloud app must be running and signed in when a backup is due (otherwise the run is skipped and retried later — nothing breaks), and the *music* folder must be fully downloaded, because rekordbox cannot play placeholder files. **Check music folder** in the app tells you whether it is.

---

## 1. What is in the folder

```
<your cloud folder or disk> › rekordbox-backup/
├── README.md (+ README.pdf if you keep one) this guide
├── NOTES.md                    build notes, sources, lessons learned
├── kit/                        the scripts — double-click Install.command to install
│   ├── Install.command         install / update / repair
│   ├── Uninstall.command
│   ├── commands/               one double-click file per action (same as the app buttons)
│   ├── rbk-setup.sh            the folder wizard (first launch and Settings…)
│   ├── rbk-backup.sh           backup engine (used by the schedule and the app)
│   ├── rbk-restore.sh          restore, restore drill, rollback
│   ├── rbk-toggle.sh           pause / resume the automatic backups
│   ├── rbk-status.sh · rbk-checkmusic.sh · rbk-selftest.sh
│   ├── rbk-fixpaths.sh + rbk_fixpaths.py   new-Mac path fixer
│   ├── rekordbox-backup.applescript   source of the app
│   └── launchd/                schedule definitions
├── latest/                     exact mirror of your library (incl. analysis data)
├── history/                    dated snapshots of the database (daily_… / manual_…)
├── official/                   rekordbox's own "Backup Library" zips (monthly)
└── logs/                       copy of the recent log
```

On the Mac the kit installs itself into `~/Library/Application Support/rekordbox-backup/`, the schedule into `~/Library/LaunchAgents/`, and the app **rekordbox Backup.app** into `~/Applications/`.

---

## 2. Install on this Mac (first launch)

1. If your backups will live in a cloud folder, make sure that cloud app is running and signed in. If your music is in a cloud folder, it should be kept **on this Mac / available offline** (see *Supported destinations* and §6.2).
2. In Finder open the kit folder (`rekordbox-backup › kit` next to your backups, or the downloaded copy).
3. **Right-click `Install.command` → Open → Open.** (First time only: macOS blocks double-clicking a downloaded script. If it still refuses: System Settings › Privacy & Security › *Open Anyway*.)
4. **The folder wizard** appears — three short dialogs:
   - **rekordbox library folder.** The kit detects `~/Library/Pioneer` and checks that `master.db` is inside. Press **Use this folder**, or **Choose another…** if your library lives elsewhere (for example after *Preferences › Advanced › Database management › Move Database*).
   - **Where the backups go.** A list of every cloud folder and external disk found on this Mac; pick one, or **Other folder…** to browse. A folder called `rekordbox-backup` is created inside the place you choose. Safety rules are enforced: the backup folder can never be inside the Music folder, inside the rekordbox library, or be your home folder itself — the wizard says so and lets you choose again.
   - **Music folder (optional).** Only used by *Check music folder*; never written to. Skip it if you like.
   - A summary follows — press **Install**.
   - **Tip for every folder window:** the `Library` folder is hidden by default. Press **⌘⇧G** (Command-Shift-G), paste the path — e.g. `~/Library/Pioneer` — and press Enter; the window jumps straight there. `~` means your home folder. (⌘⇧. shows hidden folders too.)
5. The installer then copies the scripts, schedules the automatic backups, builds the app, sends a **test notification**, runs a self-test and offers to run the **first backup** (say **Y**; the first run copies the whole library, later runs take seconds). The app opens at the end.
6. If macOS asks whether Terminal (or the app) may access files, click **Allow** — the backup needs to read `~/Library` and write into the backup folder. If it asks whether **Script Editor** may send notifications, click **Allow** — that is where the "backup ✓" notifications come from.
7. Optional: drag `~/Applications/rekordbox Backup.app` to the Dock. The `kit/commands/` folder holds the same actions as double-click files if you prefer those.

Re-running `Install.command` at any time is safe: it updates the scripts and repairs the schedule without touching backups. To change folders later, use the app → **More… › Settings…** (or `kit/commands/Settings (change folders).command`) — the same wizard, pre-filled with your current choices. If the backup destination changes, the next run does a full mirror to the new place.

Opened the app before installing? It shows a **Set up…** button that asks for the kit folder and runs the installer for you.

---

## 3. Everyday use

**Nothing to do.** Every 30 minutes a background job checks: if rekordbox is closed and something changed, it mirrors the library into `latest/` (seconds). Once a day it also files a dated database snapshot into `history/`, tidies old snapshots, and warns you if no backup has succeeded for 3 days. If the Mac was asleep at 03:00 the daily run happens when it wakes.

**The app** (`rekordbox Backup.app`) shows the status (last backup, whether automatic backups are ON or PAUSED and when the next check is due, backup folder, rekordbox) and three buttons:

| Button | What it does |
|---|---|
| **Back up now** | Immediate backup + a `manual_…` snapshot. If rekordbox is open it offers to quit it first. A Terminal window shows progress and ends with ✅. |
| **Pause automatic backups** / **Resume automatic backups** | The label shows the real state. Pause stops the schedule until you press Resume — it stays paused even after a restart. Back up now and Restore keep working while paused. |
| **More…** | **Restore… (emergency, see §5)** · **Settings… (change the library / backup / music folder)** · Full status · Check music folder · Restore drill · Restore rollback · Fix paths · Self-test · Open backup folder · View log |

**The same buttons as files:** `kit/commands/` contains `Back up now.command`, `Pause auto-backup.command`, `Resume auto-backup.command`, `Settings (change folders).command`, `Restore (emergency).command`, `Restore drill (safe test).command`, `Restore rollback.command`, `Status.command`, `Check music folder.command`, `Fix paths (new Mac).command`, `Self-test.command`. Double-click any of them (first time: right-click → Open).

**Notifications:** after **every completed backup** you get a macOS notification like *"rekordbox backup ✓ — 14:32 · 12 files updated + daily snapshot · 4s"*. Runs that are skipped (rekordbox open, nothing changed) stay silent so you are not spammed; problems always notify, and so does a stale backup (3 days). Pause and Resume confirm with a notification too. Prefer silence for the automatic runs? Set `NOTIFY_SUCCESS=0` in `config.sh`.

**Once a month (and always before changing Mac):** in rekordbox choose **File › Library › Backup Library** and save the zip into `rekordbox-backup/official/`. This is Pioneer's own, officially supported backup format — belt and braces on top of the kit.

**Good habit:** run **More… › Restore drill** every few months. It restores the backup into a scratch folder and verifies it, without touching your real library, so you *know* the backup works before you ever need it.

---

## 4. What exactly is backed up

| Source on the Mac | Goes to | Contains |
|---|---|---|
| the rekordbox library folder (default `~/Library/Pioneer/`) | `latest/Pioneer/` | `master.db` (playlists, cues, tags, grids), `master.backup.db`, and `share/…/USBANLZ` analysis files (waveforms, beat grids) — restoring these avoids re-analysing your whole collection |
| the settings folder (default `~/Library/Application Support/Pioneer/`) | `latest/ApplicationSupport-Pioneer/` | rekordbox settings, incl. where the database lives |
| database files only (no `share/`) | `history/daily_YYYY-MM-DD/`, `history/manual_…/` | point-in-time copies of the database |

Excluded: log folders, caches, `.DS_Store`. **Not included on purpose:** the music files — keep those in your cloud folder or on a disk of their own.

Retention: 14 daily snapshots, then the first snapshot of each month for 6 months, and the 10 newest manual snapshots. Most cloud services add their own version history on top (Google Drive and Dropbox keep earlier versions of changed files for 30 days on their basic plans).

---

## 5. Emergency restore (same Mac)

Use it when rekordbox will not open, the collection looks empty or damaged, or you want to go back to how the library was on a given day.

1. Open **rekordbox Backup.app → More… → Restore…** (or double-click `kit/commands/Restore (emergency).command`). Want to rehearse first? More… › Restore drill.
2. A Terminal window lists the restore points:
   - `[0] latest` — the full library exactly as it was at the last backup (**choose this in almost every case**);
   - `daily_…` / `manual_…` — the full library from `latest` **plus** the database as of that date (use this to undo a bad editing session).
3. Type the number, then type `RESTORE` to confirm. rekordbox is quit automatically if it is open.
4. Your current library is first moved aside to `<library folder>.pre-restore_<date>` — e.g. `~/Library/Pioneer.pre-restore_2026-08-31_1432` (an instant rename, so nothing is lost), then the backup is copied back and verified (file count, size, `master.db` present at the right place). If the verification fails, the kit puts your previous library back by itself.
5. Open rekordbox. Check a playlist, play two or three tracks, look at the waveforms and hot cues.
6. Not happy? **More… › Restore rollback** puts the pre-restore library back in seconds. The kit keeps the last 2 pre-restore copies next to the library folder; delete them when you are sure everything is fine.

---

## 6. Moving to a new laptop

### 6.1 Before you leave the old Mac
- Open the app → **Back up now** and wait for ✅.
- In rekordbox: **File › Library › Backup Library** → save into `rekordbox-backup/official/`.
- Note the rekordbox version (rekordbox › About) — it is also written in `latest/BACKUP-INFO.txt`.
- Best possible move: give the new Mac **the same macOS user name** (short name, the one in `/Users/<name>`). Then every path is identical and no fixing is needed.

### 6.2 New Mac — the cloud app and the music
1. Install your cloud app (Google Drive for desktop, Dropbox, OneDrive, Box… — iCloud Drive is built in), sign in with the same account, and let it show your folders in Finder (the file list arrives before the files).
2. In Finder, right-click your `Music` folder and choose the *keep on this Mac* option of your service — Google Drive / Dropbox: **Make available offline** · iCloud: **Download Now** then **Keep Downloaded** · OneDrive: **Always Keep on This Device** · Box: **Make Available Offline**. Do the same for the `rekordbox-backup` folder.
3. Wait for the download to finish — the cloud app's menu-bar icon shows progress. This downloads your whole music library, so it can take hours; plug the Mac in and keep it awake.
4. Verify with the kit later (**More… › Check music folder**): it must report **0 online-only files**. rekordbox cannot play placeholder files, so do not skip this.
5. Backups on an external disk instead? Just connect it — nothing to download.

### 6.3 rekordbox
1. Download and install **rekordbox 7** from rekordbox.com — the same version as on the old Mac or newer (rekordbox upgrades a database forward, never backward).
2. Open it once, sign in with your AlphaTheta / Pioneer DJ account (Free plan is fine), then **quit it**. This creates the folders the restore needs.

### 6.4 Install the kit and restore
1. Finder → `<your cloud folder or disk> › rekordbox-backup › kit` → right-click **Install.command → Open**. In the wizard choose `~/Library/Pioneer` (use anyway — it is empty until the restore), the same backup location (`rekordbox-backup` inside your cloud folder or on the disk) and the Music folder. Skip the first backup when asked (there is nothing to back up yet).
2. Open **rekordbox Backup.app → More… → Restore…** → choose `[0] latest` → type `RESTORE`. On a new Mac this also downloads `latest/` from the cloud, so allow a few minutes.
3. The Terminal window ends with ✅ RESTORE COMPLETE.

### 6.5 Check inside rekordbox
1. Open rekordbox. The collection count should match the old Mac; playlists, hot cues and waveforms should be there with **no re-analysis** running.
2. Play a few tracks from different folders.
3. Orange **!** marks on tracks mean rekordbox cannot find the music files → §6.6.
4. Re-do the things that live outside the library: audio device and controller preferences, hardware registration, and export to USB if you use one.
5. From now on the schedule on the new Mac keeps backing up as before.

### 6.6 If the user name is different on the new Mac
The music paths in the database contain the user name (for example `/Users/<name>/Library/CloudStorage/GoogleDrive-…/My Drive/Music/…`, `/Users/<name>/Dropbox/Music/…` or `/Users/<name>/Library/Mobile Documents/com~apple~CloudDocs/Music/…`), and so do the rekordbox settings files. Fix both in one go:

1. Quit rekordbox. Open the app → **More… › Fix paths**. It runs as a *dry run* first and shows: the old and new names, how many settings entries and how many tracks it would rewrite.
2. If the numbers look right, run it for real in the same Terminal window:
   `~/Library/Application\ Support/rekordbox-backup/bin/rbk-fixpaths.sh --apply`
3. Rewriting the database needs Python with the `pyrekordbox` library. If the tool says it is missing: `python3 -m pip install --user pyrekordbox` (if `python3` itself is missing, run `xcode-select --install` first). A safety copy of `master.db` is made before anything is written.
4. No-Python alternative: in rekordbox right-click one track with **!** → **Relocate**, point it to the file inside `Music`; rekordbox then offers to relocate the rest automatically.
5. Open rekordbox — the **!** marks should be gone.

---

## 7. How it works (technical brief)

- **Engine:** `rsync` mirrors `~/Library/Pioneer` and `~/Library/Application Support/Pioneer` into `latest/` (incremental, `--delete`, so `latest/` always equals the source). Snapshots copy everything except the `share/` analysis trees.
- **Folders:** chosen in the wizard and stored in `config.sh` as `LIBRARY_DIR`, `SETTINGS_DIR`, `BACKUP_DIR`, `MUSIC_DIR` (optional) and `DRIVE_ROOT` (optional: the cloud/disk root that must be mounted for a backup to run). The wizard is `rbk-setup.sh`; `Install.command --library … --backup … --music … --yes` installs without questions.
- **Schedule:** two launchd agents — `com.rekordbox-backup-kit.interval` (every 1800 s) and `…daily` (03:00, also housekeeping). Both run `rbk-backup.sh --auto`.
- **Pause / Resume:** `rbk-toggle.sh` unloads the two agents (`launchctl bootout`) **and** marks them disabled (`launchctl disable`), which is why a pause survives reboots; Resume re-enables and reloads them. The app reads the real launchd state every time it opens, so the button label cannot drift.
- **Safety rules built in:** skip if rekordbox is running (`pgrep -x rekordbox`); skip if the backup folder is not available (cloud app not running, disk unplugged); skip if nothing changed since the last stamp; one job at a time (lock); a backup is only marked successful if `master.db` is present in the mirror; a restore always keeps the previous library and can be rolled back; the `Music` folder is never written.
- **Change detection:** files newer than the last-backup stamp; snapshot only when the fingerprint of the database files changed.
- **Placeholders:** `Check music` counts files that have a size but no allocated blocks — how macOS File Provider clouds (Google Drive Stream, Dropbox, iCloud, OneDrive, Box) represent online-only files — and cross-checks the macOS `dataless` flag.
- **Logs:** `~/Library/Logs/rekordbox-backup/rekordbox-backup.log` (a copy of the tail in `rekordbox-backup/logs/`).
- **Settings:** `~/Library/Application Support/rekordbox-backup/config.sh` (folders, retention, stale threshold, notifications) — folders via the app's Settings…, the rest by editing the file. To change the schedule, edit the two plist files in `kit/launchd/` (`StartInterval` seconds / `Hour`) and re-run `Install.command`.

---

## 8. Troubleshooting

| Symptom | What to do |
|---|---|
| "Install.command cannot be opened because Apple could not verify it / unidentified developer" | Right-click → Open → Open. Or System Settings › Privacy & Security › scroll down › **Open Anyway**. |
| Log shows `Operation not permitted` | System Settings › Privacy & Security › **Full Disk Access** → add **Terminal**, **rekordbox Backup.app** and `/bin/bash` (in the file picker press ⌘⇧G and type `/bin/bash`). Then re-run the self-test. |
| Status says the backup folder is **not available** | The cloud app is not running or signed out, or the external disk is not connected. Fix that, wait a minute, run Back up now. Runs that were skipped meanwhile are simply retried. |
| I cannot see the `Library` folder in the folder window | It is hidden by default: press **⌘⇧G** and paste `~/Library/Pioneer` (or press ⌘⇧. to show hidden folders). |
| I picked the wrong folder | App → More… › **Settings…** and choose again. Changing the backup destination triggers a full mirror on the next run. |
| The wizard refuses my backup folder | It is inside the Music folder, inside the rekordbox library, or it is the home folder itself. Pick a separate folder (e.g. the root of your cloud drive, an external disk). |
| Every automatic run says "rekordbox is open" | rekordbox (or a stuck copy of it) is running — check Activity Monitor, quit it. Backups resume automatically. |
| Backup runs but is slow every time | The `rekordbox-backup` folder may be online-only (cloud "stream" mode). Right-click it in Finder → Make available offline. |
| No notifications appear | System Settings › Notifications → allow notifications for **Script Editor** / **rekordbox Backup**. |
| rekordbox says the database is in use after a restore | Quit rekordbox fully (⌘Q), wait 10 s, reopen. If it persists, run the restore again. |
| Tracks show **!** after a restore | Music not offline yet (§6.2 step 5) or different user name (§6.6). |
| App shows "Status unavailable" | The kit is not installed on this Mac — run `Install.command`. |
| Status says automatic backups **OFF** (not PAUSED) although you never paused them | The schedule is not loaded (a macOS update or a moved home folder can do this). Re-run `Install.command` — it reloads the schedule. |
| Paused by mistake | Open the app → **Resume automatic backups** (or `Resume auto-backup.command`). |
| Disk getting full after restores | Delete old `~/Library/Pioneer.pre-restore_…` and `…undone-restore_…` folders (the kit keeps the 2 newest). |
| Want to see what the schedule is doing | Open the app → More… › View log, or in Terminal: `tail -f ~/Library/Logs/rekordbox-backup/rekordbox-backup.log` |

Every script can also be run from Terminal with `--help` from `~/Library/Application Support/rekordbox-backup/bin/`.

---

## 9. Uninstall

Double-click `kit/Uninstall.command`. It removes the schedule, the app and the local scripts. Your backups and the rekordbox library stay untouched. To reinstall later: `Install.command`.

---

## References

Data-check legend: ✅ verified against the primary source · ⚠️ secondary source or partially verified, cite with care · ❌ not verifiable, do not cite

1. ✅ rekordbox — Cloud feature page (Free-plan sync limit of 20 tracks, 1,000 with registered hardware) — https://rekordbox.com/en/feature/cloud/
2. ✅ rekordbox — Library Sync FAQ (Google Drive supported; Stream mode recommended) — https://rekordbox.com/en/support/faq/library-sync-6/
3. ✅ Pioneer DJ News — Cloud Library Sync requires a Creative or Professional plan — https://www.pioneerdj.com/en/news/2024/rekordbox-for-ios-android-supports-google-drive/
4. ⚠️ Pioneer DJ forums (staff answer) — library location `~/Library/Pioneer/rekordbox`, copy works if the user name is identical, otherwise fix `pioneerDirectory` / `masterDbDirectory` in the settings file — https://forums.pioneerdj.com/hc/en-us/community/posts/206080446-Restore-Rekordbox-Library-from-exported-USB
5. ⚠️ Pioneer DJ community — Backup Library zip contains everything except music; beat grids live in the USBANLZ .DAT/.EXT files — https://community.pioneerdj.com/hc/en-us/community/posts/22979689281177-Rekordbox-Database-on-new-PC
6. ⚠️ DJ.Studio help — rekordbox 7 relocates its library files compared with version 6 — https://help.dj.studio/en/articles/8365382-locating-integration-folders
7. ⚠️ DeeJay Plaza — Backup & Restore rekordbox library, moving to another computer — https://www.deejayplaza.com/en/articles/rekordbox-backup
8. ✅ Google Drive Help — Use Google Drive files offline (Make available offline, Stream vs Mirror) — https://support.google.com/drive/answer/2375012?hl=en&co=GENIE.Platform%3DDesktop
9. ✅ pyrekordbox (open-source library used by Fix paths to edit master.db) — https://github.com/dylanljones/pyrekordbox
10. ✅ Apple — launchd job definitions: `man launchd.plist` and `man launchctl` (built into macOS Terminal)
11. ✅ Apple Support — Mac keyboard shortcuts: Shift-Command-G opens the Go to Folder window — https://support.apple.com/en-us/102650
12. ✅ Apple Support — Go directly to a specific folder on Mac (`~` = home folder; Option + Go menu reveals Library) — https://support.apple.com/en-in/guide/mac-help/mchlp1236/mac

Verified on the Mac only after the first run (see NOTES.md): exact rekordbox 7 folder names, openrsync flags on macOS Tahoe, placeholder detection, macOS file-access prompts.

---

## Contributing

Issues and pull requests are welcome. Please keep the two rules every change must respect: **nothing ever writes into the user's music folder**, and **nothing runs while rekordbox is open**. Build notes, the verification log and open items are in [NOTES.md](NOTES.md); the version history is in [CHANGELOG.md](CHANGELOG.md).

## Disclaimer

This is an independent, community project. It is not affiliated with, endorsed by or supported by AlphaTheta / Pioneer DJ. rekordbox is a trademark of its owner. Back up before you restore; use at your own risk.

## License

[MIT](LICENSE) © 2026 Nick Rosa
