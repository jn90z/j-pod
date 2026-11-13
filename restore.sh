#!/usr/bin/env bash
set -Eeuo pipefail
[[ $EUID -eq 0 ]] || { echo "Run: sudo bash restore.sh /path/to/jpod-full-*.tar.gz" >&2; exit 1; }
[[ $# -eq 1 && -f "$1" ]] || { echo "Usage: sudo bash restore.sh /path/to/jpod-full-*.tar.gz" >&2; exit 1; }
archive=$(readlink -f "$1")
# Only restore archives created by backup.sh, not arbitrary tar files.
tar -tzf "$archive" | grep -qx './BACKUP-INFO.txt' || { echo "Not a J-Pod backup" >&2; exit 1; }
if tar -tzf "$archive" | grep -Eq '(^/|(^|/)\.\.(/|$))'; then echo "Unsafe archive paths" >&2; exit 1; fi
echo "This overwrites Navidrome data, configuration, fstab and Tailscale identity."
echo "Verify the USB drive UUID in /etc/fstab after restore. Music files are NOT included."
read -r -p "Type RESTORE to proceed: " confirm
[[ "$confirm" == RESTORE ]] || exit 0
systemctl stop navidrome || true
systemctl stop tailscaled || true
mkdir -p /var/backups/j-pod
cp -a /etc/fstab "/var/backups/j-pod/fstab-before-restore-$(date +%Y%m%d-%H%M%S)"
tar -xzpf "$archive" -C / --no-same-owner --wildcards './etc/fstab' './etc/navidrome*' './etc/systemd/system/navidrome.service' './var/lib/navidrome*' './var/lib/tailscale*' 2>/dev/null || {
  echo "Restore extraction failed; services left stopped for inspection." >&2; exit 1;
}
chown -R navidrome:navidrome /var/lib/navidrome
chmod 700 /var/lib/tailscale
systemctl daemon-reload
echo "Restore extracted. Verify fstab UUID and mount /srv/music before starting Navidrome."
echo "Then run: sudo systemctl start tailscaled navidrome"
