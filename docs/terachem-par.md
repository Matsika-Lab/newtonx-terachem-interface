[← README](../README.md)

# terachem.par options

`terachem.par` holds the interface's own options. Put it in the trajectory folder, next to `control.dyn`. NewtonX copies it to `TEMP/` at every step, as it does for other programs' `.par` files.

The file is optional. Without it, every option keeps its default.

## Example

```text
 couplings       = neighbours
 use_prev_scf_wf = 1
 archive_molden  = 1
```

The format is `key = value`, one per line. `key value` without `=` also works. Comments start with `#` or `!`. NewtonX namelist lines (`&...` and `/`) are ignored.

## Defaults

| Key | Default | Allowed values | Methods | Effect |
|---|---|---|---|---|
| [`couplings`](#couplings) | `nx` | `nx`, `neighbours`, `current`, `all` | all | Which coupling vectors are computed |
| [`use_prev_wf`](#use_prev_wf) | `0` | `0`, `1` | CASSCF | Start from the previous step's CASSCF orbitals |
| [`use_prev_scf_wf`](#use_prev_scf_wf) | `0` | `0`, `1` | FOMO-CASCI, TDA/TDDFT, hh-TDA | Start the SCF from the previous step's orbitals |
| [`phase_ref`](#phase_ref) | `last` | `last`, `previous` | NAC (`vdoth = 0`) | Phase reference for a coupling pair that returns after a gap |
| [`archive_molden`](#archive_molden) | `1` | `0`, `1` | all | Keep a Molden file of every step |
| [`archive_wf`](#archive_wf) | `1` | `0`, `1` | CASSCF | Keep the CASSCF orbitals of every step |

`yes`/`no` and `true`/`false` are accepted for the `0`/`1` keys.

## couplings

TeraChem computes one coupling vector per run. Each extra pair of states costs one more TeraChem run per step.

| Value | Pairs computed at each step |
|---|---|
| `nx` | The pairs NewtonX lists in `transmomin`, set by `jiri.inp` and `THRES`. See [Which couplings are computed](dynamics.md#which-couplings-are-computed). |
| `neighbours` | The current state with the state just below and the state just above. At most 2 runs. |
| `current` | The current state with every other state. `nstat − 1` runs. |
| `all` | Every pair of states. `nstat(nstat − 1)/2` runs. |

`neighbors` is accepted as well. `neighbours`, together with [`phase_ref = previous`](#phase_ref), reproduces the behaviour of versions before 2.0.

## use_prev_wf

CASSCF only, that is, templates with `casscf yes`.

- **Gradient job:** reads the previous step's CASSCF orbitals as the guess. It adds `maxit 0`, so the SCF is skipped and CASSCF optimizes the orbitals itself.
- **Coupling jobs:** start from the gradient job's orbitals of the same step.
- **First step:** if `JOB_NAD/c0.casscf` exists, it is used as the first guess. The older location `JOB_NAD/GRAD/scr.geom/c0.casscf` also works.

## use_prev_scf_wf

FOMO-CASCI, TDA/TDDFT and hh-TDA, that is, templates without `casscf yes`.

- **Gradient job:** reads the previous step's converged SCF orbitals as the guess. Only a `guess` line is added. The SCF, including the FON-SCF of FOMO, still runs to convergence.
- **Coupling jobs:** start from the gradient job's orbitals of the same step, so all jobs of a step sit on the same SCF solution.

> [!NOTE]
> Do not skip the SCF for FOMO. Without the FON-SCF, CASCI would run on unconverged orbitals. This is why FOMO has its own option.

In tests on hh-TDA trajectories with near-degenerate SCF solutions, this option did not remove total-energy jumps caused by switches between SCF solutions.

## phase_ref

NewtonX fixes the sign of each coupling vector by comparing it with the previous step's vector, through its program `escalar`. A pair that was not computed at the previous step has no vector to compare with. This happens after a hop in `neighbours` mode, or when `THRES` or `jiri.inp` leaves a pair out for some steps.

| Value | A pair that returns after a gap |
|---|---|
| `last` (default) | Is compared with its last computed vector, so its sign stays continuous across the gap. |
| `previous` | Keeps the sign TeraChem gives it. This matches NewtonX's own template and versions before 2.0. Use it to reproduce runs made with those versions. |

- **Where the memory lives:** with `last`, the interface keeps the last non-zero, phase-corrected vector of every pair in `INFO_RESTART/WF_OLD/nac_phase_ref`.
- **What it is used for:** only for the sign. NewtonX's interpolation still starts from the previous step's couplings, which are zero for a returning pair.
- **When it changes results:** only when a pair returns after a gap. Trajectories without gaps are identical with both values.

In tests on recorded trajectories, TeraChem's raw sign of a returning pair agreed with the gap-free trajectory only about half the time with `previous`. With `last` it agreed in 218 of 220 cases. This is why `last` is the default. See [validation.md](validation.md#15-phase-reference-after-a-gap).

## archive_molden

With `1`, the Molden file of each step's gradient job is copied to `INFO_RESTART/MOLDEN_ARCHIVE/<time>.molden`.

## archive_wf

With `1`, the CASSCF orbitals of each step are copied to `INFO_RESTART/WF_ARCHIVE/c<time>`. The previous step's orbitals are always kept in `INFO_RESTART/WF_OLD/` for `use_prev_wf`, whatever this option says.

## Unknown keys and bad values

An unknown key or a bad value stops the trajectory before any TeraChem run, with a message that names the key. This catches typos such as `coupling = all`.

## How the options are shown

The options in effect are printed in `moldyn.log` at every step. With the [installer](installation.md)'s NewtonX registration, NewtonX also checks `terachem.par` and prints the options when the run starts.

You can check a file yourself:

```bash
$NX/run-tera-cas.pl --check-options terachem.par
```
