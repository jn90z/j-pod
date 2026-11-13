# J-Pod backup and disaster recovery (Raspberry Pi 4)

The backup archive includes `/etc/fstab`, Navidrome config/service/data, and Tailscale state. It **does not** include music files, the Navidrome executable, OS packages, or the Tailscale binary. Never commit backup archives to GitHub; they contain private credentials.

## Back up now
```bash
sudo bash backup.sh
sudo ls -lh /var/backups/j-pod/
```
Backup briefly stops Navidrome to make a consistent copy of its SQLite database, then restarts it. Do not unplug storage during backup.

## Copy off the Pi
From **Windows PowerShell** (not SSH):
```powershell
scp admin@192.168.4.190:/var/backups/j-pod/jpod-full-YYYYMMDD-HHMMSS.tar.gz .
```
Replace the filename with the one printed by the backup command. The archive is root-only; first copy it to a temporary admin-readable directory on the Pi if SCP reports permission denied, then remove that temporary copy. Encrypt the archive before long-term storage. Also separately back up your music USB drive.

## Restore after OS reinstall
1. Reinstall Raspberry Pi OS and run `install.sh` on the Pi 4 to install packages, Navidrome and Tailscale. Do not format the music drive.
2. Transfer the private backup archive to the Pi and run `sudo bash restore.sh /path/to/archive.tar.gz`.
3. Confirm `lsblk -f` and compare the actual music USB UUID with the restored `/etc/fstab`. Update if necessary, then `sudo systemctl daemon-reload && sudo mount /srv/music`.
4. Confirm `/srv/music/Music` exists and run `sudo systemctl start tailscaled navidrome`.
5. Check `systemctl status navidrome tailscaled` and test playback.

If restoring Tailscale state onto a second device while the old Pi is still online, duplicate identity can cause conflicts. Shut down the old device first or re-authenticate the new one.

## Scheduled backups
To install a weekly backup timer:
```bash
sudo install -m 755 backup.sh /usr/local/sbin/jpod-backup
sudo cp systemd/jpod-backup.service systemd/jpod-backup.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now jpod-backup.timer
systemctl list-timers jpod-backup.timer
```
Weekly backup is stored on the microSD; copy backups off-device regularly. This timer does not automatically send archives to Windows. For daily Navidrome DB backups, use Navidrome's native `[Backup]` configuration and a directory writable by `navidrome`. See https://navidrome.org/docs/usage/backup/.
