[Home](../README.md) / Validation

# Validation

This page holds every benchmark, timing and validation run of interface version 2.0.0. Read it when you want the evidence behind a statement on another page, or when you change the interface and need to repeat a test. The reference for the comparisons is the previous version of `run-tera-cas.pl`, at commit `35c7390`, which includes the coupling phase correction of October 2026.

## Summary

| # | Test | What it checks | Key number | Result |
|---|---|---|---|---|
| 1 | [Byte-identity replay](#1-byte-identity-replay) | 2.0.0 gives the same NewtonX files as the reference | 101 of 101 calls identical | pass |
| 2 | [Second run after a hop](#2-second-run-after-a-hop) | Coupling jobs skipped, results unchanged | 6 instead of 12 TeraChem runs | pass |
| 3 | [SCF guess option](#3-scf-guess-option) | `use_prev_scf_wf` matches the reference | 38 of 38 calls identical | pass |
| 4 | [Adiabatic step](#4-adiabatic-step) | Gradient only, zero couplings written | 1 TeraChem run | pass |
| 5 | [Single template](#5-single-template) | One template gives the same results as three | max \|Δh\| = 7.6e-5 a.u. after step 1 | pass |
| 6 | [Couplings from jiri.inp](#6-couplings-from-jiriinp) | Pairs follow `transmomin`; shared pairs unchanged | shared pair \|Δh\| = 0 | pass |
| 7 | [CASSCF guess option](#7-casscf-guess-option) | `use_prev_wf` with real runs | identical files | pass |
| 8 | [Triplets](#8-triplets) | Energies and couplings for one multiplicity | 3 methods | pass, with limits |
| 9 | [Full TDDFT (RPA)](#9-full-tddft-rpa) | RPA gradients and couplings | couplings are zero; gradient error 1.8e-6 | guarded |
| 10 | [Initial conditions](#10-initial-conditions) | `run_tera_ic.pl` for all methods | 4 of 5 methods with TeraChem; RPA by unit test | pass |
| 11 | [NewtonX trajectories](#11-newtonx-trajectories) | Full runs with real TeraChem | energies match the reference to 1e-9 a.u. | pass |
| 12 | [Installer](#12-installer) | colib edits, reruns, other programs kept | 2 NewtonX trees | pass |
| 13 | [Unit tests](#13-unit-tests) | Parsing and logic without GPU | 15 groups | pass |
| 14 | [Example inputs](#14-example-inputs) | Each `examples/` input runs in NewtonX; time per step | 5 of 5 inputs; 13–14 s per CASSCF step | pass |
| 15 | [Phase reference after a gap](#15-phase-reference-after-a-gap) | `phase_ref = last` keeps signs continuous | 297 of 299 vs 159 of 299 | pass |
| 16 | [NewtonX 2.6](#16-newtonx-26) | Installer, dynamics, TD-BA, restart, initial conditions and signs under 2.6 | signs identical with and without gaps | pass |
| 17 | [TeraChem behavior](#17-terachem-behavior) | Facts the interface relies on | 10 checks | – |

## Test environment

Unless a section says otherwise, every test ran in this environment.

| Item | Version |
|---|---|
| Interface | 2.0.0, branch `interface-improvements` |
| Reference interface | `run-tera-cas.pl` at commit `35c7390` |
| NewtonX | 2.4 (build 06); 2.6 (build 01) for [section 16](#16-newtonx-26) |
| TeraChem | 1.96 beta (build 2024-11-09) |
| GPU | NVIDIA RTX 5000 Ada, one per job |
| Perl | 5.34 |
| Date | 2026-11-09 |

## How the comparisons work

Tests 1 to 7 use the replay harness described in [Development and testing](development.md#replay-harness).

- **Recording:** short trajectories were run with the reference `35c7390` under NewtonX 2.4. Every interface call was recorded, together with every TeraChem job.
- **Replay:** each call was then replayed with the reference and with 2.0.0 on the same TeraChem results.
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

**Purpose.** Check that 2.0.0 changes nothing NewtonX sees, when the behavior of the reference is asked for.

**Setup.** Interface 2.0.0 against the reference `35c7390`, NewtonX 2.4 (build 06), TeraChem 1.96 beta results from the recordings. All 101 recorded calls. 2.0.0 ran with `couplings = neighbours`, the three-template layout, and `phase_ref` at both values.

| System | Calls | Identical |
|---|---|---|
| FOMO-CASCI, including the hop | 32 | 32 |
| hh-TDA | 17 | 17 |
| TDA | 21 | 21 |
| CASSCF | 31 | 31 |

**Conclusion.** All eight files are byte-identical in every call.

## 2. Second run after a hop

**Purpose.** After a hop, NewtonX calls the interface again for the new gradient. Version 2.0.0 skips the coupling jobs in that call.

**Setup.** Interface 2.0.0 against the reference `35c7390`, NewtonX 2.4 (build 06), TeraChem 1.96 beta results from the recordings. 6 TDA calls were replayed as second runs, with both versions.

| | Reference `35c7390` | 2.0.0 |
|---|---|---|
| TeraChem runs | 12 | 6 |
| NewtonX files | – | identical to the reference |

**Conclusion.** A second call needs half the TeraChem runs, with the same results.

## 3. SCF guess option

**Purpose.** Check that `use_prev_scf_wf = 1` gives the same files as the reference with the same option.

**Setup.** Interface 2.0.0 against the reference `35c7390`, NewtonX 2.4 (build 06), TeraChem 1.96 beta results from the recordings. hh-TDA (17 calls) and TDA (21 calls). Both versions write the same `guess` lines.

| System | Calls | Identical |
|---|---|---|
| hh-TDA | 17 | 17 |
| TDA | 21 | 21 |

**Conclusion.** 38 of 38 calls are identical.

## 4. Adiabatic step

**Purpose.** When NewtonX marks a step adiabatic (`typeofdyn.out` = 1), only the gradient is computed, and the couplings are written as zeros instead of being kept from the last coupled step.

**Setup.** Interface 2.0.0 against the reference `35c7390`, NewtonX 2.4 (build 06), TeraChem 1.96 beta results from the recordings. One TDA call was replayed as an adiabatic step.

| Check | Result |
|---|---|
| `epot`, `grad`, `grad.all` | identical to the reference |
| TeraChem runs | 1 |
| `nad_vectors`, `newh` | all zero |

**Conclusion.** An adiabatic step costs one TeraChem run and writes zero couplings.

## 5. Single template

**Purpose.** Check that one `tera.sp` gives the same results as three `start.sp` files.

**Setup.** Interface 2.0.0 against the reference `35c7390`, NewtonX 2.4 (build 06), TeraChem 1.96 beta. The gradient template was used as `tera.sp`. First 7 calls of each system. hh-TDA coupling jobs differ from the recorded ones by one keyword (`cistarget` is dropped), so they were run for real.

| System | Calls | Result |
|---|---|---|
| CASSCF | 7 | identical |
| TDA | 7 | identical |
| hh-TDA | 7 | first call: coupling sign flipped against the reference, \|h + h(reference)\| ≤ 5.2e-6 a.u.; later calls: max \|Δh\| = 7.6e-5 a.u. |

At the first step there is no previous coupling to fix the sign against, so either sign is valid. Later differences are at the level of SCF convergence.

**Conclusion.** The single template is equivalent to the three-template layout.

## 6. Couplings from jiri.inp

**Purpose.** Check that by default the interface computes the pairs NewtonX lists in `transmomin`.

**Setup.** Interface 2.0.0 against the reference `35c7390`, NewtonX 2.4 (build 06), TeraChem 1.96 beta. TDA and hh-TDA, 7 calls each, with no `jiri.inp`. NewtonX then lists every pair: S1–S0, S2–S0 and S2–S1. The reference computed only the neighbor pair, S2–S1.

| System | S2–S1 block vs reference | S1–S0, S2–S0 |
|---|---|---|
| TDA | identical | computed; max \|h\| = 0.43 a.u. |
| hh-TDA | identical | computed; max \|h\| = 0.57 a.u. |

**Conclusion.** The extra pairs are computed, and the pair both versions compute is unchanged.

## 7. CASSCF guess option

**Purpose.** With `use_prev_wf = 1`, 2.0.0 starts coupling jobs from the same step's gradient orbitals. Check that results do not change.

**Setup.** Interface 2.0.0 against the reference `35c7390`, NewtonX 2.4 (build 06), TeraChem 1.96 beta on one RTX 5000 Ada GPU per job. Ethylene CASSCF, 6 calls, real TeraChem runs for both versions. Each version had its own cache, so nothing was reused. The number of CPU cores and the node load were not recorded.

| | Reference `35c7390` | 2.0.0 |
|---|---|---|
| NewtonX files | – | identical |
| Coupling job time | 1.4–2.4 s | 1.2–1.3 s |

**Conclusion.** The results are the same, and the coupling jobs are faster; the saving grows with system size.

## 8. Triplets

**Purpose.** Check which methods give energies, gradients and couplings for a run in one multiplicity.

**Setup.** TeraChem 1.96 beta single points on ethylene with one multiplicity, run outside NewtonX. The interface 2.0.0 reads the triplet outputs in the unit tests ([section 13](#13-unit-tests)).

| Method | Energies | Gradient | Coupling | Note |
|---|---|---|---|---|
| FOMO-CASCI(4,4), 3 triplets | yes | yes | yes | Coupling jobs need `castargetmult 3`; without it TeraChem stops |
| hh-TDA, `cismult 3` | yes | yes | yes | Rows are labeled `triplet`; the interface selects them |
| TDA, `cismult 3` | – | no | no | TeraChem: "not implemented for triplets in restricted Kohn-Sham DFT" |

**Conclusion.** Triplet runs work with FOMO-CASCI and hh-TDA, and TeraChem cannot do them with TDA.

## 9. Full TDDFT (RPA)

**Purpose.** Check whether full TDDFT (`rpa yes`) gives usable gradients and coupling vectors.

**Setup.** TeraChem 1.96 beta single points, run outside NewtonX. Ethylene, B3LYP/6-31G*, `rpa yes`.

| Check | Result |
|---|---|
| Coupling run | Finishes normally (exit 0) but writes a coupling vector of zeros. TDA on the same geometry gives up to 0.048 a.u. |
| Gradient of state 2 | Analytic dE/dz = 0.006812, finite difference (±0.001 Bohr) = 0.006810; difference 1.8e-6 Hartree/Bohr |

RPA cannot give coupling vectors, so the interface refuses `rpa yes` with `vdoth = 0`. RPA gradients are correct, so RPA with TD-BA (`vdoth = 2`) is possible.

**Conclusion.** RPA is usable with TD-BA couplings only.

## 10. Initial conditions

**Purpose.** Check `run_tera_ic.pl` for every method, against the version used before 2.0.

**Setup.** `run_tera_ic.pl` of interface 2.0.0, called directly in the folder layout of `initcond.pl`, with the NewtonX 2.4 (build 06) libraries, TeraChem 1.96 beta. The reference is the `run_tera_ic.pl` that was installed in NewtonX 2.4 before 2.0; it was not part of the repository at `35c7390`. One uracil geometry per method, `nis = 1`, `nfs = 3`, real TeraChem. One ethylene CASSCF case with `nis = 2` and NewtonX's reference-geometry flag.

| Method | 2.0.0 | Script used before 2.0 |
|---|---|---|
| FOMO-CASCI | f(1→2) = 0.0384, f(1→3) = 0.2372 | identical energies and f |
| hh-TDA | f(1→2) = 0.00223677, f(1→3) = 0.78594484 | energies only; stopped: "Oscillator strength section not found" |
| TDA | f(1→2) = 0.0003, f(1→3) = 0.2278 | stopped: no energies, no oscillator strengths |
| CASSCF, `nis = 2` | f(2→3) = 0.3638 from TeraChem's table; `epot0.3` written | – |

Oscillator strengths computed from transition dipoles (used for `nis > 1` when TeraChem prints none) agree with TeraChem's printed values: 0.786 vs 0.78597 for hh-TDA, and 0.0137 within 5e-4 for FOMO 2→3. RPA was checked by a unit test with a real TeraChem RPA output.

**Conclusion.** 2.0.0 gives energies and oscillator strengths for every method, where the script used before 2.0 failed for hh-TDA and TDA.

## 11. NewtonX trajectories

**Purpose.** Check complete NewtonX runs with real TeraChem, without the replay harness.

**Setup.** Interface 2.0.0 against trajectories of the reference `35c7390`, NewtonX 2.4 (build 06), TeraChem 1.96 beta. dt = 0.5 fs, one GPU each.

| Run | Template | Couplings | Length | Result |
|---|---|---|---|---|
| Ethylene CASSCF | single `tera.sp` | NewtonX default (all 3 pairs) | 8 fs | Energies identical to the reference trajectory at 8 fs (to 1e-9 a.u.). No hop. |
| Uracil FOMO-CASCI | three `start.sp` | `jiri.inp` with `current = 1`: S2–S1 and S2–S0 | 5 fs | Energies identical to the reference trajectory at 5 fs (to 1e-9 a.u.). The S2–S0 pair was built from the coupling template. |
| Ethylene CASSCF | single `tera.sp` | TD-BA, `vdoth = 2` | 8 fs | Ran with one TeraChem job per step; one hop, S2 → S1. |
| Ethylene CASSCF | single `tera.sp` | `THRES = 1` eV | 8 fs | 2 nonadiabatic steps, then 15 adiabatic steps with the gradient job only and zero couplings. Worst energy deviation 0.17 mEh. |

Energy conservation over each run was the same as with the reference: worst deviation 1.0 mEh for the strained ethylene start, 0.3 mEh for uracil.

**Conclusion.** Full trajectories with 2.0.0 reproduce the reference energies and conserve energy as well as the reference.

## 12. Installer

**Purpose.** Check that `install/install_nx.pl` edits NewtonX correctly, can be run again, and leaves other programs alone.

**Setup.** `install_nx.pl` of interface 2.0.0 on two NewtonX 2.4 (build 06) trees: one with older hand-made TeraChem blocks and a QChem block, and one stock tree. TeraChem 1.96 beta for the NewtonX test. The number of CPU cores and the node load of the test run were not recorded.

| Check | Result |
|---|---|
| `--dry-run` | Lists all changes, writes nothing |
| Install on a NewtonX tree with older hand-made TeraChem blocks and a QChem block | Old TeraChem blocks replaced, QChem block kept, prog 21.0 resolves to the 2.0.0 scripts |
| Second install | `colib_perl.pm` identical to the first install |
| Install on stock NewtonX 2.4 | Four blocks added, file compiles |
| NewtonX test `MD-TERA-CASSCF-NAD-VEC` | Runs in about one minute; reference results stored |

**Conclusion.** The installer works on both trees, and a second run changes nothing.

## 13. Unit tests

**Purpose.** Check parsing and logic without a GPU.

**Setup.** `tests/unit.t` of interface 2.0.0, with NewtonX 2.4 (build 06) `colib_perl.pm`. The tests use the real TeraChem 1.96 beta outputs in `tests/fixtures/`, among them a triplet FOMO run, a triplet hh-TDA run and an RPA run.

| Groups | GPU needed | Result |
|---|---|---|
| 14 | no | all pass |

**Conclusion.** All 15 groups pass.

## 14. Example inputs

**Purpose.** Check that every input in `examples/` runs as published, and measure the time per step.

**Setup.** Interface 2.0.0 at commit `5c8b037`, installed in NewtonX 2.4 (build 06), TeraChem 1.96 beta. Twisted ethylene, 6-31G*, 3 singlets, starting on S1, 1 fs (2 steps). Neighbor couplings from `jiri.inp`. Each template was used unchanged as `JOB_NAD/tera.sp`. Each run had one NVIDIA RTX 5000 Ada GPU. The five runs started at the same time on the same node. The number of CPU cores per run was not recorded.

| Template | Couplings | Pairs per step | Result |
|---|---|---|---|
| `casscf` | NAC | S1–S0, S2–S1 | 2 steps, no warnings |
| `fomo-casci` | NAC | S1–S0, S2–S1 | 2 steps, no warnings |
| `tda` | NAC | S1–S0, S2–S1 | 2 steps, no warnings |
| `hh-tda` | NAC | S1–S0, S2–S1 | 2 steps, no warnings |
| `rpa-tdba` | TD-BA | none (NewtonX computes TD-BA) | 2 steps, no warnings |

The hh-TDA FOMO window was checked first. With `active 9`, the excitation energies were 6.5 and 7.9 eV, consistent with TDA (6.9 and 8.6 eV). With `active 8` TeraChem stopped, and with `active 10` the states came out wrong.

**Timing.** Wall time of each interface call, from the `Starting run-tera-cas.pl` and `Finished run-tera-cas.pl` lines in `moldyn.log`, to 1 s. NewtonX calls the interface three times in 1 fs: at 0, 0.5 and 1.0 fs. The first call of each run is slower than the later ones.

| Template | TeraChem runs per call | Call 1 | Call 2 | Call 3 | All 3 calls |
|---|---|---|---|---|---|
| `casscf` | 3 | 19 s | 13 s | 14 s | 46 s |
| `fomo-casci` | 3 | 15 s | 10 s | 10 s | 36 s |
| `tda` | 3 | 19 s | 13 s | 13 s | 46 s |
| `hh-tda` | 3 | 24 s | 17 s | 19 s | 61 s |
| `rpa-tdba` | 1 | 15 s | 13 s | 12 s | 41 s |

**Conclusion.** All five inputs run unchanged, at 10–19 s per step after the first call for ethylene on one GPU.

## 15. Phase reference after a gap

**Purpose.** Check [`phase_ref`](terachem-par.md#phase_ref). It decides how a coupling pair that was missing at the previous step gets its sign.

**Setup.** Interface 2.0.0, NewtonX 2.4 (build 06) programs, TeraChem 1.96 beta results from the recordings. `tests/harness/phase_gap_check.py` ran on all four recordings. For every first-run call and every pair present at the call and the step before, the pair was removed from the previous step. With `last`, the pair's vector from *g* steps earlier was given as the memory. The sign of the returning vector was compared with the recorded, gap-free trajectory. No GPU was needed; all TeraChem results came from the cache.

| System | Gap | `previous` | `last` (default) |
|---|---|---|---|
| CASSCF | 1 / 2 / 5 steps | 13/29, 12/28, 12/25 | 29/29, 28/28, 25/25 |
| TDA | 1 / 2 / 5 steps | 9/19, 8/18, 8/15 | 19/19, 18/18, 15/15 |
| hh-TDA | 1 / 2 / 5 steps | 9/15, 8/14, 7/11 | 15/15, 14/14, 11/11 |
| FOMO-CASCI | 1 / 2 / 5 steps | 27/45, 25/43, 21/37 | 45/45, 43/43, 35/37 |

- **`previous` is a coin flip:** a returning pair gets the right sign in 159 of 299 cases, 53%, because TeraChem's raw sign is arbitrary from run to run.
- **`last` keeps signs continuous:** it agrees in 297 of 299 cases. The two misses were FOMO pairs after a 2.5 fs gap, where the vector had rotated by more than 90 degrees.
- **No effect without gaps:** with `last`, the 101 recorded calls give byte-identical NewtonX files to the reference, `oldh` included. They contain no pair that returns after a gap.
- **Default:** because of these results, `last` is the default.

**Conclusion.** `phase_ref = last` gives the right sign in 297 of 299 returning pairs, against 159 of 299 for `previous`.

## 16. NewtonX 2.6

**Purpose.** Check the installer, dynamics, TD-BA, restarts, initial conditions and coupling signs under NewtonX 2.6.

**Setup.** Interface 2.0.0 on branch `interface-improvements`, with its NewtonX 2.6 support. A copy of NewtonX 2.6 (build 01) with the interface installed by `install_nx.pl`. TeraChem 1.96 beta. Ethylene CASSCF, real TeraChem, one GPU.

| Check | Result |
|---|---|
| Installer | Four blocks added; the edited `colib_perl.pm` compiles; a second run changes nothing |
| NewtonX test `MD-TERA-CASSCF-NAD-VEC` | Every state and energy line equal to the NewtonX 2.4 reference |
| TD-BA, `vdoth = 2` | Runs; energies equal to the coupling-vector run |
| Restart from `INFO_RESTART/control.dyn` | Energies equal to a continuous run |
| Initial conditions, uracil TDA, `initcond.pl` | Energies and oscillator strengths written |

**Signs.** NewtonX 2.6 corrects the coupling signs again by extrapolation (`getphase = 1`). Gaps were made by forcing adiabatic steps. Signs were checked on the vectors NewtonX 2.6 keeps.

| Case | NewtonX 2.6 on its own | With the interface setting its reference |
|---|---|---|
| One-step gap, `phase_ref = last` | 3 of 3 returning pairs flipped against their last vector | 3 of 3 kept |
| Two- and three-step gaps | kept | kept |
| Whole run with gaps vs the run without gaps | signs differ for pairs after a gap | identical signs for every pair and step |
| Coupling shrinking 10 → 3 → 1, same direction, run through `phase_correction` | flipped | – |

The last row is why the interface overrides NewtonX 2.6's own correction. The extrapolation flips a coupling that shrinks by more than half per step, as after the spike at a crossing. A separate NewtonX 2.6 run of another interface saw this near a hop. The cost is that a coupling passing smoothly through zero keeps its sign, as with NewtonX 2.4. In the ethylene run, NewtonX 2.6 alone had flipped two such pairs, at steps 14 and 16.

The NewtonX 2.4 replays (sections 1–7 and 15) give the same results with the NewtonX 2.6 support in place.

**Conclusion.** Under NewtonX 2.6 the interface runs as under 2.4, and the coupling signs are identical with and without gaps.

## 17. TeraChem behavior

**Purpose.** Record the facts about TeraChem 1.96 that the interface depends on.

**Setup.** TeraChem 1.96 beta (build 2024-11-09). Each fact was checked with a small TeraChem test job.

| Behavior | Observed | Consequence for the interface |
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

**Conclusion.** The interface relies on these 10 behaviors, and each one was observed in TeraChem 1.96 beta.

## See also

- [Development and testing](development.md): the replay harness and how to repeat these tests
- [Method tutorials](methods.md): what each method needs, with one typical cost figure each
- [Changelog](../CHANGELOG.md): what changed in 2.0.0
