# Changelog

All notable changes to this interface. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [2.0.0] – unreleased

### Changed

- **Couplings follow `jiri.inp`.** The interface now computes the coupling pairs NewtonX lists in `transmomin`, from `jiri.inp` and `THRES`. Earlier versions always computed the two neighbour couplings. Without a `jiri.inp`, NewtonX asks for every pair, which costs one TeraChem run per pair. Set `couplings = neighbours` in `terachem.par` for the old behaviour. See [Which couplings are computed](docs/dynamics.md#which-couplings-are-computed).
- **Options moved to `terachem.par`.** `use_prev_wf` and `use_prev_scf_wf` are no longer edited inside the script. See [terachem-par.md](docs/terachem-par.md).
- **Scratch handling.** Each job's scratch folder is cleared before the run, so a failed run can no longer leave last step's results to be read.
- **Coupling jobs and `use_prev_wf`.** With `use_prev_wf = 1`, CASSCF coupling jobs start from the same step's gradient orbitals instead of the previous step's.
- **Triplet energies.** Energies are taken only from rows of the target multiplicity, `castargetmult` or `cismult`.

### Added

- **One template.** A single `JOB_NAD/tera.sp` replaces the three `start.sp` files. The three-file layout still works.
- **`couplings` option:** `nx`, `neighbours`, `current` or `all`.
- **Adiabatic steps and TD-BA.** Steps that NewtonX marks adiabatic, through `THRES` or pure adiabatic dynamics, run the gradient job only and write zero couplings. `vdoth = 2` (TD-BA) is supported.
- **No coupling jobs after a hop.** In NewtonX's second call after a hop, coupling jobs are skipped.
- **Checks.** The interface stops with a clear message when TeraChem fails or does not finish, when a vector file has the wrong number of atoms, when energies are missing, or when `terachem.par` has an unknown key.
- **Full TDDFT (RPA).** `rpa yes` templates work for gradients, adiabatic steps and TD-BA. Coupling-vector runs with RPA are refused, because TeraChem writes zero vectors for them. Any all-zero coupling vector now triggers a warning in `moldyn.log`.
- **Initial conditions.** `run_tera_ic.pl` is now part of the repository. It supports CASSCF, FOMO-CASCI, TDA/TDDFT and hh-TDA, and `nis > 1`.
- **Method tutorials and templates.** [methods.md](docs/methods.md) explains each method and the NAC and TD-BA couplings. Tested templates are in `examples/`.
- **Installer.** `install/install_nx.pl` registers TeraChem in NewtonX, copies the scripts and adds a NewtonX test.
- **Tests.** Unit tests, a record-and-replay harness and a NewtonX test case. See [development.md](docs/development.md) and [validation.md](docs/validation.md).

### Fixed

- **Step type.** The interface read `type_of_dyn.out`, but NewtonX writes `typeofdyn.out`. It therefore never saw adiabatic steps and computed couplings that NewtonX did not use.
- **TD-BA.** `vdoth = 2` stopped the run.
- **Execute permission.** The script is now stored as executable.
- **`run_tera_ic.pl` for hh-TDA and TDA/TDDFT.** The old version found no oscillator strengths for hh-TDA and no energies for TDA/TDDFT.
- **Oscillator strengths for `nis > 1`.** The old version reported transitions out of the ground state whatever `nis` was.

## 2026-10-29 – coupling phase fix

NewtonX's `interpol.f90` rebuilds the couplings at every electronic substep from `oldh` and `newh`. The 2025-10-20 refactor copied the raw couplings to `newh` before the phase correction, so the substep integration used couplings whose sign could flip between steps. The script now copies the phase-corrected couplings to `newh` after `escalar`. This affects every coupling-vector run made with the 2025-10-20 version.

Added at the same time: the wavefunction guess options `use_prev_wf` (CASSCF) and `use_prev_scf_wf` (FOMO-CASCI, TDA/TDDFT, hh-TDA).

## 2025

First public version. Supports CASSCF, FOMO-CASCI and TDA/TDDFT with neighbour coupling vectors. Tested with NewtonX 2.4 and TeraChem 1.9.
