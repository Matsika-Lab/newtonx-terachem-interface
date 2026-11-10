[Home](../README.md) / Method tutorials

# Method tutorials

This page shows how to run NewtonX dynamics with each TeraChem method, and explains the three kinds of couplings the interface offers: coupling vectors from TeraChem, time-derivative couplings from wavefunction overlaps, and time-dependent Baeck-An (TD-BA) couplings from NewtonX. Read the section of your method before you write its template. Every method section has the same parts: when to use it, keywords, couplings allowed, template, settings, pitfalls and cost.

The inputs in [`examples/`](../examples/README.md) are for twisted ethylene with 6-31G* and three singlet states. Each one completed a 1 fs NewtonX trajectory with this interface; see [Validation](validation.md#14-example-inputs). For your molecule, change the basis, active space and number of states.

## Methods at a glance

| Method | Gradients | Coupling vectors (`vdoth = 0`) | Overlap couplings (`vdoth = 1`) | TD-BA couplings (`vdoth = 2`) | Triplets | Template |
|---|---|---|---|---|---|---|
| [CASSCF](#casscf) | yes | yes | yes | yes | yes, untested | [`examples/casscf`](../examples/casscf/JOB_NAD/tera.sp) |
| [FOMO-CASCI](#fomo-casci) | yes | yes | yes | yes | yes | [`examples/fomo-casci`](../examples/fomo-casci/JOB_NAD/tera.sp) |
| [TDA (TDDFT)](#tda-tddft) | yes | yes | **no** | yes | no | [`examples/tda`](../examples/tda/JOB_NAD/tera.sp) |
| [hh-TDA](#hh-tda) | yes | yes | **no** | yes | yes | [`examples/hh-tda`](../examples/hh-tda/JOB_NAD/tera.sp) |
| [Full TDDFT (RPA)](#full-tddft-rpa) | yes | **no** | **no** | yes | no | [`examples/rpa-tdba`](../examples/rpa-tdba/JOB_NAD/tera.sp) |

Every template is a single `JOB_NAD/tera.sp`. Leave out `run`, `castarget`, `cistarget`, `nacstate1`, `nacstate2`, `coordinates` and `scrdir`; the interface sets them at each step. See [Keywords the interface manages](dynamics.md#keywords-the-interface-manages).

## Coupling vectors, overlap couplings and TD-BA couplings

Surface hopping integrates the electronic amplitudes $`c_k`$ along the trajectory:

```math
i\hbar\,\frac{dc_k}{dt} = c_k E_k - i\hbar \sum_j c_j\,\sigma_{kj}
```

The time-derivative coupling $`\sigma_{kj}`$ drives population transfer and hops between states $`k`$ and $`j`$. NewtonX can get it in three ways with this interface. Set the choice with `vdoth` in `sh.inp`.

### Coupling vectors (`vdoth = 0`)

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
- **Phase:** the sign of each vector is made continuous from step to step by NewtonX's phase correction, which the interface runs with NewtonX 2.4 and 2.6 alike. For a pair that returns after a gap, see [`phase_ref`](terachem-par.md#phase_ref). NewtonX 2.6 adds a second correction of its own; see [NewtonX 2.6](terachem-par.md#newtonx-26).
- **Methods:** CASSCF, FOMO-CASCI, TDA and hh-TDA.

### Time-derivative couplings from overlaps (`vdoth = 1`)

The coupling is computed from the overlap of the CAS wavefunctions of two consecutive steps. NewtonX's own `read_cioverlap.pl` uses the Hammes-Schiffer–Tully finite difference

```math
\sigma_{mn}(t-\tfrac{dt}{2}) \approx \frac{S_{mn} - S_{nm}}{2\,dt}, \qquad S_{mn} = \langle \psi_m(t-dt) \,|\, \psi_n(t) \rangle
```

and extrapolates it to $`t`$. At the first step and after a hop it uses NewtonX's own CD approximation instead.

- **Source:** the interface runs only the gradient job at each step, with `cassavevectors yes` added. It then runs one TeraChem job, `run ci_vec_overlap`, in `TEMP/ovl/`, between the previous step's and this step's CAS wavefunction. TeraChem 1.96 computes overlaps only for CAS wavefunctions.
- **Wavefunction:** the orbitals are `c0.casscf` for CASSCF and `c0` otherwise. The CI vectors are `GRAD/scr.geom/CI_<mult>_<k>.dat` for `k` = 1 to `nstat`. The previous step's wavefunction is kept in `INFO_RESTART/WF_OLD/tdc_orb`, `tdc_civ` and `tdc_geom.xyz`.
- **Signs:** the interface flips a state when its overlap with itself would be negative, so the state signs stay continuous. The flips are carried from step to step in `INFO_RESTART/WF_OLD/tdc_phase`. NewtonX 2.6's `phase_correction` is shielded as for coupling vectors; see [NewtonX 2.6](terachem-par.md#newtonx-26). On NewtonX 2.6 (build 01) all phase factors were +1, and the couplings equal those of NewtonX 2.4 to 10⁻⁸ over 10 fs of uracil.
- **First step:** step 0 has no previous wavefunction, so its couplings are zero.
- **Adiabatic steps and hops:** the overlap job runs at every step, including adiabatic steps. In NewtonX's second call after a hop, nothing is recomputed.
- **Momentum after a hop:** set `adjmom = -1` in `sh.inp`, or leave `adjmom` out; NewtonX's default with `vdoth = 1` is −1. Time-derivative couplings give no coupling vector, so after a hop the momentum is rescaled along the velocity, as the NewtonX manual states for time-derivative couplings. With `adjmom` of 0 or more the run stops before the first step with "cannot be used with vdoth = 1". This differs from `vdoth = 0`, where the default `adjmom = 0` rescales along the coupling vector, so the two coupling types can follow different paths after a hop; see [Validation](validation.md#18-time-derivative-couplings-from-overlaps).
- **Output:** the overlap matrix goes to `run_cioverlap.log`. The couplings go to `nad_vectors`. Each step appends the raw overlap matrix, the signs and the couplings to `DEBUG/tdc_overlaps.log`.
- **Cost:** one gradient run plus one overlap run at each step, instead of one run per coupling pair. See [Validation](validation.md#18-time-derivative-couplings-from-overlaps).
- **Methods:** CASSCF and FOMO-CASCI. The interface stops with "vdoth = 1 needs a CAS method" for TDA, hh-TDA and RPA, because TeraChem refuses overlaps for them ("Ci Vector overlaps only work with CAS methods!").
- **Settings:** the `couplings` and `phase_ref` keys of `terachem.par` have no effect with `vdoth = 1`.
- **Checked on:** NewtonX 2.4 and 2.6.

### Time-dependent Baeck-An couplings (TD-BA, `vdoth = 2`)

TD-BA estimates $`\sigma_{ij}`$ from the energy gap $`\Delta E_{ij} = E_i - E_j`$ along the trajectory alone:

```math
\sigma_{ij} \approx \mathrm{sign}(\Delta E_{ij})\,\frac{1}{2}\sqrt{\frac{1}{\Delta E_{ij}}\,\frac{d^2 \Delta E_{ij}}{dt^2}}
```

- **Source:** NewtonX computes it after each step from the energies of the last few steps. The second derivative comes from a quadratic fit.
- **Zero couplings:** the coupling is set to zero when the expression under the root is negative, when $`|\Delta E_{ij}|`$ is larger than `BA_DE`, or when $`|\Delta E_{ij}\,\ddot{\Delta E}_{ij}|`$ is larger than `BA_DV`. These settings live in NewtonX's `auxnac.inp`; see the NewtonX manual, section 12.1.7.
- **Cost:** one TeraChem run per step, the gradient only.
- **Accuracy:** it is an approximation, and it gives no coupling direction. Reference: do Casal, Toldo, Pinheiro Jr and Barbatti, *Open Res. Europe* **2021**, 1, 49.
- **Methods:** every method on this page, including full TDDFT.

`vdoth` below 0 (local diabatization) is not supported.

## CASSCF

### When to use it

> Multireference states: bond breaking, conical intersections with the ground state, and small active spaces you can choose by hand. It is affordable for small molecules or small active spaces, because each step re-optimizes the orbitals.
>
> Couplings: coupling vectors, overlap couplings and TD-BA couplings.

### Keywords

| Keyword | Example value | Meaning |
|---|---|---|
| `method` | `rhf` | Reference for the orbitals |
| `casscf` | `yes` | State-averaged CASSCF |
| `closed` | `7` | Doubly occupied inactive orbitals |
| `active` | `2` | Active orbitals; the active electrons follow from the charge |
| `cassinglets` | `3` | States averaged and computed; at least `nstat` |
| `castargetmult` | `1` | Multiplicity of the dynamics states |
| `casscfmaxiter` | `200` | CASSCF iteration limit |

**Singlets and triplets:** for a triplet run, set `castargetmult 3` and `castriplets`, with `cassinglets 0`. Coupling jobs need `castargetmult 3` too. Triplet CASSCF dynamics is untested.

### Couplings allowed

[Coupling vectors](#coupling-vectors-vdoth--0), [time-derivative couplings from overlaps](#time-derivative-couplings-from-overlaps-vdoth--1) and [TD-BA](#time-dependent-baeck-an-couplings-td-ba-vdoth--2).

### Template

```text
basis           6-31g*
method          rhf
casscf          yes
closed          7
active          2
cassinglets     3
castargetmult   1
casscfmaxiter   200
precision       double
convthre        1e-8
```

Full file: [`examples/casscf/JOB_NAD/tera.sp`](../examples/casscf/JOB_NAD/tera.sp).

### Settings

- **[`use_prev_wf`](terachem-par.md#use_prev_wf) = 1:** start each step from the previous orbitals. It is faster, and it keeps the active space continuous. The default is `0`.
- **[`archive_wf`](terachem-par.md#archive_wf):** keep it at `1`, the default, if you want the orbitals of every step.

### Pitfalls

- **Active space:** the active orbitals can rotate out of the space between steps. Check the archived Molden files, and use `use_prev_wf = 1`.
- **First step:** a poor first guess can converge to the wrong active space. With `use_prev_wf = 1`, give a tested first guess as `JOB_NAD/c0.casscf`.

### Cost

About 13–14 s per step for ethylene SA-3-CASSCF(2,2)/6-31G* with two coupling pairs, on one GPU ([Validation](validation.md#14-example-inputs)).

## FOMO-CASCI

### When to use it

> Large systems: a cheaper multireference method. Floating occupations give smooth orbitals, so no CASSCF optimization is needed.
>
> Couplings: coupling vectors, overlap couplings and TD-BA couplings.

### Keywords

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

**Singlets and triplets:** as for CASSCF, with `castargetmult` and `castriplets`. Triplets were tested with FOMO-CASCI(4,4); see [Validation](validation.md#8-triplets).

### Couplings allowed

[Coupling vectors](#coupling-vectors-vdoth--0), [time-derivative couplings from overlaps](#time-derivative-couplings-from-overlaps-vdoth--1) and [TD-BA](#time-dependent-baeck-an-couplings-td-ba-vdoth--2).

### Template

```text
basis           6-31g*
method          rhf
fon             yes
fon_method      gaussian
fon_temperature 0.2
casci           yes
closed          6
active          4
cassinglets     3
castargetmult   1
```

Full file: [`examples/fomo-casci/JOB_NAD/tera.sp`](../examples/fomo-casci/JOB_NAD/tera.sp).

### Settings

- **[`use_prev_scf_wf`](terachem-par.md#use_prev_scf_wf) = 1:** optional; the default is `0`. It starts the FON-SCF from the previous step's orbitals, and the SCF still converges.

### Pitfalls

- **Do not skip the FON-SCF:** `use_prev_wf` is for CASSCF only, and the interface ignores it for FOMO.
- **Overlap warning:** with `vdoth = 1`, the interface warns when a state overlaps less than 0.5 with itself at the previous step. In uracil FOMO-CASCI(14,10) this happened when the last closed and first active orbitals came close in energy; all three diagonals fell to 0.35–0.69 for two steps. Check the states around that step, and consider a smaller time step.
- **Smearing width:** `fon_temperature` changes the orbitals, and with them the energies. Keep it fixed within one study.

### Cost

About 10 s per step for ethylene FOMO-CASCI(4,4)/6-31G* with two coupling pairs, on one GPU ([Validation](validation.md#14-example-inputs)).

## TDA (TDDFT)

### When to use it

> Single-reference states: excited states of molecules with a well-behaved closed-shell ground state. It is not for S1/S0 crossings, because linear-response TDDFT describes the S1/S0 intersection poorly. If needed, restrict couplings to excited states with `never_state = 1` in `jiri.inp`.
>
> Couplings: coupling vectors and TD-BA couplings.

### Keywords

| Keyword | Example value | Meaning |
|---|---|---|
| `method` | `camb3lyp` | Functional |
| `cis` | `yes` | TDDFT in the Tamm-Dancoff approximation |
| `cisnumstates` | `4` | Excited states computed; at least `nstat − 1`, a few more helps convergence |
| `cisguessvecs`, `cismaxiter` | `12`, `500` | Davidson settings |

**Singlets and triplets:** singlets only. TeraChem has no triplet gradients for restricted TDDFT.

### Couplings allowed

Both coupling vectors and TD-BA couplings. `vdoth = 1` is refused, because TeraChem computes overlaps only for CAS wavefunctions.

### Template

```text
basis           6-31g*
method          camb3lyp
cis             yes
cisnumstates    4
cisguessvecs    12
cismaxiter      500
```

Full file: [`examples/tda/JOB_NAD/tera.sp`](../examples/tda/JOB_NAD/tera.sp).

### Settings

- **[`use_prev_scf_wf`](terachem-par.md#use_prev_scf_wf) = 1:** optional; the default is `0`. It helps when the SCF needs many iterations.

### Pitfalls

- **State 1 is S0:** the ground state is the DFT reference, and state *k* is the (*k* − 1)th excited state.

### Cost

About 13 s per step for ethylene TDA CAM-B3LYP/6-31G* with two coupling pairs, on one GPU ([Validation](validation.md#14-example-inputs)).

## hh-TDA

### When to use it

> TDDFT-like cost with a correct S1/S0 intersection: hole-hole TDA builds the ground and excited states together from an (N+2)-electron reference.
>
> Couplings: coupling vectors and TD-BA couplings.

### Keywords

| Keyword | Example value | Meaning |
|---|---|---|
| `method` | `bhandhlyp` | Functional |
| `fon`, `fon_method` | `yes`, `constant` | FOMO reference |
| `closed`, `active` | `0`, `9` | FOMO window; here all occupied orbitals of the (N+2)-electron reference, (N+2)/2 = 9 for ethylene |
| `hhtda` | `yes` | Hole-hole TDA |
| `hhtdasinglets` | `3` | Singlet states, ground state included; at least `nstat` |
| `cisnumstates` | `3` | Davidson roots |
| `cisalgorithm`, `cisguessvecs`, `cismaxiter`, `cisconvtol` | `davidson`, `10`, `1000`, `1e-6` | Solver settings |

**Singlets and triplets:** for a triplet run, set `cismult 3` and `hhtdatriplets`.

### Couplings allowed

Both coupling vectors and TD-BA couplings. `vdoth = 1` is refused, because TeraChem computes overlaps only for CAS wavefunctions.

### Template

```text
basis           6-31g*
method          bhandhlyp
fon             yes
fon_method      constant
closed          0
active          9
hhtda           yes
hhtdasinglets   3
cisnumstates    3
cisalgorithm    davidson
cisguessvecs    10
cismaxiter      1000
cisconvtol      1.0e-6
```

Full file: [`examples/hh-tda/JOB_NAD/tera.sp`](../examples/hh-tda/JOB_NAD/tera.sp).

### Settings

- **[`use_prev_scf_wf`](terachem-par.md#use_prev_scf_wf) = 1:** optional; the default is `0`.

### Pitfalls

- **FOMO window:** too few active orbitals stops TeraChem, and too many smear the occupations and give wrong energies. Check the ground-state energy against a plain DFT run.
- **Energy jumps:** near-degenerate FOMO solutions can switch between steps. `use_prev_scf_wf` does not prevent this.
- **Misleading output line:** TeraChem's `FINAL Target State Energy` line shows the wrong root for hh-TDA. The gradient itself is for the right state; see [Validation](validation.md#17-terachem-behavior).

### Cost

About 17–19 s per step for ethylene hh-TDA BH&HLYP/6-31G* with two coupling pairs, on one GPU ([Validation](validation.md#14-example-inputs)).

## Full TDDFT (RPA)

### When to use it

> Full TDDFT instead of TDA, for example to compare with TDA.
>
> Couplings: TD-BA only.

### Keywords

| Keyword | Example value | Meaning |
|---|---|---|
| `method` | `camb3lyp` | Functional |
| `rpa` | `yes` | Full TDDFT; do not also set `cis yes` |
| `cisnumstates` | `4` | Excited states; at least `nstat − 1` |

**Singlets and triplets:** singlets only.

### Couplings allowed

TD-BA only. `vdoth = 0` and `vdoth = 1` are refused. Set `vdoth = 2` in `sh.inp`, as in [`examples/rpa-tdba/sh.inp`](../examples/rpa-tdba/sh.inp).

### Template

```text
basis           6-31g*
method          camb3lyp
rpa             yes
cisnumstates    4
cisguessvecs    12
cismaxiter      500
```

Full file: [`examples/rpa-tdba/JOB_NAD/tera.sp`](../examples/rpa-tdba/JOB_NAD/tera.sp).

### Settings

- **[`use_prev_scf_wf`](terachem-par.md#use_prev_scf_wf) = 1:** optional; the default is `0`.

### Pitfalls

- **No coupling vectors:** TeraChem finishes RPA coupling runs normally but writes zero vectors. The interface therefore stops if `vdoth = 0`.

### Cost

About 12–13 s per step for ethylene RPA CAM-B3LYP/6-31G* with TD-BA, one TeraChem run per step, on one GPU ([Validation](validation.md#14-example-inputs)).

## See also

- [Running dynamics](dynamics.md): templates, managed keywords and coupling pairs
- [terachem.par reference](terachem-par.md): every setting and its default
- [Examples](../examples/README.md): one complete, tested input per method
