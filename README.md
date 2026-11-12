# J-Pod — Raspberry Pi Music Streaming Setup

> **Raspberry Pi 4 branch:** This version is optimized for a Raspberry Pi 4 with a **128 GB microSD** and **1 TB exFAT USB SSD**. The original Pi Zero 2 W instructions remain on [main](https://github.com/jn90z/j-pod/tree/main).

## Raspberry Pi 4 setup (recommended)

Use **Raspberry Pi OS Lite (64-bit)** on the 128 GB microSD. Raspberry Pi Imager will expand the filesystem on first boot. Set hostname `jpod`, enable SSH, and configure your user and network. For a stable always-on server, connect **Gigabit Ethernet** if possible, and plug the SSD into a **blue USB 3.0 port**. Use a suitable USB-C 5V/3A power supply. The SSD should already be formatted exFAT and contain `Music/`.

From Windows PowerShell, connect:

~~~powershell
ssh YOUR_USERNAME@jpod.local
~~~

Then on the Pi:

~~~bash
sudo apt update && sudo apt install -y git
git clone --branch raspberry-pi-4 https://github.com/jn90z/j-pod.git
cd j-pod
sudo bash install.sh
~~~

The Pi 4 installer checks the hardware model and 64-bit architecture, confirms your SSD before mounting, installs Navidrome, and offers Tailscale setup. It uses **/var/lib/navidrome on the 128 GB microSD** for the database, leaving the 1 TB SSD dedicated to music. The installer does not format or partition drives. **Review the script before running as root; hardware testing is pending.**

Afterward visit `http://jpod.local:4533` on your LAN, create the Navidrome admin account, and test streaming over Tailscale from your phone.

---


A private, always-on music server for MP3/FLAC collections. This branch targets Raspberry Pi 4, 128 GB microSD, 1 TB USB SSD, Raspberry Pi OS Lite 64-bit, Navidrome and Tailscale.

## Recommended installation: interactive setup

The easiest way to set up J-Pod is **headless**, using SSH from Windows PowerShell. You do **not** need a monitor, keyboard, or desktop on the Pi.

### Before you begin

1. Flash **Raspberry Pi OS Lite** using [Raspberry Pi Imager](https://www.raspberrypi.com/software/).
2. In Imager, set hostname `jpod`, a username/password, your **2.4 GHz** Wi-Fi network, and **enable SSH**.
3. Format the **1 TB SSD as exFAT on Windows** (GPT partition table preferred), label it `JPOD_MUSIC`, and create a `Music` folder. **Back up existing files before formatting.**
4. Connect the SSD to the Pi Zero 2 W's **USB data** port with a micro-USB OTG adapter. If the SSD is not reliably detected, use a powered USB hub. Connect the Pi power supply to **PWR IN**.
5. Power up the Pi and wait for it to join Wi-Fi.

### Connect from Windows

Open PowerShell:

~~~powershell
ssh YOUR_USERNAME@jpod.local
~~~

Replace `YOUR_USERNAME` with the account created in Imager. If `jpod.local` doesn't resolve, find the Pi's IP address in your router and use `ssh YOUR_USERNAME@PI_IP`.

### Install with four commands

Run these **inside the Pi SSH session**, not in Windows PowerShell:

~~~bash
sudo apt update && sudo apt install -y git
git clone https://github.com/jn90z/j-pod.git
cd j-pod
sudo bash install.sh
~~~

Read [install.sh](install.sh) before running it as root. The script **never formats or repartitions a drive**, but it does change system configuration, install packages, and create a system service. It has not yet been validated on the actual Pi hardware.

### Interactive installer walkthrough

The installer will:

1. List attached drives. Enter the **SSD partition**, such as `/dev/sda1` (not the microSD and not necessarily `/dev/sda1` on your system).
2. Display its filesystem and UUID. Type **YES** only after verifying the correct SSD.
3. Mount the SSD at `/srv/music` using its UUID and configure persistent mounting in `/etc/fstab`. It backs up the existing fstab first.
4. Ask for the folder containing your music. For the recommended Windows layout, accept **Music**, corresponding to `/srv/music/Music`.
5. Download the matching Navidrome ARM binary, configure it, and enable automatic startup through systemd.
6. Offer Tailscale installation and display a sign-in link for your private remote network.

**Database location:** For your exFAT SSD, the script uses `/var/lib/navidrome` on the microSD for the writable Navidrome database. An ext4 drive offers an SSD database option. This is a deliberate reliability choice; back up the database separately.

### After installation

On your home Wi-Fi, open **http://jpod.local:4533** (or `http://PI_LAN_IP:4533`) and create a Navidrome administrator account. Check that your albums appear and play one song.

Install Tailscale on your Android phone, sign in to the **same tailnet**, and enable the VPN. The Pi's private remote address is shown by `tailscale ip -4`; use `http://PI_TAILSCALE_IP:4533` as the server URL in your Navidrome/Subsonic-compatible Android player. Test playback over cellular with Wi-Fi disabled, then Bluetooth and Android Auto. **Android Auto compatibility depends on the chosen Android player.** Do not forward ports on your home router.

### Verify and troubleshoot

~~~bash
lsblk -f
findmnt /srv/music
systemctl status navidrome --no-pager
sudo journalctl -u navidrome -n 80 --no-pager
tailscale status
df -h / /srv/music
~~~

If the installer fails, read the error before rerunning. If `/srv/music` already has an fstab entry or is mounted from another drive, resolve that conflict manually rather than forcing another mount. Keep an independent backup of your music library and Navidrome database.

### Manual alternative

The numbered sections below document a **manual installation** for troubleshooting or advanced configuration. **Choose either the interactive installer or the manual procedure; do not perform both on the same fresh installation.**

## 1. Prepare the Pi

Use [Raspberry Pi Imager](https://www.raspberrypi.com/software/) on Windows. Choose Pi Zero 2 W and Raspberry Pi OS Lite (64-bit, or 32-bit if preferred). Configure hostname **jpod**, your own username and password, 2.4 GHz Wi-Fi, country and **enable SSH** before writing the card. Boot the Pi, then connect using PowerShell:

~~~powershell
ssh YOUR_USER@jpod.local
~~~

If mDNS fails, get the Pi IP from your router and SSH to that address. Keep SSH off the public internet.

## 2. Update and prepare USB storage

~~~bash
sudo apt update && sudo apt full-upgrade -y
sudo apt install -y curl wget jq ffmpeg ca-certificates exfatprogs
uname -m
lsblk -o NAME,SIZE,FSTYPE,LABEL,UUID,MOUNTPOINTS
sudo blkid
id -u
id -g
sudo mkdir -p /srv/music
~~~

Identify the **correct USB partition UUID**. Never format a drive containing music. Edit fstab:

~~~bash
sudo nano /etc/fstab
~~~

For an **exFAT** flash drive, append this example with your actual UUID and Pi user UID/GID:

~~~text
UUID=1234-ABCD /srv/music exfat defaults,nofail,x-systemd.device-timeout=10,uid=1000,gid=1000,umask=022 0 0
~~~

For **ext4**, use instead:

~~~text
UUID=YOUR-UUID /srv/music ext4 defaults,nofail,x-systemd.device-timeout=10 0 2
~~~

NTFS requires appropriate driver and mount options. Validate:

~~~bash
sudo systemctl daemon-reload
sudo mount -a
findmnt /srv/music
ls -la /srv/music
~~~

Use the Pi USB **data** port with an OTG adapter, not PWR IN. Spinning 2.5-inch HDDs may need a **powered USB hub** to avoid voltage drop and spin-up failures.

## 3. Install Navidrome (native binary, no Docker)

[Official releases](https://github.com/navidrome/navidrome/releases) and [Linux docs](https://www.navidrome.org/docs/installation/linux/). Match the binary to the OS architecture.

~~~bash
case "$(uname -m)" in
  aarch64) ND_ARCH=arm64 ;;
  armv7l|armv6l) ND_ARCH=armv7 ;;
  *) echo "Unsupported architecture"; exit 1 ;;
esac
ASSET_URL=$(curl -fsSL https://api.github.com/repos/navidrome/navidrome/releases/latest | jq -r --arg arch "$ND_ARCH" '.assets[] | select(.name | test("linux_" + $arch + "\\.tar\\.gz$")) | .browser_download_url' | head -n 1)
test -n "$ASSET_URL" || { echo "Inspect official releases for your ARM binary"; exit 1; }
echo "$ASSET_URL"
curl -fL "$ASSET_URL" -o /tmp/navidrome.tar.gz
sudo mkdir -p /opt/navidrome /var/lib/navidrome /etc/navidrome
sudo tar -xzf /tmp/navidrome.tar.gz -C /opt/navidrome
sudo chmod +x /opt/navidrome/navidrome
id navidrome >/dev/null 2>&1 || sudo useradd --system --home /var/lib/navidrome --shell /usr/sbin/nologin navidrome
sudo chown -R navidrome:navidrome /var/lib/navidrome
~~~

If release asset naming changes, manually download the correct ARM64/ARMv7 Linux tarball from the official releases page. Ensure Navidrome can read the mounted music files (exFAT umask=022 above; for ext4 set appropriate read/traverse permissions).

~~~bash
sudo tee /etc/navidrome/navidrome.toml >/dev/null <<'EOF'
MusicFolder = "/srv/music"
DataFolder = "/var/lib/navidrome"
Address = "0.0.0.0"
Port = 4533
ScanSchedule = "@every 1h"
LogLevel = "info"
EOF
~~~

## 4. Make Navidrome start automatically

~~~bash
sudo tee /etc/systemd/system/navidrome.service >/dev/null <<'EOF'
[Unit]
Description=J-Pod Navidrome music server
Wants=network-online.target
After=network-online.target
RequiresMountsFor=/srv/music
ConditionPathIsMountPoint=/srv/music

[Service]
Type=simple
User=navidrome
Group=navidrome
WorkingDirectory=/var/lib/navidrome
ExecStart=/opt/navidrome/navidrome --configfile /etc/navidrome/navidrome.toml
Restart=on-failure
RestartSec=10
NoNewPrivileges=true
ProtectSystem=full
ProtectHome=true
PrivateTmp=true
ReadWritePaths=/var/lib/navidrome

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now navidrome
systemctl status navidrome --no-pager
~~~

The mount dependency prevents a scan against a missing drive. On your home network visit **http://jpod.local:4533** (or the Pi LAN IP). Create a strong Navidrome admin account, wait for scanning, and play a track.

## 5. Enable remote streaming securely with Tailscale

Follow [official Tailscale Linux setup](https://tailscale.com/docs/install/linux):

~~~bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo systemctl enable --now tailscaled
sudo tailscale up
tailscale ip -4
~~~

Authorize the Pi through the displayed login URL. Install [Tailscale on Android](https://tailscale.com/download/android), sign into the **same tailnet** and enable the VPN. Turn off phone Wi-Fi to test cellular access to **http://PI_TAILSCALE_IP:4533**, replacing with the Pi 100.x address printed above. HTTP is encrypted inside the Tailscale tunnel. **Do not open router ports 4533 or 22.** Check Tailscale device key expiration settings for an unattended server.

## 6. Android, Bluetooth, Android Auto

Choose a Subsonic/Navidrome-compatible Android music client. The discussed **Subsonic Player by SirFoxior** is one candidate; verify its current Android Auto compatibility and availability in Google Play on your device. [Symfonium](https://www.symfonium.app/) is another option (trial and one-time payment).

In the player configure:
- Server URL: http://PI_TAILSCALE_IP:4533
- Username/password: your **Navidrome** account
- Enable offline downloads for low-cellular-coverage areas
- Prefer original audio streaming, not heavy transcoding on the Zero 2 W

Test home Wi-Fi, then cellular with Tailscale enabled, then Bluetooth, then Android Auto. Android Auto support depends on the **player app** and car/head unit, not the server. Review battery optimization for Tailscale/player if playback stops in background. Set everything up while parked.

## 7. Add music from Windows

Initially copy music to USB from Windows, safely eject, reconnect to Pi. For easier ongoing transfers, use [WinSCP](https://winscp.net/) over SFTP to jpod.local, writing to /srv/music if your Pi user has permission. Or:

~~~powershell
scp -r "C:\Music\Favorite Album" YOUR_USER@jpod.local:/srv/music/
~~~

Navidrome rescans hourly. Do not expose SFTP or SMB to the public internet.

## 8. Operations, backups and troubleshooting

~~~bash
systemctl status navidrome tailscaled --no-pager
tailscale status
df -h / /srv/music
free -h
sudo journalctl -u navidrome -n 80 --no-pager
sudo apt update && sudo apt full-upgrade -y
~~~

For a consistent Navidrome database/config backup:

~~~bash
sudo systemctl stop navidrome
sudo tar -czf "$HOME/jpod-config-$(date +%F).tgz" -C / var/lib/navidrome etc/navidrome
sudo systemctl start navidrome
~~~

**Copy the backup off the Pi.** Back up the entire music collection separately, too.

| Symptom | Check |
|---|---|
| Pi not reachable | Power, 2.4 GHz Wi-Fi, router IP, SSH |
| USB missing | OTG data port, powered hub, lsblk, findmnt |
| Navidrome fails | journalctl, correct ARM binary, mount, permissions |
| Empty library | MusicFolder path, read access, ID3 tags, scan |
| Cellular fails | Tailscale active on phone/Pi, use 100.x address |
| Android Auto missing | Client app support and launcher settings |
| Audio stutters | Cellular coverage, USB power, avoid transcoding |

## Completion checklist

- [ ] Headless Pi boots after power outage
- [ ] Music USB drive mounts by UUID
- [ ] Navidrome starts automatically and finds albums
- [ ] Home Wi-Fi streaming works
- [ ] Cellular streaming through Tailscale works
- [ ] Bluetooth and Android Auto tested
- [ ] Offline playlist cached
- [ ] Music and database backed up separately

Only store and stream music you have the rights to use.
