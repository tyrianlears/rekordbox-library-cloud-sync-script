# Changelog — rekordbox backup kit

## 1.3.1 — 1 Sep 2026 — disclaimer
- `DISCLAIMER.md` (no warranty, no liability for data loss; the author takes no responsibility) with the step-by-step rekordbox **File › Library › Backup Library** procedure (library only, no music files) and how to restore it; linked from a prominent section at the top of the README.
- The wizard's welcome screen and the typed setup repeat the warning; the installer copies `DISCLAIMER.md` and `LICENSE` next to the backups and writes the backup steps into `official/README.txt`.

## 1.3.0 — 1 Sep 2026 — choose where the scripts and the app install
- New wizard screen: scripts **On this Mac** (default), **Inside the backup folder** (`rekordbox-backup/kit` on the cloud folder or disk, so they travel with the backups) or **Other folder…**; app in `~/Applications` or `/Applications`. Also `--install-dir local|backup|PATH` and `--app-dir PATH`.
- `rbk-launch.sh`: a small launcher that always stays on the Mac and is what launchd calls; when the scripts folder is unreachable it logs the skip and notifies (at most once every 12 h) instead of failing silently.
- Settings… can move the scripts later (old location tidied; the backup folder's kit copy is always kept); the app and the `.command` launchers find the scripts through `config.sh`; the app explains when the scripts folder is unavailable.
- Safety rules for the install location: never inside the Music folder, the library/settings folders, the home folder itself, or anywhere in the backup folder other than `kit/`.
- Self-test and Status report the launcher and the scripts location.

## 1.2.1 — 31 Aug 2026 — cloud-agnostic pass
- Nothing depends on Google Drive any more: unattended-install default = first detected cloud folder (any service), neutral wording in the app, Check music and the scripts.
- More cloud folders detected by the wizard: Box, Proton Drive, pCloud, MEGA, Nextcloud, Sync.com (in addition to Google Drive, Dropbox, iCloud Drive, OneDrive and external disks); anything else via "Other folder…".
- README: "Supported destinations" table with each service's keep-offline wording; new-Mac guide rewritten for any cloud app; Windows explicitly unsupported.

## 1.2.0 — 31 Aug 2026 — universal
- Folder safety rules in the wizard, the installer and the command-line options: the backup folder is refused if it is inside the Music folder, inside the rekordbox library/settings folders, or is the home folder itself; the library folder cannot sit inside the backup folder.
- First-launch folder wizard (rekordbox library, backup destination, optional music folder) with detected defaults, a list of cloud folders/external disks found on the Mac, and a ⌘⇧G tip in every folder window.
- Settings… in the app (More…) and `Settings (change folders).command` re-run the wizard; changing the destination triggers a full mirror on the next run.
- App shows a Set up… button when opened before installation.
- Backups to any folder (Google Drive, Dropbox, iCloud Drive, OneDrive, external disk, NAS…); library folder can be anywhere.
- launchd labels renamed to `com.rekordbox-backup-kit.*` (old jobs removed automatically).
- Restore: refuses an empty backup, undoes itself if verification fails, safety copies next to the library folder with unique names.
- `Install.command --library … --backup … --music … --yes` for unattended installs.

## 1.1.0 — 31 Aug 2026
- Notification after every completed backup (time · files updated · snapshot · duration); skipped runs stay silent.
- Pause / Resume automatic backups: app button with live label, `rbk-toggle.sh`, `Pause auto-backup.command` / `Resume auto-backup.command`; a pause survives reboots.
- Status shows automatic-backup state and the next check time.
- One double-click `.command` file per action in `kit/commands/`.
- Restore… moved under More… in the app (three-button limit); `Back up now` from Terminal offers to quit rekordbox.
- Installer: test notification, `launchctl enable` before loading, clears a previous pause.
- Snapshots exclude `USBANLZ/` as well as `share/`.

## 1.0.0 — 31 Aug 2026
- First version: automatic mirror + dated snapshots to Google Drive, Back up now, emergency Restore with rollback, restore drill, self-test, Check music, Fix paths, README + PDF, new-laptop guide.
