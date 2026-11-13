# J-Pod backup and recovery

See [README.md](README.md) for a complete fresh installation, Android setup, and the first backup.

## Automatic backups

When you answer **Y** to the backup prompt in `sudo bash install.sh`, J-Pod installs a systemd timer for **Sunday 03:00** (Pi local timezone). Each run creates a verified archive in `/var/backups/j-pod/`, retains the **four newest** `jpod-full-YYYYMMDD-HHMMSS.tar.gz` files, and removes corresponding checksum files for rotated archives. Files with other names are not deleted.

A backup briefly stops Navidrome, copies its SQLite database and configuration, then restarts it. The archive includes `/etc/fstab`, `/etc/navidrome`, `/etc/systemd/system/navidrome.service`, `/var/lib/navidrome`, and `/var/lib/tailscale`. It does **not** contain music files, installed programs, or Raspberry Pi OS.

```bash
sudo /usr/local/sbin/jpod-backup
sudo ls -lh /var/backups/j-pod/
systemctl list-timers jpod-backup.timer
systemctl is-active navidrome
```

If installing backups separately on an existing J-Pod:

```bash
cd ~/j-pod/j-pod
git pull origin raspberry-pi-4
sudo install -m 755 backup.sh /usr/local/sbin/jpod-backup
sudo install -m 644 systemd/jpod-backup.service systemd/jpod-backup.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now jpod-backup.timer
```

To retain six instead of four for a **manual** run: `sudo env JPOD_KEEP=6 /usr/local/sbin/jpod-backup`. For scheduled runs, add `Environment=JPOD_KEEP=6` to the backup service with a systemd drop-in. Do not run multiple backups simultaneously.

## Copy a backup to Windows

Backups contain **Navidrome account data and Tailscale private device keys**. Never upload them to GitHub or share them unencrypted.

On the **Pi**, replace the example archive filename with the actual one printed by the backup script:

```bash
sudo install -m 600 -o admin -g admin /var/backups/j-pod/jpod-full-YYYYMMDD-HHMMSS.tar.gz /home/admin/jpod-backup.tar.gz
```

In a **second Windows PowerShell** window (replace the LAN IP):

```powershell
scp admin@YOUR_PI_LAN_IP:/home/admin/jpod-backup.tar.gz "$env:USERPROFILE\Downloads\jpod-backup.tar.gz"
Get-Item "$env:USERPROFILE\Downloads\jpod-backup.tar.gz"
```

Only after confirming the file exists on Windows, delete the temporary Pi copy:

```bash
rm /home/admin/jpod-backup.tar.gz
```

Encrypt the Windows copy and back up your **USB music library separately**. Weekly backups on the Pi do not protect against microSD failure, and the timer does not automatically copy archives off-device.

## Recover on a replacement Raspberry Pi

1. Turn off the old Pi (if still online) to avoid two devices using the same restored Tailscale identity.
2. Install Raspberry Pi OS Lite 64-bit and clone the `raspberry-pi-4` branch as described in [README.md](README.md). Connect the USB music drive with its original files intact.
3. Run `sudo bash install.sh` to install Navidrome and Tailscale. You can create a temporary Navidrome admin account if the installer starts the service and prompts for setup. Do not format the USB drive.
4. Copy the encrypted backup securely to the Pi and decrypt it locally. Run `sudo bash restore.sh /path/to/jpod-full-YYYYMMDD-HHMMSS.tar.gz` and confirm by typing `RESTORE`. **This overwrites configuration, accounts, and Tailscale state.**
5. Verify `lsblk -f` and the restored `/etc/fstab`. If the USB drive has a different UUID, update the fstab entry before mounting. Run `sudo systemctl daemon-reload && sudo mount /srv/music`; check `findmnt /srv/music` and `ls /srv/music/Music`.
6. Run `sudo systemctl start tailscaled navidrome`, then check `systemctl is-active tailscaled navidrome` and test streaming.
7. Ensure the weekly backup timer remains enabled: `sudo systemctl enable --now jpod-backup.timer`.

**Recovery caveat:** The restore procedure is documented but has not yet been validated on a replacement Pi. Preserve your original archive and music USB unchanged until recovery is confirmed. The archive alone cannot rebuild the operating system or replace missing music.

## Common checks

```bash
systemctl list-timers jpod-backup.timer
sudo journalctl -u jpod-backup.service -n 40 --no-pager
sudo ls -lh /var/backups/j-pod/
sudo tar -tzf /var/backups/j-pod/jpod-full-YYYYMMDD-HHMMSS.tar.gz | head
```
