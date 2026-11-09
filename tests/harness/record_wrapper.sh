#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Installed as $NX/run-tera-cas.pl by make_nxbin.sh ... record.
# Runs from TEMP/. Saves, per call, a "before" tarball of TEMP plus INFO_RESTART/WF_OLD,
# the interface's stdout, and the files the interface writes for NX.
REAL=@REAL_SCRIPT@
SNAP=${NXREC_DIR:-../SNAPSHOTS}
mkdir -p "$SNAP"
n=$(ls "$SNAP" | grep -c '^call_' || true)
d=$SNAP/call_$(printf %04d "$n")
mkdir -p "$d/after"
tar -cf "$d/before.tar" . -C .. INFO_RESTART/WF_OLD 2>/dev/null || tar -cf "$d/before.tar" .
perl "$REAL" | tee "$d/stdout"
rc=${PIPESTATUS[0]}
echo "$rc" > "$d/rc"
for f in epot oldepot newepot grad grad.all nad_vectors oldh newh escph which_run_is_that; do
  [ -e "$f" ] && cp "$f" "$d/after/"
done
exit "$rc"
