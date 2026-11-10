[Home](../README.md) / Development and testing

# Development and testing

This page describes the unit tests, the record-and-replay harness, the phase-gap check and the NewtonX test case. Read it before you change the interface, so that you can show the change does not alter what NewtonX receives.

## Layout of tests/

```text
tests/
├── unit.t                     # unit tests, no GPU
├── fixtures/                  # real TeraChem 1.96 outputs used by unit.t
├── harness/                   # record-and-replay harness
│   ├── tc_proxy/bin/terachem  # caching stand-in for TeraChem
│   ├── record_wrapper.sh      # snapshots TEMP before and after each interface call
│   ├── make_nxbin.sh          # builds a private NewtonX bin folder
│   ├── replay.py              # replays recorded calls with several script versions
│   └── phase_gap_check.py     # tests phase_ref on simulated coupling gaps
└── nx/                        # NewtonX-style test and its reference results
    ├── MD-TERA-CASSCF-NAD-VEC/
    └── STANDARD-RESULTS/MD-TERA-CASSCF-NAD-VEC/
```

## Unit tests

```bash
NX=/path/to/newtonx/bin prove -v tests/unit.t
```

They need Perl 5.10 or newer and NewtonX's `colib_perl.pm`. They do not need TeraChem or a GPU. They cover option reading, state-pair indexing, template editing, `transmomin` reading, energy and oscillator parsing for all methods and multiplicities, and the checks on vector files.

## Replay harness

The harness checks that a change to the interface does not change what NewtonX receives. It works in three steps.

1. **Record.** Run a short trajectory with a reference version of the script. `record_wrapper.sh` saves `TEMP/` before and after every interface call. `tc_proxy` runs the real TeraChem and caches each job's output and scratch folder. The cache key is the input's keywords and the geometry.
2. **Replay.** `replay.py` rebuilds each recorded call and runs one or more script versions on it. `tc_proxy` serves the cached TeraChem results instead of running TeraChem.
3. **Compare.** The files NewtonX reads (`epot`, `oldepot`, `newepot`, `grad`, `grad.all`, `nad_vectors`, `oldh`, `newh`) are compared byte by byte with the first version.

Record a trajectory:

```bash
H=tests/harness
$H/make_nxbin.sh ~/nxbin_rec /path/to/reference/run-tera-cas.pl record
export NX=~/nxbin_rec TeraChem=$PWD/$H/tc_proxy TCPROXY_MODE=record
export TCPROXY_REAL=/path/to/TeraChem/bin/terachem TCPROXY_CACHE=~/tc_cache
export NXREC_DIR=$PWD/TRAJ1/SNAPSHOTS
(cd TRAJ1 && $NX/moldyn.pl > moldyn.log)
```

Replay it with two versions:

```bash
python3 $H/replay.py --snapshots TRAJ1/SNAPSHOTS --cache ~/tc_cache --work ~/replay \
    --variant ref=/path/to/reference/run-tera-cas.pl \
    --variant new=run-tera-cas.pl,par=neighbours.par
```

Here `neighbours.par` is a `terachem.par` with the line `couplings = neighbours`.

The harness needs Python 3.12 or newer, and NumPy for `phase_gap_check.py`. It uses `/software/NX-2.4-B06/bin` and this host's TeraChem by default. Set `SYS_NX` for `make_nxbin.sh`, `--nx` for the Python scripts and `TCPROXY_REAL` for the real TeraChem. The files it compares include `oldh` and `newh`, which NewtonX 2.4 reads for its interpolation; NewtonX 2.6 reads `nad_vectors-dt` instead.

Variant options, after the script path:

| Option | Effect |
|---|---|
| `par=FILE` | Use FILE as `terachem.par` |
| `single` | Convert the three-template layout to one `tera.sp` |
| `second` | Pretend the call is the second run after a hop |
| `state=N` | Set the current state to N |
| `type=N` | Write N to `typeofdyn.out` (1 = adiabatic step) |
| `cache=DIR` | Use a separate cache, to force real TeraChem runs |

Add `--record` to let `tc_proxy` run real TeraChem for jobs that are not in the cache. This needs a GPU.

> [!IMPORTANT]
> The cache key leaves out `guess`, `scrdir` and `coordinates`. A replay therefore cannot show how real TeraChem reacts to those keywords. Check changes to them with real runs, using `cache=DIR` or a full trajectory.

## Phase-gap check

`tests/harness/phase_gap_check.py` tests [`phase_ref`](terachem-par.md#phase_ref) on a recorded trajectory without a GPU. It replays each call with one coupling pair removed from the previous step, as if the pair had not been computed. Then it checks whether the returning vector has the same sign as in the recorded, gap-free trajectory, for both values of `phase_ref` and several gap lengths.

```bash
python3 tests/harness/phase_gap_check.py --snapshots TRAJ1/SNAPSHOTS --cache ~/tc_cache \
    --work ~/gapcheck --script run-tera-cas.pl --gaps 1,2,5
```

## NewtonX test

`tests/nx/MD-TERA-CASSCF-NAD-VEC` is a 2 fs CASSCF(2,2) run of twisted ethylene with neighbor couplings. The [installer](installation.md) adds it to NewtonX's `test-nx` folder and to `test_list`. NewtonX's test tool compares the `Wave function state` lines of `RESULTS/dyn.out` with the reference within 1e-3.

To update the reference after an intended change, run the test folder with NewtonX and copy its `RESULTS/dyn.out` to `tests/nx/STANDARD-RESULTS/MD-TERA-CASSCF-NAD-VEC/RESULTS/`. Say why in the commit message.

## See also

- [Validation](validation.md): the results of these tests for version 2.0.0
- [Installation](installation.md): how the NewtonX test case is installed
- [Changelog](../CHANGELOG.md): record each change there
