[Home](../README.md) / terachem.par reference

# terachem.par reference

`terachem.par` holds the interface's own settings: which couplings to compute, wavefunction guesses, coupling signs and archives. Read this page when you want to change one of them, or to look up a default. The file is optional. Without it, every key keeps its default.

## Example file

```text
 couplings       = neighbours
 use_prev_scf_wf = 1
 archive_molden  = 1
```

## Format and location

- **Place:** put `terachem.par` in the trajectory folder, next to `control.dyn`.
- **When it is read:** NewtonX copies it to `TEMP/` when the run starts, so edits during a run have no effect. On a restart with `nxrestart = 1`, NewtonX uses the copy in `INFO_RESTART/`.
- **Lines:** the format is `key = value`, one per line. `key value` without `=` also works.
- **Comments:** comments start with `#` or `!`. NewtonX namelist lines (`&...` and `/`) are ignored.
- **On and off:** `yes`/`no` and `true`/`false` are accepted for the `0`/`1` keys.

## Summary of keys

| Key | Default | Allowed values | Methods | Effect |
|---|---|---|---|---|
| [`couplings`](#couplings) | `nx` | `nx`, `neighbours`, `current`, `all` | coupling vectors (`vdoth = 0`) | Which coupling vectors are computed |
| [`use_prev_wf`](#use_prev_wf) | `0` | `0`, `1` | CASSCF | Start from the previous step's CASSCF orbitals |
| [`use_prev_scf_wf`](#use_prev_scf_wf) | `0` | `0`, `1` | all except CASSCF | Start the SCF from the previous step's orbitals |
| [`phase_ref`](#phase_ref) | `last` | `last`, `previous` | coupling vectors (`vdoth = 0`) | Phase reference for a coupling pair that returns after a gap |
| [`archive_molden`](#archive_molden) | `1` | `0`, `1` | all | Keep a Molden file of every step |
| [`archive_wf`](#archive_wf) | `1` | `0`, `1` | CASSCF | Keep the CASSCF orbitals of every step |

## Keys

### couplings

This key chooses which coupling vectors are computed at each step. It applies to `vdoth = 0` only; with `vdoth = 1` it has no effect. TeraChem computes one coupling vector per run, so each extra pair of states costs one more TeraChem run per step. Change it when you want a fixed scheme instead of the list NewtonX writes from `jiri.inp`.

| Value | Pairs computed at each step |
|---|---|
| `nx` (default) | The pairs NewtonX lists in `transmomin`, set by `jiri.inp` and `THRES`. See [Which couplings are computed](dynamics.md#which-couplings-are-computed). |
| `neighbours` | The active state with the state just below and the state just above. At most 2 runs. |
| `current` | The active state with every other state. `nstat − 1` runs. |
| `all` | Every pair of states. `nstat(nstat − 1)/2` runs. |

`neighbors` is accepted as well. The [sample trajectories](../sample_trajectories/README.md) use `neighbours` with [`phase_ref = previous`](#phase_ref), the scheme of the script that made them.

```text
couplings = neighbours
```

### use_prev_wf

This key starts each CASSCF step from the previous step's orbitals. It applies to CASSCF only, that is, templates with `casscf yes`. Turn it on to save time and to keep the active space continuous from step to step.

- **Gradient job:** reads the previous step's CASSCF orbitals as the guess. Any `guess`, `maxit` and `convthre` lines of the template are replaced by `guess <file>`, `maxit 0` and `convthre 1e7`, so the SCF is skipped and CASSCF optimizes the orbitals itself.
- **Coupling jobs:** start from the gradient job's orbitals of the same step.
- **First step:** if `JOB_NAD/c0.casscf` exists, it is used as the first guess.

```text
use_prev_wf = 1
```

### use_prev_scf_wf

This key starts the SCF of each step from the previous step's converged orbitals. It applies to every method except CASSCF, that is, templates without `casscf yes`. Turn it on when the SCF needs many iterations.

- **Gradient job:** reads the previous step's converged SCF orbitals as the guess. Only a `guess` line is added. The SCF, including the FON-SCF of FOMO, still runs to convergence.
- **Coupling jobs:** start from the gradient job's orbitals of the same step, so all jobs of a step sit on the same SCF solution.
- **Why FOMO has its own key:** without the FON-SCF, CASCI would run on unconverged orbitals. This key therefore never skips the SCF, unlike `use_prev_wf`.
- **Limit:** it does not prevent total-energy jumps when the SCF switches between near-degenerate solutions.

```text
use_prev_scf_wf = 1
```

### phase_ref

This key applies to `vdoth = 0` only; with `vdoth = 1` it has no effect. It decides how a coupling pair that was not computed at the previous step gets its sign. NewtonX corrects the sign of each coupling vector by comparing it with the previous step's vector, through its program `escalar`, which the interface runs with NewtonX 2.4 and 2.6 alike. A pair that was not computed at the previous step has no vector to compare with. This happens after a hop with `couplings = neighbours`, or when `THRES` or `jiri.inp` leaves a pair out for some steps. Keep the default for new trajectories. The [sample trajectories](../sample_trajectories/README.md) use `previous`, the rule of the script that made them.

| Value | A pair that returns after a gap |
|---|---|
| `last` (default) | Is compared with its last computed vector, so its sign stays continuous across the gap. |
| `previous` | Keeps the sign TeraChem gives it, as NewtonX's own interface template does. |

- **Where the memory lives:** with `last`, the interface keeps the last non-zero, phase-corrected vector of every pair in `INFO_RESTART/WF_OLD/nac_phase_ref`.
- **What it is used for:** only for the sign. NewtonX's interpolation still starts from the previous step's couplings, which are zero for a returning pair. NewtonX 2.4 reads them from `oldh`, and NewtonX 2.6 from `nad_vectors-dt`.
- **When it changes results:** only when a pair returns after a gap. Trajectories without gaps are identical with both values.
- **Evidence:** with `last`, 297 of 299 returning pairs got the right sign in the tests; see [Validation](validation.md#15-phase-reference-after-a-gap).

```text
phase_ref = previous
```

#### NewtonX 2.6

This part applies to NewtonX 2.6 only; it was checked on 2.6 (build 01). It covers `vdoth = 0` and `vdoth = 1`; with `vdoth = 1` the interface shields the correction in the same way, and all phase factors were +1 over 10 fs of uracil. NewtonX 2.4 has no second sign correction. NewtonX 2.6 corrects the signs again after the interface, with its own program `phase_correction` (`getphase = 1` in `sh.inp`, its default). It compares each vector with a value extrapolated from the two previous steps, 2 h(t−dt) − h(t−2dt).

- **Why the interface overrides it:** the extrapolation points the wrong way whenever a coupling shrinks by more than half in one step. This happens after the spike at a crossing, where hops occur, and for a pair that was zero at the previous step. NewtonX 2.6 then flips vectors that should keep their sign.
- **What the interface does:** it rewrites NewtonX's file `nad_vectors-2dt`, which only the sign correction reads, so that the extrapolated value equals the interface's own vector. NewtonX 2.6 then keeps every sign set by the interface, and runs follow the same sign rules as with NewtonX 2.4, including `phase_ref`.
- **What is lost:** NewtonX 2.6's extrapolation can follow a coupling that changes sign as it passes smoothly through zero. With the interface's rule such a coupling keeps its sign, as with NewtonX 2.4.
- **`getphase = 0`:** NewtonX 2.6 does not correct the signs, and the interface does nothing extra.

The tests are in [Validation](validation.md#16-newtonx-26).

### archive_molden

With `1`, the default, the Molden file of each step's gradient job is copied to `INFO_RESTART/MOLDEN_ARCHIVE/<time>.molden`. Set it to `0` to save disk space when you do not need the orbitals of every step.

```text
archive_molden = 0
```

### archive_wf

With `1`, the default, the CASSCF orbitals of each step are copied to `INFO_RESTART/WF_ARCHIVE/c<time>`. The previous step's orbitals are always kept in `INFO_RESTART/WF_OLD/` for `use_prev_wf`, whatever this key says. Set it to `0` to save disk space.

```text
archive_wf = 0
```

## Unknown keys and bad values

An unknown key or a bad value stops the trajectory before any TeraChem run, with a message that names the key. This catches typos such as `coupling = all`. The messages are listed in [Troubleshooting](troubleshooting.md#settings-file).

## How the settings are shown

The settings in effect are printed in `moldyn.log` at every step. With the [installer](installation.md)'s NewtonX registration, NewtonX also checks `terachem.par` and prints the settings when the run starts.

You can check a file yourself:

```bash
$NX/run-tera-cas.pl --check-options terachem.par
```

## See also

- [Running dynamics](dynamics.md): which couplings NewtonX asks for, and the keywords the interface manages
- [Method tutorials](methods.md): the keys that matter for each method
- [Troubleshooting](troubleshooting.md): messages about `terachem.par`
