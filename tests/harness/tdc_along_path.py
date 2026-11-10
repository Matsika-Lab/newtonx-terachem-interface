#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Overlap couplings along a recorded NAC trajectory, compared with the NAC run's v.h.

For every step k of a finished NX run (geometries from RESULTS/dyn.out):
  1. TeraChem energy single point with the run's method keywords and cassavevectors.
  2. TeraChem ci_vec_overlap between steps k-1 and k:  S_IJ = <psi_I(t_k-1)|psi_J(t_k)>.
  3. State signs chained from step 0 (flip J when S_JJ < 0).
  4. sigma_mid(pair m>n) = (S_mn - S_nm) / 2dt, raw and after Loewdin orthonormalisation.
  5. v.h of the NAC run at t_k-1 and t_k (sh.out, every ms-th line), averaged.
Writes <out>/compare.csv. Single points are cached, so the script can be rerun.
Assumes singlets, ms = 20 and dt = 0.5 fs, as in the uracil test of validation section 18.
TeraChem must be on PATH (source SetTCVars.sh first).

usage: tdc_along_path.py TRAJ_DIR TEMPLATE OUT_DIR GPU [MAX_STEP]
"""
import os, sys, subprocess, csv
import numpy as np

traj, tpl_file, out, gpu = sys.argv[1], sys.argv[2], os.path.abspath(sys.argv[3]), sys.argv[4]
max_step = int(sys.argv[5]) if len(sys.argv) > 5 else 10**9
B = 0.529177210903
FS2AU = 41.341374575751
os.makedirs(out, exist_ok=True)

tpl = [l for l in open(tpl_file) if l.split() and l.split()[0].lower() not in
       ("run", "castarget", "cistarget", "coordinates", "scrdir", "guess", "nacstate1", "nacstate2", "cassavevectors")]
tpl = "".join(tpl)

# geometries (bohr) and states per step
L = open(os.path.join(traj, "RESULTS", "dyn.out")).read().splitlines()
geo, state = {}, {}
for i, l in enumerate(L):
    if l.startswith("STEP"):
        k = int(l.split()[1]); state[k] = int(l.split()[6])
        j = next(j for j in range(i, i + 10) if "New geometry" in L[j])
        rows = []
        for r in L[j + 1:]:
            f = r.split()
            if len(f) != 6: break
            rows.append((f[0], np.array(f[2:5], float)))
        geo[k] = rows
g0 = []
for r in open(os.path.join(traj, "geom")):
    f = r.split()
    if len(f) >= 5: g0.append((f[0], np.array(f[2:5], float)))
geo[0] = g0
nat = len(g0)
steps = sorted(k for k in geo if k <= max_step)
cd = open(os.path.join(traj, "control.dyn")).read()
dt = float(cd.split("dt")[1].split("=")[1].split()[0]) * FS2AU
nstat = int(cd.split("nstat ")[1].split("=")[1].split()[0]) if "nstat " in cd else 3
ms = 20
vh = [[float(x) for x in l.split()[1:]] for l in open(os.path.join(traj, "RESULTS", "sh.out")) if l.startswith("|v.h|=")]
en = {round(float(r.split()[0]) / 0.5): [float(x) for x in r.split()[1:1 + nstat]]
      for r in open(os.path.join(traj, "RESULTS", "en.dat")) if r.split()}


def run(d, text):
    os.makedirs(d, exist_ok=True)
    o = os.path.join(d, "tc.out")
    if not (os.path.exists(o) and "Job finished" in open(o).read()):
        open(os.path.join(d, "tc.in"), "w").write(text)
        subprocess.run("terachem tc.in > tc.out 2>&1", shell=True, cwd=d,
                       env={**os.environ, "CUDA_VISIBLE_DEVICES": str(gpu)})
    return open(o).read()


def sp(k):
    d = os.path.join(out, "sp%05d" % k)
    open(os.path.join(d if os.path.isdir(d) else (os.makedirs(d) or d), "geom.xyz"), "w").write(
        "%d\n\n" % nat + "".join("%s %.10f %.10f %.10f\n" % (s, *(x * B)) for s, x in geo[k]))
    txt = run(d, tpl + "coordinates geom.xyz\nrun energy\ncassavevectors yes\nscrdir scr\n")
    civ = os.path.join(d, "civ")
    if not os.path.exists(civ):
        with open(civ, "wb") as fh:
            for s in range(1, nstat + 1):
                fh.write(open(os.path.join(d, "scr", "CI_1_%d.dat" % s), "rb").read())
    e = [float(l.split()[4]) for l in txt.splitlines() if l.startswith("Singlet state") and "energy:" in l][:nstat]
    return d, e


rows, p = [], np.ones(nstat)
prev = None
for k in steps:
    d, e = sp(k)
    if prev is not None:
        dp, kp = prev
        od = os.path.join(out, "ov%05d" % k)
        run(od, tpl + "coordinates %s/geom.xyz\nold_coors %s/geom.xyz\nrun ci_vec_overlap\nscrdir scr\n"
            "orb1afile %s/scr/c0\norb2afile %s/scr/c0\ncvec1file %s/civ\ncvec2file %s/civ\n" % (d, dp, dp, d, dp, d))
        n = int(round(np.sqrt(os.path.getsize(os.path.join(od, "scr", "CIVecOverlap.dat")) / 8)))
        S = np.fromfile(os.path.join(od, "scr", "CIVecOverlap.dat")).reshape(n, n)[:nstat, :nstat]
        pn = p * np.sign(np.diag(S))
        Sal = np.outer(p, pn) * S
        u, _, vt = np.linalg.svd(Sal); Sl = u @ vt
        row = dict(step=k, t_mid=(k - 0.5) * 0.5, state=state.get(k, ""),
                   diag_min=float(np.min(np.abs(np.diag(S)))), e_err=max(abs(a - b) for a, b in zip(e, en.get(k, e))))
        for m, nn, c in ((1, 0, 0), (2, 0, 1), (2, 1, 2)):
            row["ov%d%d" % (m + 1, nn + 1)] = (Sal[m, nn] - Sal[nn, m]) / (2 * dt)
            row["lw%d%d" % (m + 1, nn + 1)] = (Sl[m, nn] - Sl[nn, m]) / (2 * dt)
            if ms * k < len(vh):
                row["vh%d%d" % (m + 1, nn + 1)] = 0.5 * (vh[ms * (k - 1)][c] + vh[ms * k][c])
        rows.append(row)
        p = pn
    prev = (d, k)
with open(os.path.join(out, "compare.csv"), "w", newline="") as fh:
    w = csv.DictWriter(fh, fieldnames=list(rows[-1].keys()))
    w.writeheader(); w.writerows(rows)
print("wrote", os.path.join(out, "compare.csv"), len(rows), "rows")
