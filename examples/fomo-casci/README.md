[Home](../../README.md) / [Examples](../README.md) / Ethylene, FOMO-CASCI(4,4)/6-31G*

# Ethylene, FOMO-CASCI(4,4)/6-31G*

This folder is a complete NewtonX input for a 1 fs trajectory of twisted ethylene with CASCI with four active orbitals on FOMO orbitals with Gaussian smearing, kT = 0.2 Hartree. The trajectory starts on S1 with zero velocities, so it shows that the template runs unchanged in NewtonX and what one step costs, not any photochemistry. Copy the folder and run `moldyn.pl` in the copy; see [Your first trajectory](../../docs/first-trajectory.md) for the steps.

| Setting | Value |
|---|---|
| Method | FOMO-CASCI, [tutorial](../../docs/methods.md#fomo-casci) |
| TeraChem keywords | `fon yes`, `casci yes`, `closed 6`, `active 4`, `cassinglets 3` |
| States | 3 singlets (`nstat = 3`), start in S1 (`nstatdyn = 2`) |
| Time step and length | `dt = 0.5` fs, `tmax = 1` fs |
| Couplings | Coupling vectors (`vdoth = 0`); pairs per step: S1–S0 and S2–S1 |
| `jiri.inp` | `kross = 0`, `current = 1` (neighbor couplings) |
| `sh.inp` | `vdoth = 0`, `integrator = 5`, `decohmod = 1`, `seed = 10` |
| `terachem.par` | none, so every setting has its [default](../../docs/terachem-par.md#summary-of-keys) |
| Program versions | Interface 2.0.0 (commit `5c8b037`), NewtonX 2.4 (build 06), TeraChem 1.96 beta |
| Hardware | One NVIDIA RTX 5000 Ada GPU |

## Result

The test run's output is not part of this folder. These numbers come from it.

- **Gaps at the start.** S1 lies 8.56 eV above S0, and S2 lies 1.55 eV above S1, from `RESULTS/typeofdyn.log` of the test run.
- **No hop.** The trajectory stays on S1 for the whole 1 fs, and the `moldyn.log` of the test run has no warnings.
- **Energy conservation.** The total energy changes by +0.08 µEh between 0.5 and 1.0 fs in `RESULTS/en.dat` of the test run, from -77.714072143 to -77.714072065 Hartree.
- **TeraChem runs.** NewtonX called the interface 3 times, at 0, 0.5 and 1.0 fs, with 3 TeraChem runs per call, 9 in total.
- **Time.** The three calls took 15, 10 and 10 s, 36 s in total. Five example runs shared the node at the time; see [Validation](../../docs/validation.md#14-example-inputs).

## Files

| Path | Contents |
|---|---|
| `control.dyn` | NewtonX run settings, with `prog = 21.0` for TeraChem |
| `geom` | Twisted ethylene geometry, NewtonX format, Bohr |
| `veloc` | Initial velocities, all zero (a.u.) |
| `sh.inp` | Surface-hopping settings |
| `jiri.inp` | Coupling pairs NewtonX asks for |
| [`JOB_NAD/tera.sp`](JOB_NAD/tera.sp) | TeraChem template |
