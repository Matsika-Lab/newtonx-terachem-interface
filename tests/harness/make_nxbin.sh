#!/bin/bash
# usage: make_nxbin.sh <dest_dir> <interface_script> [record]
# Builds a private NX bin folder: symlinks to the system NX bin, with run-tera-cas.pl
# replaced. With "record", run-tera-cas.pl becomes snapshot_wrapper.sh, which calls
# <interface_script> and saves TEMP before and after every call (see record_wrapper).
set -euo pipefail
SYS_NX=${SYS_NX:-/software/NX-2.4-B06/bin}
DEST=$1; SCRIPT=$(readlink -f "$2"); MODE=${3:-plain}
HERE=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$DEST"
for f in "$SYS_NX"/*; do ln -sfn "$f" "$DEST/$(basename "$f")"; done
rm -f "$DEST/run-tera-cas.pl"
if [ "$MODE" = record ]; then
  sed "s|@REAL_SCRIPT@|$SCRIPT|" "$HERE/record_wrapper.sh" > "$DEST/run-tera-cas.pl"
  chmod +x "$DEST/run-tera-cas.pl"
else
  ln -s "$SCRIPT" "$DEST/run-tera-cas.pl"
fi
echo "built $DEST ($MODE) -> $SCRIPT"
