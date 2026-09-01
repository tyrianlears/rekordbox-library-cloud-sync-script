# Disclaimer — please read before you use this kit

**No warranty, no liability.** This software is provided free of charge, "as is", without warranty of any kind (see [LICENSE](LICENSE)). The author, Nick Rosa, accepts **no responsibility and no liability for any loss of or damage to data — including a corrupted or missing rekordbox library, lost playlists, cue points, beat grids, tags, ratings or analysis data, unusable music files, downtime before a gig, or any other direct or indirect damage — arising from the use, misuse or inability to use this kit, however it was installed or configured.** You use it entirely at your own risk, and you remain responsible for your own backups.

This is an independent community project. It is not affiliated with, endorsed by or supported by AlphaTheta / Pioneer DJ. rekordbox is a trademark of its owner.

## Always keep rekordbox's own backup as well

This kit is an *additional* safety net, not a replacement for the backup function built into rekordbox. Make a library backup with rekordbox itself **before you install or update this kit, before any restore, before moving to a new Mac — and at least once a month**. It contains the database (playlists, cues, grids, tags, ratings), the analysis data and the settings; it does **not** contain your music files, which stay wherever they are.

1. Open rekordbox (7 or 6) and wait until no analysis or export is running.
2. Choose **File › Library › Backup Library**.
3. rekordbox warns that this may take a while — click **OK**.
4. rekordbox asks whether to also back up the music files — choose **No** (library only; a backup with music is much larger and is not needed when your music already lives in a cloud folder or on its own disk).
5. Pick where to save the backup — for example the `official/` folder inside `rekordbox-backup` on your cloud folder, or an external disk — and confirm. rekordbox writes a single `.zip` file.
6. Wait for the completion message. Keep the zip; older ones are worth keeping too.

To put a library back: **File › Library › Restore Library**, select the zip and confirm — rekordbox restores it and closes; open it again to use the restored library. If tracks then show an orange **!**, they need relocating (right-click a track › Relocate), which is normal after music has moved.

Sources: Pioneer DJ community answers on Backup Library / Restore Library (see README › References, items 13–15).
