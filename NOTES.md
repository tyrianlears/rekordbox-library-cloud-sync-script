# NOTES — rekordbox backup kit (task memory for a 2.0)

Built 31 Aug 2026 by Claude with Nick Rosa. Version 1.2 (1.1 + folder wizard at first launch, Settings… button, any backup destination — universal kit).

## Decisions taken (and why)
- **No subscription needed:** rekordbox's own Cloud Library Sync is limited to 20 tracks on the Free plan (1,000 with registered hardware), so the kit replaces it for a single-Mac setup: music stays in Google Drive (Stream mode + "Available offline"), the library folders are mirrored to Drive by rsync.
- **Two layers:** `latest/` = full mirror incl. analysis data (no re-analysis after restore); `history/` = database-only dated snapshots (cheap, lets you go back in time). Retention 14 daily + first-of-month × 6 + 10 manual.
- **Cadence "Both":** launchd interval job every 30 min (backs up shortly after a session) + daily 03:00 job for housekeeping/stale alert. `RunAtLoad` is off on purpose so the installer's visible first backup never races a background run.
- **Safety:** never run while rekordbox is open (`pgrep -x rekordbox`); lock file; Drive-mounted check; backup only "successful" if `master.db` is in the mirror; restore = rename current library aside (instant, no extra space) → copy → verify → `--rollback` available; `Music` folder is read-only for every script (Nick's strict rule).
- **Universal kit (v1.2):** all four folders (`LIBRARY_DIR`, `SETTINGS_DIR`, `BACKUP_DIR`, optional `MUSIC_DIR`) are chosen in a wizard (`rbk-setup.sh`) at first launch and changeable from the app (More… › Settings… → `install.sh --reconfigure`). GUI = `osascript` dialogs (`display dialog`, `choose folder … with invisibles` so `~/Library` is visible, `choose from list` of detected destinations); every folder window's prompt carries the ⌘⇧G tip. Typed prompts when no GUI; `--library/--backup/--music/--yes` for unattended installs and tests. Destination candidates: Google Drive (Stream/Mirror, localised "My Drive" names), Dropbox, iCloud Drive, OneDrive, writable `/Volumes/*`; picking a root creates `<root>/rekordbox-backup`. Changing library or destination deletes the change stamp + snapshot fingerprint so the next run does a full mirror. launchd labels renamed to `com.rekordbox-backup-kit.*` (old `com.nickrosa.*` jobs are removed on install). Pre-restore safety copies sit next to the library folder (`<library>.pre-restore_<ts>`), unique per second.
- **Notifications after every backup (v1.1):** `NOTIFY_SUCCESS=1` by default; message = time · files updated · snapshot · seconds. Skipped runs stay silent by design (30-min cadence would otherwise nag). Failures and 3-day staleness always notify.
- **Pause/Resume (v1.1):** `rbk-toggle.sh` = `launchctl bootout` + `launchctl disable` (persists across reboots) / `enable` + `bootstrap`. The app's middle button label is computed from the real launchd state on every launch. Install.command runs `launchctl enable` before `bootstrap` (bootstrap fails on a disabled service) and clears the paused marker. On Linux the state is faked with `state/test-auto-loaded` for testing.
- **Restore moved under More…** (display dialog allows 3 buttons; Back up now / Pause·Resume / More… won). Every action also exists as `kit/commands/*.command` (fallback path = scripts next to the file, so they even work before install).
- **App = AppleScript applet** compiled on the Mac by `osacompile` (no signing needed; long actions open Terminal windows for visible progress; `tell application "rekordbox"` is resolved at run time so the app compiles on a Mac without rekordbox).
- **Fix paths** for a new Mac with a different user name: settings files via `sed`; `master.db` via `pyrekordbox` (SQLCipher key handled by that library), dry-run first, safety copy. Recommendation stays: use the same macOS user name and avoid the problem entirely.
- **bash 3.2 compatible** (macOS default): no arrays `+=` tricks beyond 3.x, no `mapfile`, no associative arrays; BSD `stat -f` with Linux fallbacks so the logic could be tested in a Linux sandbox.

## Verified in the sandbox (Linux stand-in, 31 Aug 2026) — v1.2 additions
- Unattended install with a non-default library (`~/RBLib/Pioneer`) and an "external disk" destination; typed wizard with destination list, invalid music path rejected, `none` accepted; reconfigure from the installed copy switching destination → stamp reset → next auto run mirrors to the new place with a notification.
- Restore refuses an empty destination (no master.db); verification failure (empty master.db in the mirror) auto-undoes and leaves the live library intact; restore → rollback → restore → failing restore all within one second: safety copies get unique names, live DB byte-identical to the backup afterwards.
- First install through the typed wizard with defaults on an Italian "Il mio Drive"; `--yes` re-run; self-test 14 ok.
- Not testable here: the osascript dialogs themselves (`display dialog`, `choose folder`, `choose from list`) — review them on the Mac at first launch (NOTES › To verify).

## Verified in the sandbox (Linux stand-in, 31 Aug 2026) — v1.1 additions
- Auto run: unchanged → silent (no notification); rekordbox "open" → silent skip (exit 3); 2 files changed → notification "13:21 · 2 files updated + daily snapshot · 0s".
- Pause → state `paused`, status shows "PAUSED since …", notification sent; toggle → resume, state `on`, "next check in ~29 min".
- `commands/Status.command` runs via the installed bin; Drive copy of the kit contains `commands/`.
- Drive detection with an Italian "Il mio Drive" folder name.
- Restore drill PASS, restore → DB identical to backup, rollback returns the pre-restore copy (re-run after the v1.1 changes).

## Verified in the sandbox (Linux stand-in, 31 Aug 2026) — v1.0
- Installer end-to-end (detects Drive folder, writes config, copies kit into Drive, self-test, first backup).
- Auto run: no-change skip, change → mirror + daily snapshot, rekordbox-open skip (exit 3), Drive-missing skip (exit 4).
- Mirror byte-identical to source (md5 of every file); log folders excluded.
- Retention pruning: 53 dailies → 14 newest + 6 monthly representatives; manuals capped at 10.
- Restore drill PASS; real restore after corrupting the live DB → identical to backup; rollback restores the corrupted version (proving the safety copy); restore from a dated snapshot → snapshot's `master.db` in place; pre-restore copies pruned to 2.
- Placeholder detection: a sparse file (size, no blocks) is reported as online-only.
- Fix paths dry run counts settings entries; Python part exits 2 with install instructions when pyrekordbox is absent.

## To verify on the real Mac at first install (could not be tested in the sandbox)
1. rekordbox 7 folder names: expected `~/Library/Pioneer/rekordbox7/master.db` (rb6 used `…/rekordbox/`). The kit backs up the whole `~/Library/Pioneer`, so either works; check `BACKUP-INFO.txt` shows the master.db path.
2. macOS Tahoe ships **openrsync** as `/usr/bin/rsync`; the kit only uses `-a -n -v --delete --exclude=`. If the first backup logs an rsync option error, `brew install rsync` (the kit prefers `/opt/homebrew/bin/rsync` automatically).
3. Google Drive placeholder detection (`stat` blocks = 0, `find -flags +dataless`): confirm `Check music` reports 0 online-only on the fully-offline Music folder.
4. TCC prompts: the first backup from Terminal may trigger "Terminal wants to access…" — allow. If launchd runs log `Operation not permitted`, add `/bin/bash` to Full Disk Access (README › Troubleshooting).
5. `osacompile` builds the app; check the three buttons work, the middle button flips between Pause/Resume, and the "backup ✓" notification appears after Back up now (allow notifications for Script Editor when asked).
8. The wizard dialogs: welcome → library (detected, "Use this folder") → destination list → music → summary → Install. In a folder window try ⌘⇧G + `~/Library/Pioneer`. Then app › More… › Settings… must show the same wizard pre-filled.
6. Locale: the Drive folder may be `Il mio Drive` on an Italian macOS — detection uses a wildcard, but confirm the path printed by the installer.
7. Whether `rekordboxAgent` keeps `master.db` open after rekordbox quits (the restore stops it; the backup only checks the `rekordbox` process).

## Lessons learned while building
- A folder wizard needs containment rules, not just existence checks: without them "pick any folder" let the backup land inside the Music folder (breaking the read-only rule) or inside the library (recursive mirror). Resolve symlinks (`pwd -P`) before comparing paths, and validate on every entry path (GUI, typed prompt, CLI flags).
- `set -u` + `$USER`: launch environments do not always define `USER` → use `${USER:-$(id -un)}`.
- `read </dev/tty 2>/dev/null` still prints the open error (redirections apply left to right) → wrap in `{ … } 2>/dev/null`.
- AppleScript: `items` is a reserved word — do not use it as a variable name; `do shell script` runs `/bin/sh`, so use `.` not `source`.
- Sorting snapshot folders by name puts `manual_` after `daily_`; sort by mtime (`ls -1dt`) for "newest".
- Group redirections (`{ … } > file 2>/dev/null`) hide `bash -x` traces of the failure inside — debug with the group's stderr visible.
- AppleScript: `result` is a built-in property — never use it as a variable name (use `outText`); wrap every `display dialog` that has a Cancel button in `try … on error number -128` so Cancel does not abort the whole app with an error.
- `launchctl bootstrap` refuses a service that was `launchctl disable`d — always `enable` first (installer and Resume).
- `mv dir existing_dir` moves INTO the existing folder — a timestamped safety-copy name must be made unique before use, or two restores in the same second nest folders.
- A verification step should check the expected relative path (e.g. `rekordbox7/master.db`), not "any master.db within depth 3" — otherwise a nested/stray copy passes.
- Scripts copied to `bin` at install time are what launchd and the app run: after changing the kit, re-run `Install.command` from the kit folder (a `--reconfigure` from `bin/install.sh` deliberately does not overwrite the scripts).

## How to rerun / build a 2.0
- Inputs that matter: cadence (30 min + 03:00), retention numbers, folder layout (`rekordbox-backup/` in Drive), the read-only `Music` rule, single-Mac assumption.
- Candidate improvements: (a) verify `master.db` integrity by opening it read-only with pyrekordbox after each backup; (b) menu-bar status item instead of an applet; (c) automate the official rekordbox zip via GUI scripting (fragile — deliberately left manual); (d) e-mail/Telegram alert when stale; (e) optional second destination (USB SSD) for gigs.

## Sources
See README.md › Sources (same list, with ✅/⚠️ data-check marks).
