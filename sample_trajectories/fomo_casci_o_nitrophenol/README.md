[Home](../../README.md) / [Sample trajectories](../README.md) / o-Nitrophenol, FOMO-CASCI(12,10)/cc-pVDZ

# o-Nitrophenol, FOMO-CASCI(12,10)/cc-pVDZ

This folder holds a complete 40 fs trajectory of o-nitrophenol that starts on S3, with all inputs and the NewtonX output. It shows a FOMO-CASCI run with coupling vectors, a hop, and the second interface call that follows a hop. It was made with the interface before version 2.0, at commit `35c7390`, so its `terachem.par` keeps the coupling scheme of that version.

| Setting | Value |
|---|---|
| Method | FOMO-CASCI(12,10)/cc-pVDZ: `method hf`, `fon yes`, `fon_method gaussian`, `fon_temperature 0.2`, `casci yes`, `closed 30`, `active 10`, `cassinglets 8`; [tutorial](../../docs/methods.md#fomo-casci) |
| States | 5 singlets (`nstat = 5`), start in S3 (`nstatdyn = 4`) |
| Time step and length | `dt = 0.5` fs, `tmax = 40` fs |
| Couplings | Coupling vectors (`vdoth = 0`), neighbor pairs |
| `terachem.par` | `couplings = neighbours`, `phase_ref = previous` |
| `sh.inp` | `vdoth = 0`, `integrator = 5`, `ms = 20`, `seed = 1` |
| Template layout | Three templates: `GRAD`, `NAD_N1N0`, `NAD_N1N2` |
| Program versions | Interface at commit `35c7390`, NewtonX 2.4 (build 06); the TeraChem version is not recorded in the files |

## Result

- **Gaps at the start.** S3 lies 0.92 eV above S2, and S4 lies 0.17 eV above S3, from `RESULTS/typeofdyn.log`.
- **One hop.** The trajectory hops from S3 to S4 at 1.0 fs. `RESULTS/sh.out` shows it as `SURFACE HOPPING! THE SURFACE CHANGES FROM   4 TO   5`, in NewtonX's numbering from 1.
- **After the hop.** The trajectory stays on S4, the highest state, until 40 fs.
- **Energy conservation.** The total energy in `RESULTS/en.dat` stays within 0.72 mEh of its starting value, and ends 0.08 mEh below it.
- **Interface calls.** NewtonX called the interface 82 times: once per step from 0 to 40 fs, plus the second call after the hop.

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
