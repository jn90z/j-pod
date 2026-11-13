# J-Pod — Self-hosted music streaming on Raspberry Pi 4

Run your own music server with **Raspberry Pi OS Lite 64-bit + Navidrome + Tailscale + Tempo (Android)**. Stream over Wi-Fi or cellular without forwarding router ports. The Pi Zero 2 W version lives on [main](https://github.com/jn90z/j-pod/tree/main).

## Hardware and layout

- Raspberry Pi **4 Model B** (tested setup: 8 GB RAM), adequate 5V/3A USB-C power supply, and microSD (tested: 128 GB).
- USB 3.0 music drive (tested: 256 GB SanDisk Ultra Fit, exFAT). A different-sized drive also works.
- Put your existing music in a top-level **`Music/`** directory on the USB drive **before connecting it**. Never format a drive containing music.
- Pi stores Navidrome's database at `/var/lib/navidrome` on microSD; USB mounts at `/srv/music`; Navidrome scans `/srv/music/Music`.
- Your actual USB **UUID** and Pi **LAN/Tailscale IPs** are unique; do not copy the examples blindly.

## Fresh installation (from scratch)

**1. Prepare Raspberry Pi OS.** Flash [Raspberry Pi OS Lite (64-bit)](https://www.raspberrypi.com/software/) using Raspberry Pi Imager. In Imager's settings, choose hostname `J-Pod`, user `admin` (or your preferred username), a strong password, network settings, and **enable SSH**. Insert the microSD, connect the music USB drive to a blue USB 3.0 port, and power on the Pi.

**2. SSH from Windows PowerShell.** Find the Pi's LAN IP in your router if the hostname does not resolve:

```powershell
ssh admin@J-Pod.local
# Alternative: ssh admin@YOUR_PI_LAN_IP
```

**3. Download and run the Pi 4 installer.** Run these **on the Pi**, not Windows:

```bash
sudo apt update && sudo apt install -y git
git clone --branch raspberry-pi-4 https://github.com/jn90z/j-pod.git
cd j-pod
sudo bash install.sh
```

The interactive installer:
1. Lists disks. Select the **USB music partition** (often `/dev/sda1`, but check `lsblk -f`); confirm its filesystem and UUID with `YES`.
2. Adds a persistent UUID mount at `/srv/music` in `/etc/fstab` without formatting the drive.
3. Asks for music folder: press Enter for **`Music`**.
4. Installs Navidrome, enables startup on boot, and stores its database on the microSD.
5. Offers Tailscale: accept, then sign in using the authorization link.
6. Offers **weekly local backups**: accept to install the timer with **four-backup rotation**.

**4. Create your Navidrome account.** On a PC on your home network, open `http://YOUR_PI_LAN_IP:4533`. On first launch, create an admin username and password. Wait for your music to scan. This is **not** your Pi or Tailscale login.

**5. Configure Android.** Install [Tailscale for Android](https://tailscale.com/download/android), sign into the **same Tailscale account**, and connect. Install [Tempo](https://github.com/CappielloAntonio/tempo), a free Navidrome/Subsonic player. Add a server:

| Tempo field | Value |
|---|---|
| Server name | J-Pod |
| URL | `http://YOUR_PI_TAILSCALE_IP:4533` |
| Username / password | Navidrome credentials from step 4 |
| Low Security | Leave off initially; enable only if required by your setup |

Get the Pi's private IP with `tailscale ip -4` (usually `100.x.x.x`). **Keep Tailscale connected on Android**. Test with Wi-Fi disabled to confirm cellular streaming. Check Android Auto/Bluetooth and optional offline downloads. HTTP traffic over Tailscale is protected by its encrypted tunnel; **do not forward port 4533 or SSH on your router**.

## Backups — included in the installer

With the backup option enabled, a systemd timer runs **every Sunday at 03:00 Pi local time**:

- Creates `/var/backups/j-pod/jpod-full-YYYYMMDD-HHMMSS.tar.gz`.
- Briefly stops Navidrome to copy its database consistently, then restarts it.
- Includes Navidrome config, users/playlists/database, systemd unit, `/etc/fstab`, and **sensitive Tailscale device identity**.
- Checks the archive and retains the **four most recent full archives**. Earlier manually named backups are unaffected.
- **Does not include the music USB files, OS, or program binaries.** Back up the USB music separately.

Make the **first backup immediately** after creating your Navidrome account:

```bash
sudo /usr/local/sbin/jpod-backup
sudo ls -lh /var/backups/j-pod/
systemctl list-timers jpod-backup.timer
systemctl is-active navidrome
```

**Copy a backup off the Pi** (a backup on the same microSD does not protect against microSD failure). The archives are root-only; on the Pi, use the exact archive filename shown above:

```bash
sudo install -m 600 -o admin -g admin /var/backups/j-pod/jpod-full-YYYYMMDD-HHMMSS.tar.gz /home/admin/jpod-backup.tar.gz
```

From a **separate Windows PowerShell**:

```powershell
scp admin@YOUR_PI_LAN_IP:/home/admin/jpod-backup.tar.gz "$env:USERPROFILE\Downloads\jpod-backup.tar.gz"
```

After verifying the download, on the Pi:

```bash
rm /home/admin/jpod-backup.tar.gz
```

**Encrypt and safeguard the Windows backup**: it contains credentials and Tailscale keys. Backups are **not automatically sent to Windows**. See [BACKUP.md](BACKUP.md) for restore instructions and retention customization.

## Rebuild after a failure

Reinstall Raspberry Pi OS and use the **fresh installation** steps above to install software and mount your music USB. Then restore the private backup from Windows using [BACKUP.md](BACKUP.md). Confirm the USB UUID and `/etc/fstab` match before starting Navidrome. Do **not** restore the same Tailscale device identity while the original Pi remains online.

## Verify / troubleshoot

```bash
lsblk -f                          # USB device and UUID
findmnt /srv/music                # correct music drive mounted?
ls /srv/music/Music               # music files present?
systemctl is-enabled navidrome tailscaled jpod-backup.timer
systemctl is-active navidrome tailscaled
systemctl list-timers jpod-backup.timer
tailscale ip -4
sudo journalctl -u navidrome -n 40 --no-pager
vcgencmd get_throttled            # 0x0 means no recorded throttling
```

If Navidrome is stopped after boot, first check that the USB drive is connected and mounted. The service intentionally requires `/srv/music`. For installation errors, inspect the message before rerunning; the installer refuses to overwrite an existing Navidrome config or conflicting fstab entry.

## Updating an existing J-Pod

```bash
cd ~/j-pod/j-pod   # adjust if cloned elsewhere
git pull origin raspberry-pi-4
sudo install -m 755 backup.sh /usr/local/sbin/jpod-backup
```

The installer is intended for **fresh installations**, not upgrades: do not rerun it on an already-configured server. See [BACKUP.md](BACKUP.md) for the full recovery procedure.

Only store and stream music you have rights to use.
