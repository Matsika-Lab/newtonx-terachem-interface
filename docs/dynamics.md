[← README](../README.md)

# Running dynamics

## Setup checklist

1. Install the interface. See [installation.md](installation.md).
2. Set `prog = 21.0` in `control.dyn`.
3. Copy the template for your method from [`examples/`](../examples) to `JOB_NAD/tera.sp` and adapt it. See [Method tutorials](methods.md) and [Templates](#templates).
4. Set `vdoth` in `sh.inp`: `0` for coupling vectors or `2` for TD-BA. If `sh.inp` has no `vdoth`, NewtonX uses 2. See [Coupling methods](#coupling-methods).
5. Choose the couplings with `jiri.inp`. See [Which couplings are computed](#which-couplings-are-computed).
6. Optionally, add `terachem.par`. See [terachem-par.md](terachem-par.md).
7. Give the trajectory one GPU and run NewtonX:

   ```bash
   export CUDA_VISIBLE_DEVICES=0
   $NX/moldyn.pl > moldyn.log
   ```

Each trajectory uses one GPU. The TeraChem jobs of a step run one after another.

A trajectory folder looks like this:

```text
TRAJ1/
├── control.dyn      # prog = 21.0
├── sh.inp           # vdoth = 0 (coupling vectors) or 2 (TD-BA)
├── jiri.inp         # which couplings NewtonX asks for
├── terachem.par     # optional interface options
├── geom             # initial geometry (Bohr)
├── veloc            # initial velocities (a.u.)
└── JOB_NAD/
    └── tera.sp      # TeraChem template
```

> [!WARNING]
> On adiabatic steps and with TD-BA, NewtonX takes the template from `JOB_AD/`, not `JOB_NAD/`. If the trajectory folder has no `JOB_AD/`, NewtonX makes one as a copy of `JOB_NAD/` when the run starts. Do not keep an old `JOB_AD/` next to `JOB_NAD/`, or it will be used for those steps.

## Templates

### Single template (recommended)

```text
JOB_NAD/
└── tera.sp
```

`tera.sp` is an ordinary TeraChem input that describes the method, basis, active space and so on. The interface writes the gradient input and every coupling input from it at each step. Leave out the keywords in the table below; the interface sets them. `guess` is the exception: the interface changes it only when a guess option is on.

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
├── GRAD/start.sp       # gradient of the current state
├── NAD_N1N0/start.sp   # coupling with the state below
└── NAD_N1N2/start.sp   # coupling with the state above
```

The sample trajectories use this layout. Each `start.sp` must contain its own `run gradient` or `run coupling` line. Coupling pairs other than these two neighbours are written from `NAD_N1N0/start.sp`, or from `NAD_N1N2/start.sp` if the first is missing, each in its own `NAC_i_j` folder.

### Keywords the interface manages

| Keyword | Gradient job | Coupling job |
|---|---|---|
| `run` | `gradient` (single template only) | `coupling` (single template only) |
| `castarget` / `cistarget` | current state − 1 | removed (single template only) |
| `nacstate1`, `nacstate2` | — | lower state − 1, upper state − 1 |
| `guess`, and `maxit` and `convthre` with `use_prev_wf` | set only when [`use_prev_wf`](terachem-par.md#use_prev_wf) or [`use_prev_scf_wf`](terachem-par.md#use_prev_scf_wf) is on | same as the gradient job |
| `coordinates` | `geom.xyz` | `geom.xyz` |
| `scrdir` | removed | removed |

TeraChem numbers states from 0 within one multiplicity. NewtonX numbers them from 1.

## Methods and multiplicity

The supported methods, their keywords, the couplings each allows and the singlet/triplet rules are in [Method tutorials](methods.md), with a tested template per method in [`examples/`](../examples).

- **One multiplicity per run:** the interface takes only the states of the target multiplicity from TeraChem's output, `castargetmult` for CAS methods and `cismult` for hh-TDA.
- **State numbering:** state 1 is the lowest state of that multiplicity, S0 in a singlet run and T1 in a triplet run.

## Which couplings are computed

At every step NewtonX writes the pairs it needs to `TEMP/transmomin`. The list comes from `jiri.inp`, through `KROSS`, `CASCADE`, `CURRENT`, `NEVER_STATE` and `INCLUDE_PAIR`, and from `THRES` in `control.dyn`. The NewtonX manual explains these keywords. The interface runs one TeraChem coupling job per listed pair. To override the list, set [`couplings`](terachem-par.md#couplings) in `terachem.par`.

TeraChem computes one coupling per run, so the cost per step is one gradient run plus one run per pair:

| Setting | Pairs per step | TeraChem runs per step (nstat = 3 / 5) |
|---|---|---|
| no `jiri.inp` (NewtonX default: every pair) | nstat(nstat − 1)/2 | 4 / 11 |
| `jiri.inp`: `kross = 1`, `current = 1` | nstat − 1 | 3 / 5 |
| `jiri.inp`: `kross = 0`, `current = 1` (neighbours) | at most 2 | at most 3 / at most 3 |

A `jiri.inp` for neighbour couplings:

```text
 &jirinp
  kross   = 0
  current = 1
 /
```

Pairs that are not computed are written as zero vectors, as NewtonX expects. A pair that was zero at the previous step has no previous vector for NewtonX's phase fix. By default the interface compares it with the pair's last computed vector, so its sign stays continuous; see [`phase_ref`](terachem-par.md#phase_ref).

## Coupling methods

What these couplings are, and which methods allow them: [Couplings: NAC and TD-BA](methods.md#couplings-nac-and-td-ba).

| `vdoth` in `sh.inp` | Meaning | Supported |
|---|---|---|
| `0` | Coupling vectors from TeraChem | yes |
| `2` | Time-dependent Baeck-An (TD-BA). NewtonX builds the couplings from the energies, so each step needs one TeraChem run. | yes |
| `1`, `< 0` | Time-derivative couplings or local diabatization from wavefunction overlaps | no |

## Adiabatic steps and hops

- **Adiabatic steps:** NewtonX can mark a step as adiabatic, for pure adiabatic dynamics or when the gaps from the current state to the states just below and just above are both larger than `THRES`. The interface then runs only the gradient job and writes zero couplings, so no hop can come from the couplings of an earlier step. With TD-BA, NewtonX writes the couplings itself.
- **Hops:** after a hop, NewtonX calls the interface a second time at the same geometry for the new state's gradient. Coupling jobs are skipped in this second call, because NewtonX already has the couplings of that step.

## Output files

| File | Content |
|---|---|
| `TEMP/GRAD/tera.out` | TeraChem output of the gradient job |
| `TEMP/NAC_i_j/tera.out` | Coupling job between states i and j |
| `TEMP/NAD_N1N0/`, `TEMP/NAD_N1N2/` | Neighbour coupling jobs in the three-template layout, instead of `NAC_i_j` |
| `TEMP/<job>/scr.geom/` | TeraChem scratch of that job, cleared before each run |
| `INFO_RESTART/MOLDEN_ARCHIVE/<time>.molden` | Orbitals of each step ([`archive_molden`](terachem-par.md#archive_molden)) |
| `INFO_RESTART/WF_ARCHIVE/c<time>` | CASSCF orbitals of each step ([`archive_wf`](terachem-par.md#archive_wf)) |
| `INFO_RESTART/WF_OLD/` | Previous step's orbitals for the guess options |

`moldyn.log` shows the interface version, the options in effect and, at `lvprt = 2` or higher, the coupling pairs of each step.

## Error messages

The interface stops the trajectory with a message that starts with `run-tera-cas.pl: ERROR:`. The most common ones:

| Message contains | Cause | What to do |
|---|---|---|
| `TeraChem failed in <job>` | TeraChem returned an error | Read `TEMP/<job>/tera.out` |
| `TeraChem did not finish in <job>` | The run was killed, for example by a licence time limit or the queue | Check the time limit. To continue, set `nxrestart = 1` in `control.dyn` and run `moldyn.pl` again |
| `Could not read N state energies` | Fewer states in the output than `nstat`, or the wrong multiplicity | Raise the number of states in the template; check `castargetmult` or `cismult` |
| `... atom lines; expected N` | A gradient or coupling file is incomplete | Read the job's `tera.out` |
| `Unknown option` | A typo in `terachem.par` | See [terachem-par.md](terachem-par.md) |
| `vdoth = ... needs wavefunction overlaps` | `vdoth` is 1 or negative | Use `vdoth = 0` or `2` |
