[← README](../README.md)

# Validation

These tests were run for version 2.0 before release. The reference is the previous version of `run-tera-cas.pl`, at commit `35c7390`, which includes the coupling phase fix.

## Environment

| Item | Version |
|---|---|
| NewtonX | 2.4 (build B06) |
| TeraChem | 1.96 beta (build 2024-11-09) |
| GPU | NVIDIA RTX 5000 Ada, one per job |
| Perl | 5.34 |
| Date | 2026-11-09 |

## Summary

| # | Test | What it checks | Key number | Result |
|---|---|---|---|---|
| 1 | [Byte-identity replay](#1-byte-identity-replay) | New script gives the same NewtonX files as the old one | 101 of 101 calls identical | pass |
| 2 | [Second run after a hop](#2-second-run-after-a-hop) | Coupling jobs skipped, results unchanged | 6 instead of 12 TeraChem runs | pass |
| 3 | [SCF guess option](#3-scf-guess-option) | `use_prev_scf_wf` matches the old version | 38 of 38 calls identical | pass |
| 4 | [Adiabatic step](#4-adiabatic-step) | Gradient only, zero couplings written | 1 TeraChem run | pass |
| 5 | [Single template](#5-single-template) | One template gives the same results as three | max \|Δh\| = 7.6e-5 a.u. after step 1 | pass |
| 6 | [Couplings from jiri.inp](#6-couplings-from-jiriinp) | Pairs follow `transmomin`; shared pairs unchanged | shared pair \|Δh\| = 0 | pass |
| 7 | [CASSCF guess option](#7-casscf-guess-option) | `use_prev_wf` with real runs | identical files | pass |
| 8 | [Triplets](#8-triplets) | Energies and couplings for one multiplicity | 3 methods | pass, with limits |
| 9 | [Full TDDFT (RPA)](#9-full-tddft-rpa) | RPA gradients and couplings | couplings are zero; gradient error 1.8e-6 | guarded |
| 10 | [Initial conditions](#10-initial-conditions) | `run_tera_ic.pl` for all methods | 4 of 4 methods | pass |
| 11 | [NewtonX trajectories](#11-newtonx-trajectories) | Full runs with real TeraChem | energies match the old version to 1e-9 a.u. | pass |
| 12 | [Installer](#12-installer) | colib edits, reruns, other programs kept | 2 NewtonX trees | pass |
| 13 | [Unit tests](#13-unit-tests) | Parsing and logic without GPU | 12 groups | pass |
| 14 | [Example templates](#14-example-templates) | Each `examples/` template runs in NewtonX | 5 of 5 templates | pass |
| – | [TeraChem behaviour](#terachem-behaviour) | Facts the interface relies on | 10 checks | – |

## How the comparisons work

Tests 1 to 7 use the replay harness described in [development.md](development.md#replay-harness).

- **Recording:** short trajectories were run with the old script. Every interface call was recorded, together with every TeraChem job.
- **Replay:** each call was then replayed with the old and the new script on the same TeraChem results.
- **Comparison:** the eight files NewtonX reads (`epot`, `oldepot`, `newepot`, `grad`, `grad.all`, `nad_vectors`, `oldh`, `newh`) were compared byte by byte.
- **Real runs:** where a test needs TeraChem jobs that were not recorded, they were run for real.

Recorded systems:

| System | Method | States | Calls | Hops |
|---|---|---|---|---|
| Uracil | FOMO-CASCI(14,10)/cc-pVDZ, T = 0.2 | 3 singlets | 32 | 1 |
| Uracil | hh-TDA BHHLYP/6-31G* | 3 singlets | 17 | 0 |
| Uracil | TDA CAM-B3LYP/6-31G* | 3 singlets | 21 | 0 |
| Twisted ethylene | SA-3-CASSCF(2,2)/6-31G* | 3 singlets | 31 | 0 |

## 1. Byte-identity replay

**Purpose.** Check that the rewrite changes nothing NewtonX sees, when the old behaviour is asked for.

**Setup.** All 101 recorded calls. New script with `couplings = neighbours` and the three-template layout.

| System | Calls | Identical |
|---|---|---|
| FOMO-CASCI, including the hop | 32 | 32 |
| hh-TDA | 17 | 17 |
| TDA | 21 | 21 |
| CASSCF | 31 | 31 |

**Conclusion.** All eight files are byte-identical in every call.

## 2. Second run after a hop

**Purpose.** After a hop, NewtonX calls the interface again for the new gradient. The new script skips the coupling jobs then.

**Setup.** 6 TDA calls replayed as second runs, with both scripts.

| | Old | New |
|---|---|---|
| TeraChem runs | 12 | 6 |
| NewtonX files | – | identical to old |

**Conclusion.** Half the TeraChem runs in a second call, with the same results.

## 3. SCF guess option

**Purpose.** `use_prev_scf_wf = 1` gives the same files as the old script with the same option.

**Setup.** hh-TDA (17 calls) and TDA (21 calls). Both scripts write the same `guess` lines.

**Result.** 38 of 38 calls identical.

## 4. Adiabatic step

**Purpose.** When NewtonX marks a step adiabatic (`typeofdyn.out` = 1), only the gradient is computed, and the couplings are written as zeros instead of being kept from the last coupled step.

**Setup.** One TDA call replayed as an adiabatic step.

| Check | Result |
|---|---|
| `epot`, `grad`, `grad.all` | identical to the old script |
| TeraChem runs | 1 |
| `nad_vectors`, `newh` | all zero |

## 5. Single template

**Purpose.** One `tera.sp` gives the same results as three `start.sp` files.

**Setup.** The gradient template was used as `tera.sp`. First 7 calls of each system. hh-TDA coupling jobs differ from the recorded ones by one keyword (`cistarget` is dropped), so they were run for real.

| System | Calls | Result |
|---|---|---|
| CASSCF | 7 | identical |
| TDA | 7 | identical |
| hh-TDA | 7 | first call: coupling sign flipped, \|new + old\| ≤ 5.2e-6 a.u.; later calls: max \|Δh\| = 7.6e-5 a.u. |

**Conclusion.** Equivalent. At the first step there is no previous coupling to fix the sign against, so either sign is valid. Later differences are at the level of SCF convergence.

## 6. Couplings from jiri.inp

**Purpose.** By default the interface computes the pairs NewtonX lists in `transmomin`.

**Setup.** TDA and hh-TDA, 7 calls each, with no `jiri.inp`. NewtonX then lists every pair: S1–S0, S2–S0 and S2–S1. The old script computed only the neighbour pair, S2–S1.

| System | S2–S1 block vs old | S1–S0, S2–S0 |
|---|---|---|
| TDA | identical | computed; max \|h\| = 0.43 a.u. |
| hh-TDA | identical | computed; max \|h\| = 0.57 a.u. |

## 7. CASSCF guess option

**Purpose.** With `use_prev_wf = 1`, coupling jobs now start from the same step's gradient orbitals. Check that results do not change.

**Setup.** Ethylene CASSCF, 6 calls, real TeraChem runs for both scripts. Each script had its own cache, so nothing was reused.

| | Old | New |
|---|---|---|
| NewtonX files | – | identical |
| Coupling job time | 1.4–2.4 s | 1.2–1.3 s |

**Conclusion.** Same results. The saving grows with system size.

## 8. Triplets

**Setup.** Single points on ethylene with one multiplicity.

| Method | Energies | Gradient | Coupling | Note |
|---|---|---|---|---|
| FOMO-CASCI(4,4), 3 triplets | yes | yes | yes | Coupling jobs need `castargetmult 3`; without it TeraChem stops |
| hh-TDA, `cismult 3` | yes | yes | yes | Rows are labelled `triplet`; the interface selects them |
| TDA, `cismult 3` | – | no | no | TeraChem: "not implemented for triplets in restricted Kohn-Sham DFT" |

## 9. Full TDDFT (RPA)

**Setup.** Ethylene, B3LYP/6-31G*, `rpa yes`.

| Check | Result |
|---|---|
| Coupling run | Finishes normally (exit 0) but writes a coupling vector of zeros. TDA on the same geometry gives up to 0.048 a.u. |
| Gradient of state 2 | Analytic dE/dz = 0.006812, finite difference (±0.001 Bohr) = 0.006810; difference 1.8e-6 Hartree/Bohr |

**Conclusion.** RPA cannot give coupling vectors, so the interface refuses `rpa yes` with `vdoth = 0`. RPA gradients are correct, so RPA with TD-BA (`vdoth = 2`) is possible.

## 10. Initial conditions

**Setup.** One uracil geometry per method, `nis = 1`, `nfs = 3`, real TeraChem. One ethylene CASSCF case with `nis = 2` and NewtonX's reference-geometry flag.

| Method | New script | Old script |
|---|---|---|
| FOMO-CASCI | f(1→2) = 0.0384, f(1→3) = 0.2372 | identical energies and f |
| hh-TDA | f(1→2) = 0.00223677, f(1→3) = 0.78594484 | energies only; stopped: "Oscillator strength section not found" |
| TDA | f(1→2) = 0.0003, f(1→3) = 0.2278 | stopped: no energies, no oscillator strengths |
| CASSCF, `nis = 2` | f(2→3) = 0.3638 from TeraChem's table; `epot0.3` written | – |

Oscillator strengths computed from transition dipoles (used for `nis > 1` when TeraChem prints none) agree with TeraChem's printed values: 0.786 vs 0.78597 for hh-TDA, and 0.0137 within 5e-4 for FOMO 2→3.

## 11. NewtonX trajectories

**Setup.** Complete NewtonX runs with the new script and real TeraChem, no replay. dt = 0.5 fs, one GPU each.

| Run | Template | Couplings | Length | Result |
|---|---|---|---|---|
| Ethylene CASSCF | single `tera.sp` | NewtonX default (all 3 pairs) | 8 fs | Energies identical to the old script's trajectory at 8 fs (to 1e-9 a.u.). No hop. |
| Uracil FOMO-CASCI | three `start.sp` | `jiri.inp` with `current = 1`: S2–S1 and S2–S0 | 5 fs | Energies identical to the old script's trajectory at 5 fs (to 1e-9 a.u.). The S2–S0 pair was built from the coupling template. |
| Ethylene CASSCF | single `tera.sp` | TD-BA, `vdoth = 2` | 8 fs | Ran with one TeraChem job per step; one hop, S2 → S1. |
| Ethylene CASSCF | single `tera.sp` | `THRES = 1` eV | 8 fs | 2 nonadiabatic steps, then 15 adiabatic steps with the gradient job only and zero couplings. Worst energy deviation 0.17 mEh. |

Energy conservation over 8 fs was the same as with the old script: worst deviation 1.0 mEh for the strained ethylene start, 0.3 mEh for uracil.

## 12. Installer

| Check | Result |
|---|---|
| `--dry-run` | Lists all changes, writes nothing |
| Install on a NewtonX tree with older hand-made TeraChem blocks and a QChem block | Old TeraChem blocks replaced, QChem block kept, prog 21.0 resolves to the new scripts |
| Second install | `colib_perl.pm` identical to the first install |
| Install on stock NewtonX 2.4 | Four blocks added, file compiles |
| NewtonX test `MD-TERA-CASSCF-NAD-VEC` | Runs in about one minute; reference results stored |

## 13. Unit tests

`tests/unit.t` has 12 groups. They need no GPU. All pass. They use the real TeraChem outputs in `tests/fixtures/`, among them a triplet FOMO run, a triplet hh-TDA run and an RPA run.

## 14. Example templates

**Purpose.** Every template in `examples/` must run as published.

**Setup.** Twisted ethylene, 6-31G*, 3 singlets, starting on S1, 1 fs (2 steps). Neighbour couplings from `jiri.inp`. Each template was used unchanged as `JOB_NAD/tera.sp`, with the installed interface.

| Template | Couplings | Pairs per step | Result |
|---|---|---|---|
| `casscf` | NAC | S1–S0, S2–S1 | 2 steps, no warnings |
| `fomo-casci` | NAC | S1–S0, S2–S1 | 2 steps, no warnings |
| `tda` | NAC | S1–S0, S2–S1 | 2 steps, no warnings |
| `hh-tda` | NAC | S1–S0, S2–S1 | 2 steps, no warnings |
| `rpa-tdba` | TD-BA | none (NewtonX computes TD-BA) | 2 steps, no warnings |

The hh-TDA FOMO window was checked first. With `active 9`, the excitation energies were 6.5 and 7.9 eV, consistent with TDA (6.9 and 8.6 eV). With `active 8` TeraChem stopped, and with `active 10` the states came out wrong.

## TeraChem behaviour

Facts about TeraChem 1.96 that the interface depends on, each checked with a small test job.

| Behaviour | Observed | Consequence for the interface |
|---|---|---|
| Couplings per run | One. `nacstate3` is accepted but ignored; the vector is identical to the run without it. | One TeraChem run per coupling pair |
| Keyword values | Lowercased, including paths: `scrdir /a/B` becomes `/a/b` | `scrdir` is never used; jobs write `./scr.geom`, which the interface moves |
| `guess` paths | Case is kept | Absolute guess paths are safe |
| Lines after `end` | Still read | Inserted lines go before `end` anyway |
| Exit code on failure | Non-zero, for example for a missing guess file | Failures are caught, plus a check for "Job finished" |
| RPA couplings | Zero vector, exit 0 | RPA with coupling vectors refused; all-zero vectors warned |
| `cis yes` with `rpa yes` | Refused: "Can not run both CIS and RPA" | Documented: use `rpa yes` alone |
| TDA/TDDFT triplet gradients | Not implemented | Documented as not supported |
| Triplet CAS couplings | Need `castargetmult 3` | Template check with a clear message |
| hh-TDA `cistarget` | `cistarget k` gives the gradient of root k + 1, counting the ground state as root 1 (finite differences on two coordinates agree to 1e-4). The `FINAL Target State Energy` line shows root k instead. | `cistarget` = state − 1 is right; that output line is not used |
