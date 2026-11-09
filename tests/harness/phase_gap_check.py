#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Checks the phase_ref option on recorded trajectories by simulating coupling gaps.

For every recorded first-run call k and every coupling pair p that is non-zero at
steps k-1 and k, the previous step's nad_vectors is replayed with pair p set to zero,
as if p had not been computed at step k-1. With phase_ref = last, the pair's vector
from step k-1-g is given as the remembered vector. The sign of the new pair-p vector
is compared with the recorded, gap-free trajectory at step k.

usage: phase_gap_check.py --snapshots DIR --cache DIR --work DIR --script SCRIPT
                          [--gaps 1,2,5] [--nx NXBIN]
Needs only cached TeraChem results (no GPU).
"""
import argparse, os, shutil, sys, tarfile
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import replay  # noqa: E402


def load(path):
    return np.loadtxt(path).reshape(-1, 3)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--snapshots", required=True)
    ap.add_argument("--cache", required=True)
    ap.add_argument("--work", required=True)
    ap.add_argument("--script", required=True)
    ap.add_argument("--gaps", default="1,2,5")
    ap.add_argument("--nx", default="/software/NX-2.4-B06/bin")
    args = ap.parse_args()
    args.cache, args.work = os.path.abspath(args.cache), os.path.abspath(args.work)
    args.record = False
    gaps = [int(g) for g in args.gaps.split(",")]

    calls = sorted(int(d[5:]) for d in os.listdir(args.snapshots) if d.startswith("call_"))
    snap = lambda c: os.path.join(args.snapshots, "call_%04d" % c)
    first = [c for c in calls
             if open(os.path.join(snap(c), "after", "which_run_is_that")).read().strip() != "second run"]
    after = {c: load(os.path.join(snap(c), "after", "nad_vectors")) for c in first}
    with tarfile.open(os.path.join(snap(first[0]), "before.tar")) as tf:
        cd = tf.extractfile("./control.d").read().decode().split(",")
    nat, nstat = int(cd[0]), int(cd[2])
    ncoup = nstat * (nstat - 1) // 2
    results = {("previous", g): [0, 0] for g in gaps}
    results.update({("last", g): [0, 0] for g in gaps})

    for idx, k in enumerate(first):
        for g in gaps:
            if idx - 1 - g < 0:
                continue
            prev, ref_call = first[idx - 1], first[idx - 1 - g]
            h_prev, h_now, h_ref = after[prev], after[k], after[ref_call]
            for p in range(ncoup):
                blk = slice(p * nat, (p + 1) * nat)
                if not (np.abs(h_prev[blk]).max() > 0 and np.abs(h_now[blk]).max() > 0
                        and np.abs(h_ref[blk]).max() > 0):
                    continue
                for mode in ("previous", "last"):
                    v = {"name": "%s_g%d_p%d" % (mode, g, p), "script": os.path.abspath(args.script),
                         "par": None, "single": False, "second": False, "state": None,
                         "type": None, "cache": None}
                    traj = os.path.join(args.work, v["name"], "call_%04d" % k)
                    temp = replay.build(snap(k), traj, v)
                    with open(os.path.join(temp, "terachem.par"), "w") as fh:
                        fh.write("couplings = neighbours\nphase_ref = %s\n" % mode)
                    nv = load(os.path.join(temp, "nad_vectors"))
                    nv[blk] = 0.0
                    np.savetxt(os.path.join(temp, "nad_vectors"), nv, fmt="%.8f")
                    if mode == "last":
                        mem = np.zeros_like(nv)
                        mem[blk] = h_ref[blk]
                        np.savetxt(os.path.join(traj, "INFO_RESTART", "WF_OLD", "nac_phase_ref"), mem, fmt="%.8f")
                    out = replay.run(temp, v, args)
                    if out["rc"] != 0:
                        print("call %d pair %d %s: interface failed" % (k, p, mode))
                        continue
                    h = np.array([[float(x) for x in l.split()] for l in out["nad_vectors"].decode().splitlines()])
                    agree = float(np.sum(h[blk] * h_now[blk])) > 0
                    results[(mode, g)][0] += agree
                    results[(mode, g)][1] += 1
                    shutil.rmtree(traj, ignore_errors=True)
    for g in gaps:
        for mode in ("previous", "last"):
            a, n = results[(mode, g)]
            print("gap %2d steps  phase_ref=%-8s  sign agrees with the gap-free run: %d / %d" % (g, mode, a, n))


if __name__ == "__main__":
    main()
