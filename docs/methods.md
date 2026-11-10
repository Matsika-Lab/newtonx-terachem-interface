[← README](../README.md)

# Method tutorials

This page shows how to run NewtonX dynamics with each TeraChem method. Each section has the same shape: when to use the method, its keywords, the couplings it allows, the multiplicity rules, `terachem.par` settings, a template and pitfalls.

The templates in [`examples/`](../examples) are for twisted ethylene with 6-31G* and three singlet states. Each one completed a 1 fs NewtonX trajectory with this interface (see [validation.md](validation.md#14-example-templates)). For your molecule, change the basis, active space and number of states.

## Overview

| Method | Gradients | NAC vectors (`vdoth = 0`) | TD-BA (`vdoth = 2`) | Triplets | Template |
|---|---|---|---|---|---|
| [CASSCF](#casscf) | yes | yes | yes | yes, untested | [`examples/casscf`](../examples/casscf/tera.sp) |
| [FOMO-CASCI](#fomo-casci) | yes | yes | yes | yes | [`examples/fomo-casci`](../examples/fomo-casci/tera.sp) |
| [TDA (TDDFT)](#tda-tddft) | yes | yes | yes | no | [`examples/tda`](../examples/tda/tera.sp) |
| [hh-TDA](#hh-tda) | yes | yes | yes | yes | [`examples/hh-tda`](../examples/hh-tda/tera.sp) |
| [Full TDDFT (RPA)](#full-tddft-rpa) | yes | **no** | yes | no | [`examples/rpa-tdba`](../examples/rpa-tdba/tera.sp) |

Every template is a single `JOB_NAD/tera.sp`. Leave out `run`, `castarget`, `cistarget`, `nacstate1`, `nacstate2`, `coordinates` and `scrdir`; the interface sets them at each step (see [Keywords the interface manages](dynamics.md#keywords-the-interface-manages)).

## Couplings: NAC and TD-BA

Surface hopping integrates the electronic amplitudes $`c_k`$ along the trajectory:

```math
i\hbar\,\frac{dc_k}{dt} = c_k E_k - i\hbar \sum_j c_j\,\sigma_{kj}
```

The time-derivative coupling $`\sigma_{kj}`$ drives population transfer and hops between states $`k`$ and $`j`$. NewtonX can get it in two ways with this interface. Set the choice with `vdoth` in `sh.inp`.

### Nonadiabatic coupling vectors (NAC, `vdoth = 0`)

The nonadiabatic coupling vector between states $`i`$ and $`j`$ is

```math
\mathbf{h}_{ij} = \langle \psi_i \,|\, \nabla_{\mathbf{R}}\, \psi_j \rangle
```

in 1/Bohr, one 3-vector per atom. The time-derivative coupling follows from the nuclear velocity $`\mathbf{v}`$:

```math
\sigma_{ij} = \langle \psi_i \,|\, \partial_t \psi_j \rangle = \mathbf{v}\cdot\mathbf{h}_{ij}
```

- **Source:** TeraChem computes $`\mathbf{h}_{ij}`$ analytically, one pair per run (`run coupling`).
- **Cost:** one gradient run plus one run per pair at each step. NewtonX chooses the pairs; see [Which couplings are computed](dynamics.md#which-couplings-are-computed).
- **Phase:** the sign of each vector is made continuous from step to step by NewtonX's phase fix. For a pair that returns after a gap, see [`phase_ref`](terachem-par.md#phase_ref).
- **Methods:** CASSCF, FOMO-CASCI, TDA and hh-TDA.

### Time-dependent Baeck-An couplings (TD-BA, `vdoth = 2`)

TD-BA estimates $`\sigma_{ij}`$ from the energy gap $`\Delta E_{ij} = E_i - E_j`$ along the trajectory alone:

```math
\sigma_{ij} \approx \operatorname{sign}(\Delta E_{ij})\,\frac{1}{2}\sqrt{\frac{1}{\Delta E_{ij}}\,\frac{d^2 \Delta E_{ij}}{dt^2}}
```

- **Source:** NewtonX computes it after each step from the energies of the last few steps. The second derivative comes from a quadratic fit.
- **Zero couplings:** the coupling is set to zero when the expression under the root is negative, when $`|\Delta E_{ij}|`$ is larger than `BA_DE`, or when $`|\Delta E_{ij}\,\ddot{\Delta E}_{ij}|`$ is larger than `BA_DV`. These settings live in NewtonX's `auxnac.inp`; see the NewtonX manual, section 12.1.7.
- **Cost:** one TeraChem run per step, the gradient only.
- **Accuracy:** it is an approximation, and it gives no coupling direction. Reference: do Casal, Toldo, Pinheiro Jr and Barbatti, *Open Res. Europe* **2021**, 1, 49.
- **Methods:** every method above, including full TDDFT.

Overlap-based couplings (`vdoth = 1` or negative) are not supported, because TeraChem does not provide the wavefunction overlaps NewtonX needs.

## CASSCF

**When to use it**
- **Multireference states:** for bond breaking, conical intersections with the ground state, and small active spaces you can choose by hand.
- **Size limit:** it is affordable for small molecules or small active spaces. Each step re-optimizes the orbitals.

**TeraChem keywords**

| Keyword | Example value | Meaning |
|---|---|---|
| `method` | `rhf` | Reference for the orbitals |
| `casscf` | `yes` | State-averaged CASSCF |
| `closed` | `7` | Doubly occupied inactive orbitals |
| `active` | `2` | Active orbitals; the active electrons follow from the charge |
| `cassinglets` | `3` | States averaged and computed; at least `nstat` |
| `castargetmult` | `1` | Multiplicity of the dynamics states |
| `casscfmaxiter` | `200` | CASSCF iteration limit |

**Couplings allowed:** [NAC](#nonadiabatic-coupling-vectors-nac-vdoth--0) and [TD-BA](#time-dependent-baeck-an-couplings-td-ba-vdoth--2).

**Singlets and triplets:** set `castargetmult 3` and `castriplets` (with `cassinglets 0`) for a triplet run. Coupling jobs need `castargetmult 3` too.

**terachem.par**
- **[`use_prev_wf`](terachem-par.md#use_prev_wf) = 1:** start each step from the previous orbitals. It is faster, and it keeps the active space continuous.
- **[`archive_wf`](terachem-par.md#archive_wf):** keep it at 1 if you want the orbitals of every step.

**Template:** [`examples/casscf/tera.sp`](../examples/casscf/tera.sp)

**Pitfalls**
- **Active space:** the active orbitals can rotate out of the space between steps. Check the archived Molden files, and use `use_prev_wf = 1`.
- **First step:** a poor first guess can converge to the wrong active space. With `use_prev_wf = 1`, give a tested first guess as `JOB_NAD/c0.casscf`.

## FOMO-CASCI

**When to use it**
- **Large systems:** a cheaper multireference method. Floating occupations give smooth orbitals, so no CASSCF optimization is needed.

**TeraChem keywords**

| Keyword | Example value | Meaning |
|---|---|---|
| `method` | `rhf` | Reference |
| `fon` | `yes` | Fractional occupation (FOMO) SCF |
| `fon_method` | `gaussian` | Smearing function |
| `fon_temperature` | `0.2` | Smearing width kT (Hartree) |
| `casci` | `yes` | CASCI on the FOMO orbitals |
| `closed`, `active` | `6`, `4` | CAS space |
| `cassinglets` | `3` | States; at least `nstat` |
| `castargetmult` | `1` | Multiplicity of the dynamics states |

**Couplings allowed:** NAC and TD-BA.

**Singlets and triplets:** as for CASSCF, with `castargetmult` and `castriplets`.

**terachem.par**
- **[`use_prev_scf_wf`](terachem-par.md#use_prev_scf_wf) = 1:** optional. It starts the FON-SCF from the previous step's orbitals, and the SCF still converges.

**Template:** [`examples/fomo-casci/tera.sp`](../examples/fomo-casci/tera.sp)

**Pitfalls**
- **Do not skip the FON-SCF:** `use_prev_wf` is for CASSCF only, and the interface ignores it for FOMO.
- **Smearing width:** `fon_temperature` changes the orbitals, and with them the energies. Keep it fixed within one study.

## TDA (TDDFT)

**When to use it**
- **Single-reference states:** excited states of molecules with a well-behaved closed-shell ground state.
- **Not for S1/S0 crossings:** linear-response TDDFT describes the S1/S0 intersection poorly. Restrict couplings to excited states with `never_state = 1` in `jiri.inp` if needed.

**TeraChem keywords**

| Keyword | Example value | Meaning |
|---|---|---|
| `method` | `camb3lyp` | Functional |
| `cis` | `yes` | TDDFT in the Tamm-Dancoff approximation |
| `cisnumstates` | `4` | Excited states computed; at least `nstat − 1`, a few more helps convergence |
| `cisguessvecs`, `cismaxiter` | `12`, `500` | Davidson settings |

**Couplings allowed:** NAC and TD-BA.

**Singlets and triplets:** singlets only. TeraChem has no triplet gradients for restricted TDDFT.

**terachem.par**
- **[`use_prev_scf_wf`](terachem-par.md#use_prev_scf_wf) = 1:** optional. It helps when the SCF needs many iterations.

**Template:** [`examples/tda/tera.sp`](../examples/tda/tera.sp)

**Pitfalls**
- **State 1 is S0:** the ground state is the DFT reference, and state *k* is the (*k* − 1)th excited state.

## hh-TDA

**When to use it**
- **TDDFT-like cost with a correct S1/S0 intersection:** hole-hole TDA builds the ground and excited states together from an (N+2)-electron reference.

**TeraChem keywords**

| Keyword | Example value | Meaning |
|---|---|---|
| `method` | `bhandhlyp` | Functional |
| `fon`, `fon_method` | `yes`, `constant` | FOMO reference |
| `closed`, `active` | `0`, `9` | FOMO window; here all occupied orbitals of the (N+2)-electron reference, (N+2)/2 = 9 for ethylene |
| `hhtda` | `yes` | Hole-hole TDA |
| `hhtdasinglets` | `3` | Singlet states, ground state included; at least `nstat` |
| `cisnumstates` | `3` | Davidson roots |
| `cisalgorithm`, `cisguessvecs`, `cismaxiter`, `cisconvtol` | `davidson`, `10`, `1000`, `1e-6` | Solver settings |

**Couplings allowed:** NAC and TD-BA.

**Singlets and triplets:** set `cismult 3` and `hhtdatriplets` for a triplet run.

**terachem.par**
- **[`use_prev_scf_wf`](terachem-par.md#use_prev_scf_wf) = 1:** optional.

**Template:** [`examples/hh-tda/tera.sp`](../examples/hh-tda/tera.sp)

**Pitfalls**
- **FOMO window:** too few active orbitals stops TeraChem, and too many smear the occupations and give wrong energies. Check the ground-state energy against a plain DFT run.
- **Energy jumps:** near-degenerate FOMO solutions can switch between steps. `use_prev_scf_wf` does not prevent this.
- **Misleading output line:** TeraChem's `FINAL Target State Energy` line shows the wrong root for hh-TDA. The gradient itself is for the right state; see [validation.md](validation.md#terachem-behaviour).

## Full TDDFT (RPA)

**When to use it**
- **Full TDDFT instead of TDA:** for example to compare with TDA, with TD-BA couplings only.

**TeraChem keywords**

| Keyword | Example value | Meaning |
|---|---|---|
| `method` | `camb3lyp` | Functional |
| `rpa` | `yes` | Full TDDFT; do not also set `cis yes` |
| `cisnumstates` | `4` | Excited states; at least `nstat − 1` |

**Couplings allowed:** TD-BA only. Set `vdoth = 2` in `sh.inp`, as in [`examples/rpa-tdba/sh.inp`](../examples/rpa-tdba/sh.inp).

**Singlets and triplets:** singlets only.

**terachem.par**
- **[`use_prev_scf_wf`](terachem-par.md#use_prev_scf_wf) = 1:** optional.

**Template:** [`examples/rpa-tdba/tera.sp`](../examples/rpa-tdba/tera.sp)

**Pitfalls**
- **No coupling vectors:** TeraChem finishes RPA coupling runs normally but writes zero vectors. The interface therefore stops if `vdoth = 0`.
