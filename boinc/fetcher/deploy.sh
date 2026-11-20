#!/bin/sh
# deploy.sh [SSH_TARGET] — copy boinc/fetcher to kimmy and (re)install it.
# Default target: root@157.22.134.209 (kimmy).  Only code is copied: config,
# registry, secrets and state on kimmy stay as they are.
set -eu
T=${1:-root@157.22.134.209}
cd "$(dirname "$0")"
COPYFILE_DISABLE=1 tar --no-xattrs --no-mac-metadata -cf - fetcher.py install.sh config.example.json registry.example.json systemd README.md |
  ssh "$T" 'set -e; d=/home/leancheck/boinc-fetcher; mkdir -p $d; tar -xf - -C $d --no-same-owner; sh $d/install.sh'
