#!/bin/sh
# install.sh — run as root ON kimmy from the unpacked code directory
# (/home/leancheck/boinc-fetcher); deploy.sh on the Mac does both steps.
# Idempotent: config, registry, secrets and state are never overwritten.
set -eu
U=${FETCHER_USER:-leancheck}
H=$(getent passwd "$U" | cut -d: -f6)
src=$(cd "$(dirname "$0")" && pwd)
[ "$src" = "$H/boinc-fetcher" ] || { echo "expected to run from $H/boinc-fetcher" >&2; exit 2; }
chown -R "$U:$U" "$src"
install -d -o "$U" -g "$U" -m 700 "$H/.config/boinc-fetcher" "$H/.config/boinc-fetcher/secrets" \
  "$H/.local/state/boinc-fetcher"
install -d -o "$U" -g "$U" -m 750 "$H/boinc-results"
for f in config registry; do
  dst="$H/.config/boinc-fetcher/$f.json"
  [ -e "$dst" ] || install -o "$U" -g "$U" -m 600 "$src/$f.example.json" "$dst"
done
install -m 644 "$src/systemd/boinc-fetcher.service" "$src/systemd/boinc-fetcher.timer" /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now boinc-fetcher.timer
systemctl list-timers boinc-fetcher.timer --no-pager
