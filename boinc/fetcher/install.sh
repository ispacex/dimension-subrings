#!/bin/sh
# install.sh — run as root ON kimmy from a root-owned staging copy of this
# directory (deploy.sh on the Mac does that).  Idempotent: config, registry,
# secrets, state and results are never overwritten.
#
#   user     boinc-fetcher (system user, no shell; NOT the tm job user, so tm
#            jobs cannot read its secrets)
#   code     /opt/boinc-fetcher            root:root 755 (the service cannot change it)
#   config   /etc/boinc-fetcher/{config,registry}.json   root:boinc-fetcher 640
#   secrets  /etc/boinc-fetcher/secrets/   boinc-fetcher 700, files 600
#   state    /var/lib/boinc-fetcher        (systemd StateDirectory, 700)
#   results  /srv/boinc-results/<id>/      boinc-fetcher 755, files 644 (readable by everybody on kimmy)
set -eu
[ "$(id -u)" = 0 ] || { echo "run as root" >&2; exit 2; }
src=$(cd "$(dirname "$0")" && pwd)
U=boinc-fetcher
id "$U" >/dev/null 2>&1 ||
  useradd --system --home-dir /var/lib/boinc-fetcher --no-create-home --shell /usr/sbin/nologin "$U"
install -d -o root -g root -m 755 /opt/boinc-fetcher
install -o root -g root -m 755 "$src/fetcher.py" /opt/boinc-fetcher/fetcher.py
install -o root -g root -m 644 "$src/README.md" /opt/boinc-fetcher/README.md
install -d -o root -g "$U" -m 750 /etc/boinc-fetcher
install -d -o "$U" -g "$U" -m 700 /etc/boinc-fetcher/secrets
install -d -o "$U" -g "$U" -m 755 /srv/boinc-results
for f in config registry; do
  dst=/etc/boinc-fetcher/$f.json
  [ -e "$dst" ] || install -o root -g "$U" -m 640 "$src/$f.example.json" "$dst"
done
install -o root -g root -m 644 "$src/systemd/boinc-fetcher.service" "$src/systemd/boinc-fetcher.timer" \
  /etc/systemd/system/
systemctl daemon-reload
systemctl enable boinc-fetcher.timer
systemctl restart boinc-fetcher.timer
systemctl list-timers boinc-fetcher.timer --no-pager
