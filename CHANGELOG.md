# Changelog

All notable changes to this interface. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [2.0.0] - 2026-11-09

### Changed

- **License.** The interface is now licensed under GPL-3.0-or-later (see `LICENSE`), as NewtonX requires for interfaces in its distribution. Earlier versions were released under the MIT license, copyright (c) 2025 Dakshitha Abeygunewardane. Each script carries an SPDX identifier, and `CITATION.cff` gives the citation and the method papers.
- **AI use.** This revision was refactored and improved with Claude Code (Anthropic), using the Claude Opus 5.5 model. See the Credits section of the README.
- **Couplings follow `jiri.inp`.** The interface now computes the coupling pairs NewtonX lists in `transmomin`, from `jiri.inp` and `THRES`. Earlier versions always computed the two neighbor couplings. Without a `jiri.inp`, NewtonX asks for every pair, which costs one TeraChem run per pair. Set `couplings = neighbours` and `phase_ref = previous` in `terachem.par` to reproduce runs made with earlier versions. See [Which couplings are computed](docs/dynamics.md#which-couplings-are-computed).
- **Options moved to `terachem.par`.** `use_prev_wf` and `use_prev_scf_wf` are no longer edited inside the script. See [terachem.par reference](docs/terachem-par.md).
- **Scratch handling.** Each job's scratch folder is cleared before the run, so a failed run can no longer leave last step's results to be read.
- **Coupling jobs and `use_prev_wf`.** With `use_prev_wf = 1`, CASSCF coupling jobs start from the same step's gradient orbitals instead of the previous step's.
- **Triplet energies.** Energies are taken only from rows of the target multiplicity, `castargetmult` or `cismult`.

### Added

- **One template.** A single `JOB_NAD/tera.sp` replaces the three `start.sp` files. The three-file layout still works.
- **`couplings` option:** `nx`, `neighbours`, `current` or `all`.
- **Adiabatic steps and time-dependent Baeck-An (TD-BA).** Steps that NewtonX marks adiabatic, through `THRES` or pure adiabatic dynamics, run the gradient job only and write zero couplings. `vdoth = 2` (TD-BA) is supported.
- **No coupling jobs after a hop.** In NewtonX's second call after a hop, coupling jobs are skipped.
- **Checks.** The interface stops with a clear message when TeraChem fails or does not finish, when a vector file has the wrong number of atoms, when energies are missing, or when `terachem.par` has an unknown key.
- **Full TDDFT (RPA).** `rpa yes` templates work for gradients, adiabatic steps and TD-BA. Coupling-vector runs with RPA are refused, because TeraChem writes zero vectors for them. Any all-zero coupling vector now triggers a warning in `moldyn.log`.
- **Initial conditions.** `run_tera_ic.pl` is now part of the repository. It supports CASSCF, FOMO-CASCI, TDA/TDDFT, hh-TDA and full TDDFT, and `nis > 1`.
- **`phase_ref` option.** A coupling pair that returns after a gap now gets its sign from its last computed vector (`phase_ref = last`, the default). Before, its sign was TeraChem's. `phase_ref = previous` keeps the old behavior.
- **Method tutorials and templates.** [Method tutorials](docs/methods.md) explains each method and coupling vectors and TD-BA couplings. Tested templates are in `examples/`.
- **Documentation.** A first-trajectory tutorial, a troubleshooting page and an output-files page. Each `examples/` folder is a complete 1 fs input with its own README, and each sample trajectory has a README.
- **NewtonX 2.6.** The interface works with NewtonX 2.6 as well as 2.4. NewtonX 2.6 corrects coupling signs again by extrapolation, which flips couplings that shrink quickly after a crossing. The interface sets NewtonX's reference so that 2.6 keeps the interface's signs, as 2.4 does. See [NewtonX 2.6](docs/terachem-par.md#newtonx-26).
- **Installer.** `install/install_nx.pl` registers TeraChem in NewtonX, copies the scripts and adds a NewtonX test.
- **Tests.** Unit tests, a record-and-replay harness and a NewtonX test case. See [Development and testing](docs/development.md) and [Validation](docs/validation.md).

### Fixed

- **Step type.** The interface read `type_of_dyn.out`, but NewtonX writes `typeofdyn.out`. It therefore never saw adiabatic steps and computed couplings that NewtonX did not use.
- **TD-BA.** `vdoth = 2` stopped the run.
- **Execute permission.** The script is now stored as executable.
- **`run_tera_ic.pl` for hh-TDA and TDA/TDDFT.** The old version found no oscillator strengths for hh-TDA and no energies for TDA/TDDFT.
- **Oscillator strengths for `nis > 1`.** The old version reported transitions out of the ground state whatever `nis` was.

## 2026-10-29 – coupling phase fix

NewtonX 2.4's `interpol.f90` rebuilds the couplings at every electronic substep from `oldh` and `newh`. The 2025 versions copied the raw couplings to `newh` before the phase correction, so the substep integration used couplings whose sign could flip between steps. The script now copies the phase-corrected couplings to `newh` after `escalar`. This affects every coupling-vector run made with the 2025 versions under NewtonX 2.4. NewtonX 2.6 reads its own copies of the couplings and was not affected.

Added at the same time: the wavefunction guess options `use_prev_wf` (CASSCF) and `use_prev_scf_wf` (FOMO-CASCI, TDA/TDDFT, hh-TDA).

## 2025

First public version. Supports CASSCF, FOMO-CASCI and TDA/TDDFT with neighbor coupling vectors. Tested with NewtonX 2.4 and TeraChem 1.9.
