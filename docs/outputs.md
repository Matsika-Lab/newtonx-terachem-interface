[Home](../README.md) / Output files

# Output files

This page lists the files a trajectory writes: the NewtonX results you read, the interface's own outputs and archives, and the files the interface hands to NewtonX at each step. Read it when you analyze a trajectory or look for the output of a failed TeraChem job. The file names were checked on NewtonX 2.4 (build 06) and 2.6 (build 01); where the two versions differ, the table says so.

## NewtonX results

NewtonX writes these files in `RESULTS/` during the run. The examples are from the 1 fs run of [`examples/casscf`](../examples/casscf/README.md).

| File | Contents |
|---|---|
| `RESULTS/dyn.out` | Geometry, velocity and acceleration of every step, the active state, the number of hops, and the energies |
| `RESULTS/en.dat` | One line per step: time (fs), the energy of each state, the energy of the active state and the total energy, all in Hartree |
| `RESULTS/sh.out` | Surface-hopping log: populations at each substep and every hop, as `SURFACE HOPPING! THE SURFACE CHANGES FROM` |
| `RESULTS/tprob` | Random number and hopping probabilities at each substep |
| `RESULTS/typeofdyn.log` | Step type and the gaps from the active state to the states below and above (eV), compared with `THRES` |
| `RESULTS/report.ci` | Points where the energy gap is below 0.200 eV |
| `RESULTS/nx.log` | The NewtonX log, including the interface's lines |

A line of `en.dat` from the example, at 1.0 fs on S1 with three states:

```text
     1.000   -78.018994670   -77.718487040   -77.591614900   -77.718487040   -77.716771641
```

## Logs

| File | Contents |
|---|---|
| `moldyn.log` | The output of `moldyn.pl`. It shows the interface version and the settings in effect at every step, the TeraChem jobs, the energies, the gradient and the couplings. At `lvprt = 2` or higher it also shows the coupling pairs of each step. |
| `DEBUG/runnx.error` | Error output of the programs NewtonX calls, including every `run-tera-cas.pl: ERROR:` line. Empty after a clean run. See [Troubleshooting](troubleshooting.md). |

## Interface outputs

`TEMP/` holds the files of the last step only. NewtonX overwrites them at the next step.

| File | Contents |
|---|---|
| `TEMP/GRAD/start.sp` | Gradient input the interface wrote from the template |
| `TEMP/GRAD/tera.out` | TeraChem output of the gradient job |
| `TEMP/NAC_i_j/tera.out` | Coupling job between states i and j |
| `TEMP/NAD_N1N0/`, `TEMP/NAD_N1N2/` | Neighbor coupling jobs in the three-template layout, instead of `NAC_i_j` |
| `TEMP/<job>/scr.geom/` | TeraChem scratch of that job, cleared before each run |
| `TEMP/geom.xyz` | The current geometry in Å, as TeraChem reads it |

## Archives and restart files

| File | Contents |
|---|---|
| `INFO_RESTART/MOLDEN_ARCHIVE/<time>.molden` | Orbitals of each step ([`archive_molden`](terachem-par.md#archive_molden), default `1`) |
| `INFO_RESTART/WF_ARCHIVE/c<time>` | CASSCF orbitals of each step ([`archive_wf`](terachem-par.md#archive_wf), default `1`) |
| `INFO_RESTART/WF_OLD/c0` | Previous step's CASSCF orbitals, for [`use_prev_wf`](terachem-par.md#use_prev_wf) |
| `INFO_RESTART/WF_OLD/c0_scf` | Previous step's SCF orbitals, for [`use_prev_scf_wf`](terachem-par.md#use_prev_scf_wf) |
| `INFO_RESTART/WF_OLD/nac_phase_ref` | Last computed vector of every coupling pair, for [`phase_ref = last`](terachem-par.md#phase_ref) |
| `INFO_RESTART/control.dyn` | NewtonX's restart input. Copy it over `control.dyn` to continue a stopped run. |

## Files the interface gives NewtonX

The interface writes these files in `TEMP/` at every step. You do not need to read them, but they are what the tests in [Validation](validation.md#how-the-comparisons-work) compare.

| File | Contents | Read by |
|---|---|---|
| `epot`, `oldepot`, `newepot` | State energies of this and the previous step | NewtonX 2.4 and 2.6 |
| `grad`, `grad.all` | Gradient of the active state | NewtonX 2.4 and 2.6 |
| `nad_vectors` | Phase-corrected coupling vectors; zero for pairs not computed | NewtonX 2.4 and 2.6 |
| `oldh`, `newh` | Coupling vectors of the previous and this step | NewtonX's `escalar`, which the interface calls for the phase correction, in 2.4 and 2.6; the interpolation between steps in NewtonX 2.4 only |
| `nad_vectors-dt` | Coupling vectors of the previous step, written by NewtonX itself and used for the interpolation | NewtonX 2.6 |
| `nad_vectors-2dt` | Coupling vectors of two steps back, rewritten by the interface so that NewtonX keeps its signs; see [NewtonX 2.6](terachem-par.md#newtonx-26) | NewtonX 2.6 |

## Initial conditions

The files `run_tera_ic.pl` writes for `initcond.pl` (`epot.<ifs>`, `oos.<ifs>` and `geom.out`) and the names of the files `initcond.pl` writes are in [Initial conditions and spectra](initial-conditions.md#outputs).

## See also

- [Your first trajectory](first-trajectory.md): what a clean run looks like in `moldyn.log` and `RESULTS/`
- [Troubleshooting](troubleshooting.md): what an error in `moldyn.log` means
- [terachem.par reference](terachem-par.md): the archive and guess settings
