#!/usr/bin/env bash
set -Eeuo pipefail
[[ $EUID -eq 0 ]] || { echo "Run: sudo bash backup.sh" >&2; exit 1; }
umask 077
dest=${1:-/var/backups/j-pod}
mkdir -p "$dest"
chmod 700 "$dest"
# Retain four completed weekly full backups (configurable with JPOD_KEEP).
keep=${JPOD_KEEP:-4}
[[ "$keep" =~ ^[1-9][0-9]*$ ]] || { echo "JPOD_KEEP must be a positive integer" >&2; exit 1; }
stamp=$(date +%Y%m%d-%H%M%S)
archive="$dest/jpod-full-$stamp.tar.gz"
tmp=$(mktemp -d)
was_running=0
cleanup() {
  if (( was_running )); then systemctl start navidrome || echo "WARNING: Navidrome restart failed" >&2; fi
  rm -rf "$tmp"
}
trap cleanup EXIT
if systemctl is-active --quiet navidrome; then
  was_running=1
  systemctl stop navidrome
fi
# Cold copy of the SQLite DB avoids inconsistent WAL snapshots.
mkdir -p "$tmp/etc/systemd/system" "$tmp/var/lib" "$tmp/etc"
for path in /etc/fstab /etc/navidrome /etc/systemd/system/navidrome.service /var/lib/navidrome /var/lib/tailscale; do
  if [[ -e "$path" ]]; then cp -a --parents "$path" "$tmp"; fi
done
printf 'Created: %s\nHost: %s\n' "$(date -Is)" "$(hostname)" > "$tmp/BACKUP-INFO.txt"
tar -C "$tmp" -czpf "$archive.tmp" .
mv "$archive.tmp" "$archive"
# Verify archive integrity before considering it a completed backup.
if ! tar -tzf "$archive" >/dev/null; then
  echo "Backup verification failed; retaining all previous backups." >&2
  rm -f -- "$archive"
  exit 1
fi
sha256sum "$archive" > "$archive.sha256"
echo "Backup: $archive (verified)"

# Rotate only successfully created full backups with exact expected filenames.
# Preserve older manually created backups and any other files in the directory.
mapfile -d '' backups < <(find "$dest" -maxdepth 1 -type f -regextype posix-extended -regex '.*/jpod-full-[0-9]{8}-[0-9]{6}[.]tar[.]gz' -print0 | sort -zr)
if (( ${#backups[@]} > keep )); then
  for old in "${backups[@]:keep}"; do
    echo "Rotating out: $old"
    rm -f -- "$old" "$old.sha256"
  done
fi
echo "Retaining up to $keep weekly full backups."
echo "Contains private Tailscale identity and Navidrome credentials. Keep encrypted and off-device."
