#!/bin/sh
# deploy.sh [SSH_TARGET] — install/update boinc-fetcher on kimmy.
# Default target: root@157.22.134.209 (kimmy).  The files are unpacked into a
# root-owned temporary directory and installed from there by install.sh.
# Config, registry, secrets, state and results on kimmy stay as they are.
set -eu
T=${1:-root@157.22.134.209}
cd "$(dirname "$0")"
COPYFILE_DISABLE=1 tar --no-xattrs --no-mac-metadata -cf - fetcher.py install.sh config.example.json registry.example.json systemd README.md |
  ssh "$T" 'set -e; d=$(mktemp -d /root/boinc-fetcher-deploy.XXXXXX); trap "rm -rf $d" EXIT; tar -xf - -C $d --no-same-owner; sh $d/install.sh'
