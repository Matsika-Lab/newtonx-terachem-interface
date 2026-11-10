[← README](../README.md)

# terachem.par options

`terachem.par` holds the interface's own options. Put it in the trajectory folder, next to `control.dyn`. NewtonX copies it to `TEMP/` when the run starts, so edits during a run have no effect. On a restart with `nxrestart = 1`, NewtonX uses the copy in `INFO_RESTART/`.

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
| [`use_prev_scf_wf`](#use_prev_scf_wf) | `0` | `0`, `1` | all except CASSCF | Start the SCF from the previous step's orbitals |
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

`neighbors` is accepted as well. The [sample trajectories](../sample_trajectories) use `neighbours` with [`phase_ref = previous`](#phase_ref), the scheme of the script that made them.

## use_prev_wf

CASSCF only, that is, templates with `casscf yes`.

- **Gradient job:** reads the previous step's CASSCF orbitals as the guess. Any `guess`, `maxit` and `convthre` lines of the template are replaced by `guess <file>`, `maxit 0` and `convthre 1e7`, so the SCF is skipped and CASSCF optimizes the orbitals itself.
- **Coupling jobs:** start from the gradient job's orbitals of the same step.
- **First step:** if `JOB_NAD/c0.casscf` exists, it is used as the first guess.

## use_prev_scf_wf

Every method except CASSCF, that is, templates without `casscf yes`.

- **Gradient job:** reads the previous step's converged SCF orbitals as the guess. Only a `guess` line is added. The SCF, including the FON-SCF of FOMO, still runs to convergence.
- **Coupling jobs:** start from the gradient job's orbitals of the same step, so all jobs of a step sit on the same SCF solution.

> [!NOTE]
> Do not skip the SCF for FOMO. Without the FON-SCF, CASCI would run on unconverged orbitals. This is why FOMO has its own option.

This option does not prevent total-energy jumps when the SCF switches between near-degenerate solutions.

## phase_ref

NewtonX fixes the sign of each coupling vector by comparing it with the previous step's vector, through its program `escalar`. A pair that was not computed at the previous step has no vector to compare with. This happens after a hop in `neighbours` mode, or when `THRES` or `jiri.inp` leaves a pair out for some steps.

| Value | A pair that returns after a gap |
|---|---|
| `last` (default) | Is compared with its last computed vector, so its sign stays continuous across the gap. |
| `previous` | Keeps the sign TeraChem gives it, as NewtonX's own interface template does. |

- **Where the memory lives:** with `last`, the interface keeps the last non-zero, phase-corrected vector of every pair in `INFO_RESTART/WF_OLD/nac_phase_ref`.
- **What it is used for:** only for the sign. NewtonX's interpolation still starts from the previous step's couplings, which are zero for a returning pair.
- **When it changes results:** only when a pair returns after a gap. Trajectories without gaps are identical with both values.

### NewtonX 2.6

NewtonX 2.6 corrects the signs again after the interface, with its own program `phase_correction` (`getphase = 1` in `sh.inp`, its default). It compares each vector with a value extrapolated from the two previous steps. This also catches a coupling that changes sign as it passes through zero.

- **Pairs computed at the previous step:** NewtonX 2.6 decides their sign; `phase_ref` has no effect on them.
- **Pairs that return after a gap:** the interface's sign is kept, as described above. For a gap of one step, NewtonX 2.6's extrapolation would turn the returning vector against its last vector. The interface prevents this by clearing that pair from NewtonX's file `nad_vectors-2dt`, which only the sign correction reads.
- **`getphase = 0`:** NewtonX 2.6 leaves the signs to the interface, as NewtonX 2.4 does.

`last` is the default because TeraChem's sign for a returning pair is arbitrary. The test results are in [validation.md](validation.md#15-phase-reference-after-a-gap).

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
