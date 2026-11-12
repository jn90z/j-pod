#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "Installation stopped at line $LINENO" >&2' ERR
if [[ $EUID -ne 0 || ! -t 0 ]]; then echo "Run interactively: sudo bash install.sh"; exit 1; fi
echo "J-Pod Raspberry Pi 4 installer — never formats or partitions drives."
model=$(tr -d "\000" </proc/device-tree/model 2>/dev/null || true)
echo "Detected: $model"
if [[ "$model" != *"Raspberry Pi 4"* ]]; then
  echo "This branch targets Raspberry Pi 4 hardware."; exit 1
fi
if [[ "$(uname -m)" != aarch64 ]]; then
  echo "Use Raspberry Pi OS 64-bit for this branch."; exit 1
fi
echo "SD capacity: $(lsblk -dn -o SIZE /dev/mmcblk0 2>/dev/null || echo unknown)"
lsblk -o NAME,PATH,SIZE,FSTYPE,LABEL,UUID,MOUNTPOINTS
read -r -p "Enter SSD partition (e.g. /dev/sda1): " part
[[ -b "$part" ]] || { echo "Invalid partition"; exit 1; }
fs=$(lsblk -no FSTYPE "$part" | head -1 | xargs)
uuid=$(blkid -s UUID -o value "$part")
case "$fs" in exfat|ext4|ntfs|ntfs3) ;; *) echo "Unsupported filesystem: $fs"; exit 1;; esac
echo "Selected $part, $fs, UUID $uuid"
read -r -p "Confirm this is your music SSD [type YES]: " confirm
[[ "$confirm" == YES ]] || exit 0
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y curl jq ffmpeg ca-certificates exfatprogs git
mkdir -p /srv/music
if mountpoint -q /srv/music; then
  mounted_uuid=$(findmnt -n -o UUID /srv/music || true)
  [[ "$mounted_uuid" == "$uuid" ]] || { echo "Different disk already mounted at /srv/music"; exit 1; }
fi
if ! mountpoint -q /srv/music; then
  if grep -Eq '^[^#].*[[:space:]]/srv/music[[:space:]]' /etc/fstab; then
    echo "Existing /srv/music fstab entry; mount/check it manually"; exit 1
  fi
  uid=$(id -u "$SUDO_USER")
  gid=$(id -g "$SUDO_USER")
  case "$fs" in
    exfat) type=exfat; options="defaults,nofail,x-systemd.device-timeout=10,uid=$uid,gid=$gid,umask=022"; pass=0 ;;
    ext4) type=ext4; options="defaults,nofail,x-systemd.device-timeout=10"; pass=2 ;;
    *) type=ntfs3; options="defaults,nofail,x-systemd.device-timeout=10,uid=$uid,gid=$gid,umask=022"; pass=0 ;;
  esac
  cp /etc/fstab "/etc/fstab.jpod.$(date +%s).bak"
  printf 'UUID=%s /srv/music %s %s 0 %s\n' "$uuid" "$type" "$options" "$pass" >> /etc/fstab
  systemctl daemon-reload
  mount /srv/music
fi
mountpoint -q /srv/music || { echo "SSD not mounted"; exit 1; }
read -r -p "Music folder on SSD [Music]: " folder
folder=$(echo "$folder" | xargs)
if [[ -z "$folder" ]]; then folder=Music; fi
if [[ "$folder" == /* || "$folder" == *..* ]]; then echo "Invalid relative folder"; exit 1; fi
music="/srv/music/$folder"
if [[ ! -d "$music" ]]; then
  read -r -p "Create $music? [y/N]: " answer
  [[ "$answer" == y ]] || exit 1
  mkdir -p "$music"
fi
case "$(uname -m)" in aarch64) arch=arm64;; armv7l) arch=armv7;; *) echo "Unsupported architecture"; exit 1;; esac
echo "Finding latest Navidrome Linux $arch release..."
url=$(curl -fsSL https://api.github.com/repos/navidrome/navidrome/releases/latest | jq -r --arg arch "$arch" '.assets[] | select(.name | test("linux_" + $arch + "\\.tar\\.gz$")) | .browser_download_url' | head -1)
[[ -n "$url" ]] || { echo "No matching release: check github.com/navidrome/navidrome/releases"; exit 1; }
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl -fL "$url" -o "$tmp/navidrome.tar.gz"
mkdir -p /opt/navidrome /etc/navidrome
tar -xzf "$tmp/navidrome.tar.gz" -C /opt/navidrome
chmod +x /opt/navidrome/navidrome
id navidrome >/dev/null 2>&1 || useradd --system --home /var/lib/navidrome --shell /usr/sbin/nologin navidrome
echo "The Pi 4 has ample SD space; storing Navidrome database on microSD."
data=/var/lib/navidrome
mkdir -p "$data"
chown -R navidrome:navidrome "$data"
runuser -u navidrome -- test -r "$music" || { echo "Navidrome cannot read music directory"; exit 1; }
if [[ -e /etc/navidrome/navidrome.toml ]]; then echo "Existing Navidrome config detected; refusing overwrite"; exit 1; fi
cat > /etc/navidrome/navidrome.toml <<EOF
MusicFolder = "$music"
DataFolder = "$data"
Address = "0.0.0.0"
Port = 4533
ScanSchedule = "@every 1h"
LogLevel = "info"
EOF
cat > /etc/systemd/system/navidrome.service <<EOF
[Unit]
Description=J-Pod Navidrome
Wants=network-online.target
After=network-online.target
RequiresMountsFor=/srv/music
ConditionPathIsMountPoint=/srv/music
[Service]
User=navidrome
Group=navidrome
WorkingDirectory=$data
ExecStart=/opt/navidrome/navidrome --configfile /etc/navidrome/navidrome.toml
Restart=on-failure
RestartSec=10
NoNewPrivileges=true
ProtectSystem=full
ProtectHome=true
PrivateTmp=true
ReadWritePaths=$data
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now navidrome
systemctl is-active --quiet navidrome || { journalctl -u navidrome -n 40 --no-pager; exit 1; }
echo "Navidrome running on port 4533."
read -r -p "Install and configure Tailscale now? [Y/n]: " answer
if [[ "$answer" != n ]]; then
  if ! command -v tailscale >/dev/null; then curl -fsSL https://tailscale.com/install.sh | sh; fi
  systemctl enable --now tailscaled
  tailscale up
  echo "Remote URL: http://$(tailscale ip -4 | head -1):4533"
fi
echo "J-Pod installed. Open http://jpod.local:4533 on home Wi-Fi to create your admin account."
