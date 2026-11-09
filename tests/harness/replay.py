#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Replays recorded interface calls with one or more script versions and compares them.

Each recorded call (SNAPSHOTS/call_NNNN, made by record_wrapper.sh) holds TEMP/ and
INFO_RESTART/WF_OLD exactly as NX left them before the interface ran. For every call and
every variant, this script rebuilds TRAJ/{TEMP,INFO_RESTART,DEBUG}, runs the variant's
interface script from TEMP with $TeraChem pointing at tc_proxy (cache only), and collects
the files NX reads. Variants are then compared file by file with the first one (the
reference).

usage: replay.py --snapshots DIR --cache DIR --work DIR
                 --variant NAME=SCRIPT[,par=FILE][,single][,second] [--variant ...]
                 [--calls 0-5,9] [--record] [--keep]

  par=FILE  copy FILE to TEMP/terachem.par
  single    convert the old layout to one template: TEMP/tera.sp = GRAD/start.sp and the
            three start.sp files removed
  second    pretend this is the call after a hop: which_run_is_that = "second run"
  cache=DIR use this tc_proxy cache for this variant (e.g. to force real runs)
  type=N    write N to typeofdyn.out (1 = adiabatic step)
  state=N   set the current state (nstatdyn) in control.d to N
  --record  let tc_proxy run real TeraChem on cache misses (needs a GPU)
