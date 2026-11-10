[Home](../../README.md) / [Sample trajectories](../README.md) / Cyclooctadiene, SA-3-CASSCF(4,3)/cc-pVDZ

# Cyclooctadiene, SA-3-CASSCF(4,3)/cc-pVDZ

This folder holds a complete 20 fs trajectory of cyclooctadiene on S1, with all inputs and the NewtonX output. It shows a full CASSCF run with coupling vectors in the three-template layout. It was made with the interface before version 2.0, at commit `35c7390`, so its `terachem.par` keeps the coupling scheme of that version.

| Setting | Value |
|---|---|
| Method | SA-3-CASSCF(4,3)/cc-pVDZ: `casscf yes`, `closed 28`, `active 3`, `cassinglets 3`; [tutorial](../../docs/methods.md#casscf) |
| States | 3 singlets (`nstat = 3`), start in S1 (`nstatdyn = 2`) |
| Time step and length | `dt = 0.25` fs, `tmax = 20` fs |
| Couplings | Coupling vectors (`vdoth = 0`), neighbor pairs |
| `terachem.par` | `couplings = neighbours`, `phase_ref = previous` |
| `sh.inp` | `vdoth = 0`, `integrator = 5`, `ms = 100`, `decohmod = 1`, `seed = 2` |
| Template layout | Three templates: `GRAD`, `NAD_N1N0`, `NAD_N1N2` |
| Program versions | Interface at commit `35c7390`, NewtonX 2.4 (build 06); the TeraChem version is not recorded in the files |

## Result

- **Gaps at the start.** S1 lies 7.14 eV above S0, and S2 lies 0.72 eV above S1, from `RESULTS/typeofdyn.log`.
- **No hop.** The trajectory stays on S1 for the whole 20 fs; `RESULTS/sh.out` has no hop.
- **Gaps at the end.** At 20 fs, S1 lies 4.57 eV above S0, and S2 lies 1.92 eV above S1.
- **Energy conservation.** The total energy in `RESULTS/en.dat` stays within 0.34 mEh of its starting value, and ends 0.32 mEh below it.
- **Interface calls.** NewtonX called the interface 81 times, once per step from 0 to 20 fs.

## Files

| Path | Contents |
|---|---|
| `control.dyn` | NewtonX run settings, with `prog = 21.0` for TeraChem |
| `geom` | Initial geometry, NewtonX format, Bohr |
| `veloc` | Initial velocities (a.u.) |
| `sh.inp` | Surface-hopping settings |
| `terachem.par` | `couplings = neighbours` and `phase_ref = previous`, the scheme of the script that made the sample |
| `run_nx_tera.sh` | The command that ran the trajectory on one GPU |
| `JOB_NAD/GRAD/start.sp` | TeraChem template for the gradient |
| `JOB_NAD/NAD_N1N0/start.sp`, `JOB_NAD/NAD_N1N2/start.sp` | TeraChem templates for the couplings with the states below and above |
| `moldyn.log` | NewtonX and interface log |
| `RESULTS/` | NewtonX results: `dyn.out`, `en.dat`, `sh.out`, `tprob`, `typeofdyn.log`, `report.ci`, `nx.log`; see [Output files](../../docs/outputs.md) |
