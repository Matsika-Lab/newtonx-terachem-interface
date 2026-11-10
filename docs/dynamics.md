[Home](../README.md) / Running dynamics

# Running dynamics

This page explains how to set up a trajectory folder, how the interface turns one template into TeraChem jobs, which couplings it computes, and what happens on adiabatic steps and after a hop. Read it after [Your first trajectory](first-trajectory.md), when you set up your own molecule.

## Setup checklist

1. Install the interface. See [Installation](installation.md).
2. Set `prog = 21.0` in `control.dyn`.
3. Copy the template for your method from [`examples/`](../examples/README.md) to `JOB_NAD/tera.sp` and adapt it. See [Method tutorials](methods.md) and [Templates](#templates).
4. Set `vdoth` in `sh.inp`: `0` for coupling vectors or `2` for TD-BA. If `sh.inp` has no `vdoth`, NewtonX uses 2. See [Coupling methods](#coupling-methods).
5. Choose the couplings with `jiri.inp`. See [Which couplings are computed](#which-couplings-are-computed).
6. Optionally, add `terachem.par`. See [terachem.par reference](terachem-par.md).
7. Give the trajectory one GPU and run NewtonX:

   ```bash
   export CUDA_VISIBLE_DEVICES=0
   $NX/moldyn.pl > moldyn.log
   ```

Each trajectory uses one GPU. The TeraChem jobs of a step run one after another. The NewtonX keywords in `control.dyn`, `sh.inp` and `jiri.inp`, and their defaults, are explained in the NewtonX manual.

A trajectory folder looks like this:

```text
TRAJ1/
├── control.dyn      # prog = 21.0
├── sh.inp           # vdoth = 0 (coupling vectors) or 2 (TD-BA)
├── jiri.inp         # which couplings NewtonX asks for
├── terachem.par     # optional interface settings
├── geom             # initial geometry (Bohr)
├── veloc            # initial velocities (a.u.)
└── JOB_NAD/
    └── tera.sp      # TeraChem template
```

> [!WARNING]
> On adiabatic steps and with TD-BA, NewtonX takes the template from `JOB_AD/`, not `JOB_NAD/`. If the trajectory folder has no `JOB_AD/`, NewtonX makes one as a copy of `JOB_NAD/` when the run starts. Do not keep an old `JOB_AD/` next to `JOB_NAD/`, or it will be used for those steps.

## Templates

### Single template

The single template is the recommended layout.

```text
JOB_NAD/
└── tera.sp
```

`tera.sp` is an ordinary TeraChem input that describes the method, basis, active space and so on. The interface writes the gradient input and every coupling input from it at each step. Leave out the keywords in the [table below](#keywords-the-interface-manages); the interface sets them. `guess` is the exception: the interface changes it only when a guess setting is on.

Example, FOMO-CASCI:

```text
basis           cc-pvdz
method          rhf
fon             yes
fon_method      gaussian
fon_temperature 0.2
casci           yes
closed          22
active          10
cassinglets     3
charge          0
spinmult        1
gpus            1
coordinates     geom.xyz
```

### Three templates

```text
JOB_NAD/
├── GRAD/start.sp       # gradient of the active state
├── NAD_N1N0/start.sp   # coupling with the state below
└── NAD_N1N2/start.sp   # coupling with the state above
```

The [sample trajectories](../sample_trajectories/README.md) use this layout. Each `start.sp` must contain its own `run gradient` or `run coupling` line. Coupling pairs other than these two neighbors are written from `NAD_N1N0/start.sp`, or from `NAD_N1N2/start.sp` if the first is missing, each in its own `NAC_i_j` folder.

### Keywords the interface manages

| Keyword | Gradient job | Coupling job |
|---|---|---|
| `run` | `gradient` (single template only) | `coupling` (single template only) |
| `castarget` / `cistarget` | active state − 1 | removed (single template only) |
| `nacstate1`, `nacstate2` | — | lower state − 1, upper state − 1 |
| `guess`, and `maxit` and `convthre` with `use_prev_wf` | set only when [`use_prev_wf`](terachem-par.md#use_prev_wf) or [`use_prev_scf_wf`](terachem-par.md#use_prev_scf_wf) is on; both default to `0` | same as the gradient job |
| `coordinates` | `geom.xyz` | `geom.xyz` |
| `scrdir` | removed | removed |

TeraChem numbers states from 0 within one multiplicity. NewtonX numbers them from 1.

## Methods and multiplicity

The supported methods, their keywords, the couplings each allows and the singlet and triplet rules are in [Method tutorials](methods.md), with a tested input per method in [`examples/`](../examples/README.md).

- **One multiplicity per run:** the interface takes only the states of the target multiplicity from TeraChem's output, `castargetmult` for CAS methods and `cismult` for hh-TDA.
- **State numbering:** state 1 is the lowest state of that multiplicity, S0 in a singlet run and T1 in a triplet run.

## Which couplings are computed

At every step NewtonX writes the pairs it needs to `TEMP/transmomin`. The list comes from `jiri.inp`, through `KROSS`, `CASCADE`, `CURRENT`, `NEVER_STATE` and `INCLUDE_PAIR`, and from `THRES` in `control.dyn`. The NewtonX manual explains these keywords. The interface runs one TeraChem coupling job per listed pair. This is [`couplings = nx`](terachem-par.md#couplings), the default. To override the list, set `couplings` in `terachem.par`.

TeraChem computes one coupling per run, so the cost per step is one gradient run plus one run per pair:

| Setting | Pairs per step | TeraChem runs per step (nstat = 3 / 5) |
|---|---|---|
| no `jiri.inp` (NewtonX default: every pair) | nstat(nstat − 1)/2 | 4 / 11 |
| `jiri.inp`: `kross = 1`, `current = 1` | nstat − 1 | 3 / 5 |
| `jiri.inp`: `kross = 0`, `current = 1` (neighbors) | at most 2 | at most 3 / at most 3 |

For ethylene CASSCF with two pairs, a step takes about 13–14 s on one GPU ([Validation](validation.md#14-example-inputs)).

A `jiri.inp` for neighbor couplings:

```text
 &jirinp
  kross   = 0
  current = 1
 /
```

Pairs that are not computed are written as zero vectors, as NewtonX expects. A pair that was zero at the previous step has no previous vector for NewtonX's phase correction. By default the interface compares it with the pair's last computed vector, so its sign stays continuous; see [`phase_ref`](terachem-par.md#phase_ref), default `last`. NewtonX 2.6 corrects the signs a second time, and the interface makes it keep these signs; NewtonX 2.4 has no second correction. See [NewtonX 2.6](terachem-par.md#newtonx-26).

## Coupling methods

What these couplings are, and which methods allow them, is explained in [Coupling vectors and TD-BA couplings](methods.md#coupling-vectors-and-td-ba-couplings).

| `vdoth` in `sh.inp` | Meaning | Supported |
|---|---|---|
| `0` | Coupling vectors from TeraChem | yes |
| `2` | Time-dependent Baeck-An (TD-BA). NewtonX builds the couplings from the energies, so each step needs one TeraChem run. | yes |
| `1`, `< 0` | Time-derivative couplings or local diabatization from wavefunction overlaps | no |

## Adiabatic steps and hops

- **Adiabatic steps:** NewtonX can mark a step as adiabatic, for pure adiabatic dynamics or when the gaps from the active state to the states just below and just above are both larger than `THRES`. The interface then runs only the gradient job and writes zero couplings, so no hop can come from the couplings of an earlier step. With TD-BA, NewtonX writes the couplings itself.
- **Hops:** after a hop, NewtonX calls the interface a second time at the same geometry for the new state's gradient. Coupling jobs are skipped in this second call, because NewtonX already has the couplings of that step.

## See also

- [Output files](outputs.md): what the run writes, and where each TeraChem output is
- [Troubleshooting](troubleshooting.md): error messages and what to do
- [terachem.par reference](terachem-par.md): couplings, guesses, signs and archives
