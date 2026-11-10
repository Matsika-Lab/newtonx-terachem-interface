[Home](../../README.md) / [Examples](../README.md) / Ethylene, full TDDFT (RPA) CAM-B3LYP/6-31G* with TD-BA

# Ethylene, full TDDFT (RPA) CAM-B3LYP/6-31G* with TD-BA

This folder is a complete NewtonX input for a 1 fs trajectory of twisted ethylene with full TDDFT with the CAM-B3LYP functional; TeraChem gives no RPA coupling vectors, so NewtonX builds time-dependent Baeck-An (TD-BA) couplings from the energies. The trajectory starts on S1 with zero velocities, so it shows that the template runs unchanged in NewtonX and what one step costs, not any photochemistry. Copy the folder and run `moldyn.pl` in the copy; see [Your first trajectory](../../docs/first-trajectory.md) for the steps.

| Setting | Value |
|---|---|
| Method | Full TDDFT (RPA), [tutorial](../../docs/methods.md#full-tddft-rpa) |
| TeraChem keywords | `method camb3lyp`, `rpa yes`, `cisnumstates 4` |
| States | 3 singlets (`nstat = 3`), start in S1 (`nstatdyn = 2`) |
| Time step and length | `dt = 0.5` fs, `tmax = 1` fs |
| Couplings | TD-BA (`vdoth = 2`); pairs per step: none; NewtonX computes TD-BA |
| `jiri.inp` | `kross = 0`, `current = 1` (neighbor couplings) |
| `sh.inp` | `vdoth = 2`; nothing else, so NewtonX uses its defaults |
| `terachem.par` | none, so every setting has its [default](../../docs/terachem-par.md#summary-of-keys) |
| Program versions | Interface 2.0.0 (commit `5c8b037`), NewtonX 2.4 (build 06), TeraChem 1.96 beta |
| Hardware | One NVIDIA RTX 5000 Ada GPU |

## Result

The test run's output is not part of this folder. These numbers come from it.

- **Gaps at the start.** S1 lies 6.29 eV above S0, and S2 lies 2.14 eV above S1, from `RESULTS/typeofdyn.log` of the test run.
- **No hop.** The trajectory stays on S1 for the whole 1 fs, and the `moldyn.log` of the test run has no warnings.
- **Energy conservation.** The total energy changes by −2.6 µEh between 0.5 and 1.0 fs in `RESULTS/en.dat` of the test run, from -78.273962797 to -78.273965350 Hartree.
- **TeraChem runs.** NewtonX called the interface 3 times, at 0, 0.5 and 1.0 fs, with 1 TeraChem run per call, 3 in total.
- **Time.** The three calls took 15, 13 and 12 s, 41 s in total. Five example runs shared the node at the time; see [Validation](../../docs/validation.md#14-example-inputs).

## Files

| Path | Contents |
|---|---|
| `control.dyn` | NewtonX run settings, with `prog = 21.0` for TeraChem |
| `geom` | Twisted ethylene geometry, NewtonX format, Bohr |
| `veloc` | Initial velocities, all zero (a.u.) |
| `sh.inp` | Surface-hopping settings |
| `jiri.inp` | Coupling pairs NewtonX asks for |
| [`JOB_NAD/tera.sp`](JOB_NAD/tera.sp) | TeraChem template |