"""
import argparse, os, re, shutil, subprocess, sys, tarfile

HERE = os.path.dirname(os.path.abspath(__file__))
OUTFILES = ["epot", "oldepot", "newepot", "grad", "grad.all", "nad_vectors", "oldh", "newh"]
NUM = re.compile(r"[-+]?(?:\d+\.\d*|\.\d+|\d+)(?:[eEdD][-+]?\d+)?")


def parse_variant(text):
    name, rest = text.split("=", 1)
    parts = rest.split(",")
    v = {"name": name, "script": os.path.abspath(parts[0]), "par": None, "single": False, "second": False, "state": None, "type": None, "cache": None}
    for p in parts[1:]:
        if p.startswith("par="):
            v["par"] = os.path.abspath(p[4:])
        elif p.startswith("cache="):
            v["cache"] = os.path.abspath(p[6:])
        elif p.startswith("type="):
            v["type"] = p[5:]
        elif p.startswith("state="):
            v["state"] = int(p[6:])
        elif p in ("single", "second"):
            v[p] = True
        else:
            sys.exit("unknown variant option " + p)
    return v


def parse_calls(text, available):
    if not text:
        return available
    keep = set()
    for chunk in text.split(","):
        a, _, b = chunk.partition("-")
        keep.update(range(int(a), int(b or a) + 1))
    return [c for c in available if c in keep]


def build(snapdir, traj, v):
    if os.path.exists(traj):
        shutil.rmtree(traj)
    temp = os.path.join(traj, "TEMP")
    os.makedirs(temp)
    os.makedirs(os.path.join(traj, "DEBUG"))
    with tarfile.open(os.path.join(snapdir, "before.tar")) as tf:
        tf.extractall(temp, filter="fully_trusted")
    ir = os.path.join(temp, "INFO_RESTART")
    if os.path.isdir(ir):
        shutil.move(ir, os.path.join(traj, "INFO_RESTART"))
    os.makedirs(os.path.join(traj, "INFO_RESTART", "WF_OLD"), exist_ok=True)
    if v["par"]:
        shutil.copy(v["par"], os.path.join(temp, "terachem.par"))
    if v["single"]:
        shutil.copy(os.path.join(temp, "GRAD", "start.sp"), os.path.join(temp, "tera.sp"))
        for d in ("GRAD", "NAD_N1N0", "NAD_N1N2"):
            f = os.path.join(temp, d, "start.sp")
            if os.path.exists(f):
                os.remove(f)
    if v["state"]:  # pretend NX moved the trajectory to another state (4th field of control.d)
        cd = os.path.join(temp, "control.d")
        f = open(cd).read().split(",")
        f[3] = " %7d" % v["state"]
        open(cd, "w").write(",".join(f))
    if v["type"]:  # NX step type in typeofdyn.out (1 = adiabatic step)
        open(os.path.join(temp, "typeofdyn.out"), "w").write("   %s\n" % v["type"])
    if v["second"]:
        with open(os.path.join(temp, "which_run_is_that"), "w") as fh:
            fh.write("second run\n")
    return temp


def run(temp, v, args):
    env = dict(os.environ)
    env["NX"] = args.nx
    env["TeraChem"] = os.path.join(HERE, "tc_proxy")
    env["TCPROXY_CACHE"] = v["cache"] or args.cache
    os.makedirs(env["TCPROXY_CACHE"], exist_ok=True)
    env["TCPROXY_MODE"] = "record" if args.record else "replay"
    env["TCPROXY_LOG"] = os.path.join(os.path.dirname(temp), "tcproxy.log")
    env.setdefault("TCPROXY_REAL", "/software/TeraChem-1.96-beta-241109/TeraChem/bin/terachem")
    p = subprocess.run(["perl", v["script"]], cwd=temp, env=env,
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    with open(os.path.join(os.path.dirname(temp), "interface.out"), "wb") as fh:
        fh.write(p.stdout)
    out = {"rc": p.returncode}
    for f in OUTFILES:
        path = os.path.join(temp, f)
        out[f] = open(path, "rb").read() if os.path.exists(path) else None
    return out


def numdiff(a, b):
    na = [float(x.replace("D", "E").replace("d", "e")) for x in NUM.findall(a.decode())]
    nb = [float(x.replace("D", "E").replace("d", "e")) for x in NUM.findall(b.decode())]
    if len(na) != len(nb):
        return "different number of values (%d vs %d)" % (len(na), len(nb))
    return "max |diff| = %.3e" % max((abs(x - y) for x, y in zip(na, nb)), default=0.0)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--snapshots", required=True)
    ap.add_argument("--cache", required=True)
    ap.add_argument("--work", required=True)
    ap.add_argument("--variant", action="append", required=True)
    ap.add_argument("--calls")
    ap.add_argument("--nx", default=os.environ.get("SYS_NX", "/software/NX-2.4-B06/bin"))
    ap.add_argument("--record", action="store_true")
    ap.add_argument("--keep", action="store_true")
    args = ap.parse_args()
    args.cache = os.path.abspath(args.cache)
    args.work = os.path.abspath(args.work)
    variants = [parse_variant(t) for t in args.variant]

    calls = sorted(int(d[5:]) for d in os.listdir(args.snapshots) if d.startswith("call_"))
    calls = parse_calls(args.calls, calls)
    n_bad = 0
    for c in calls:
        snap = os.path.join(args.snapshots, "call_%04d" % c)
        flag = open(os.path.join(snap, "after", "which_run_is_that")).read().strip() \
            if os.path.exists(os.path.join(snap, "after", "which_run_is_that")) else "?"
        results = []
        for v in variants:
            traj = os.path.join(args.work, v["name"], "call_%04d" % c)
            temp = build(snap, traj, v)
            results.append(run(temp, v, args))
            if not args.keep and results[-1]["rc"] == 0:
                shutil.rmtree(os.path.join(traj, "TEMP"))
        ref = results[0]
        line = ["call %04d (%s):" % (c, flag)]
        for v, r in zip(variants[1:], results[1:]):
            if r["rc"] != ref["rc"]:
                line.append("%s rc %d vs %d" % (v["name"], r["rc"], ref["rc"]))
                n_bad += 1
                continue
            diffs = []
            for f in OUTFILES:
                if r[f] == ref[f]:
                    continue
                if r[f] is None or ref[f] is None:
                    diffs.append("%s missing in %s" % (f, v["name"] if r[f] is None else "ref"))
                else:
                    diffs.append("%s %s" % (f, numdiff(ref[f], r[f])))
            if diffs:
                n_bad += 1
                line.append("%s DIFFERS: %s" % (v["name"], "; ".join(diffs)))
            else:
                line.append("%s identical" % v["name"])
        if ref["rc"] != 0:
            line.append("(reference rc=%d)" % ref["rc"])
        print(" ".join(line), flush=True)
    print("SUMMARY: %d call(s), %d with differences" % (len(calls), n_bad))
    sys.exit(1 if n_bad else 0)


if __name__ == "__main__":
    main()
