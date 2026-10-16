#!/usr/bin/env bash
# One-time (idempotent) preparation of the remote box for remote/ds-remote.sh.
#
#     remote/setup-box.sh            # uv into $ROOT/cache/bin
#     remote/setup-box.sh --gap      # also GAP: a copy of a GAP installation on the box
#                                    # ($DS_REMOTE_GAP_SRC: GAP 4.15 with SmallGroups, anupq, io
#                                    # built) into $ROOT/cache/gap, and $ROOT/cache/bin/gap
#
# Nothing is installed system-wide: everything lives under the job user's directory. GAP is
# copied, not built, so that the job user need not read the source directory; a later rebuild
# there is picked up by running --gap again. Same environment as remote/ds-remote.sh.
set -eu
HOST=${DS_REMOTE_HOST:?set DS_REMOTE_HOST (ssh destination of the runner)}
SSH=${DS_REMOTE_SSH:-ssh -o BatchMode=yes -o ConnectTimeout=20 -o LogLevel=ERROR}
RUSER=${DS_REMOTE_USER:?set DS_REMOTE_USER (the user jobs run as)}
ROOT=${DS_REMOTE_ROOT:-/home/$RUSER/ds-jobs}
UV_VERSION=0.10.9
GAP=0 GAP_SRC=
if [ "${1:-}" = --gap ]; then
  GAP=1
  GAP_SRC=${DS_REMOTE_GAP_SRC:?set DS_REMOTE_GAP_SRC (a GAP installation on the box to copy)}
fi

$SSH "$HOST" "set -e
  mkdir -p $ROOT/cache/bin
  if ! $ROOT/cache/bin/uv --version 2>/dev/null | grep -q '$UV_VERSION'; then
    t=\$(mktemp -d)
    curl -fsSL -o \$t/uv.tgz https://github.com/astral-sh/uv/releases/download/$UV_VERSION/uv-x86_64-unknown-linux-gnu.tar.gz
    tar -xzf \$t/uv.tgz -C \$t
    install -m 755 \$t/uv-x86_64-unknown-linux-gnu/uv \$t/uv-x86_64-unknown-linux-gnu/uvx $ROOT/cache/bin/
    rm -rf \$t
  fi
  echo \"uv: \$($ROOT/cache/bin/uv --version)\"
  if [ $GAP = 1 ]; then
    nice -n 19 rsync -a --delete $GAP_SRC/ $ROOT/cache/gap/
    printf '#!/bin/sh\nexec $ROOT/cache/gap/gap -l $ROOT/cache/gap \"\$@\"\n' > $ROOT/cache/bin/gap
    chmod 755 $ROOT/cache/bin/gap
  fi
  chown -R $RUSER: $ROOT
  if [ -x $ROOT/cache/bin/gap ]; then
    cd $ROOT   # anupq runs its binary in the current directory, which must be readable by the job user
    echo 'Print(GAPInfo.Version, \" anupq=\", LoadPackage(\"anupq\"), \" \", NrSmallGroups(512), \"\\n\");' \
      | sudo -u $RUSER -H $ROOT/cache/bin/gap -q -b
  fi"
