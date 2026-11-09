[← README](../README.md)

# Running dynamics

## Setup checklist

1. Install the interface. See [installation.md](installation.md).
2. Set `prog = 21.0` in `control.dyn`.
3. Write the TeraChem template, `JOB_NAD/tera.sp`. See [Templates](#templates).
4. Choose the couplings with `jiri.inp`. See [Which couplings are computed](#which-couplings-are-computed).
5. Optionally, add `terachem.par`. See [terachem-par.md](terachem-par.md).
6. Give the trajectory one GPU and run NewtonX:

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

## Templates

### Single template (recommended)

```text
JOB_NAD/
└── tera.sp
```

`tera.sp` is an ordinary TeraChem input that describes the method, basis, active space and so on. The interface writes the gradient input and every coupling input from it at each step. Leave out the keywords in the table below, or leave them at any value; the interface sets them.

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

### Three templates (older layout, still supported)

```text
JOB_NAD/
├── GRAD/start.sp       # gradient of the current state
├── NAD_N1N0/start.sp   # coupling with the state below
└── NAD_N1N2/start.sp   # coupling with the state above
```

Coupling pairs other than these two neighbours are written from the coupling template, in their own folders.

### Keywords the interface manages

| Keyword | Gradient job | Coupling job |
|---|---|---|
| `run` | `gradient` | `coupling` |
| `castarget` / `cistarget` | current state − 1 | removed (single template only) |
| `nacstate1`, `nacstate2` | — | lower state − 1, upper state − 1 |
| `guess` (`maxit`, `convthre` with `use_prev_wf`) | see [guess options](terachem-par.md#use_prev_wf) | see [guess options](terachem-par.md#use_prev_scf_wf) |
| `coordinates` | `geom.xyz` | `geom.xyz` |
| `scrdir` | removed | removed |

TeraChem numbers states from 0 within one multiplicity. NewtonX numbers them from 1.

## Methods and multiplicity

| Method | Template keywords | Gradients | Couplings |
|---|---|---|---|
| CASSCF | `casscf yes` | yes | yes |
| FOMO-CASCI | `fon yes`, `casci yes` | yes | yes |
| TDA (TDDFT) | `cis yes` | yes | yes |
| Full TDDFT (RPA) | `rpa yes` (without `cis yes`) | yes | **no**: use TD-BA (`vdoth = 2`) |
| hh-TDA | `hhtda yes` | yes | yes |

> [!WARNING]
> TeraChem finishes an RPA coupling run normally but writes a coupling vector of zeros. The interface therefore refuses RPA with coupling vectors. RPA gradients are correct, so RPA can run with TD-BA couplings (`vdoth = 2`), which NewtonX builds from the energies. The interface also warns in `moldyn.log` whenever any coupling vector comes back as all zeros.

**Singlets or triplets, one multiplicity per run.** The interface takes only the states of the target multiplicity from TeraChem's output.

- **CAS methods:** the multiplicity is `castargetmult`. A triplet run needs `castargetmult 3`, also in the coupling jobs. A template with `cassinglets 0` and no `castargetmult` stops with a message.
- **hh-TDA:** the multiplicity is `cismult`, with `hhtdatriplets` for the number of states.
- **TDA/TDDFT triplets:** not supported. TeraChem has no triplet gradients or couplings for restricted TDDFT.

State 1 is the lowest state of the chosen multiplicity. In a singlet run that is S0. In a triplet run it is T1.

## Which couplings are computed

> [!NOTE]
> Since version 2.0 the interface computes the couplings NewtonX asks for in `jiri.inp`. Earlier versions always computed the two neighbour couplings and ignored `jiri.inp`. Set `couplings = neighbours` in `terachem.par` for the old behaviour.

At every step NewtonX writes the pairs it needs to `TEMP/transmomin`. The list comes from `jiri.inp`, through `KROSS`, `CASCADE`, `CURRENT`, `NEVER_STATE` and `INCLUDE_PAIR`, and from `THRES` in `control.dyn`. The interface runs one TeraChem coupling job per listed pair. To override the list, set [`couplings`](terachem-par.md#couplings) in `terachem.par`.

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

Pairs that are not computed are written as zero vectors, as NewtonX expects. A pair that was zero at the previous step gets its sign from TeraChem, because NewtonX's phase fix has no previous vector to compare with.

## Coupling methods

| `vdoth` in `sh.inp` | Meaning | Supported |
|---|---|---|
| `0` | Coupling vectors from TeraChem | yes |
| `2` | Time-dependent Baeck-An (TD-BA). NewtonX builds the couplings from the energies, so each step needs one TeraChem run. | yes |
| `1`, `< 0` | Time-derivative couplings or local diabatization from wavefunction overlaps | no |

## Adiabatic steps and hops

- **Adiabatic steps:** NewtonX can mark a step as adiabatic, for pure adiabatic dynamics or when every energy gap is larger than `THRES`. The interface then runs only the gradient job and leaves the coupling files alone.
- **Hops:** after a hop, NewtonX calls the interface a second time at the same geometry for the new state's gradient. Coupling jobs are skipped in this second call, because NewtonX already has the couplings of that step.

## Output files

| File | Content |
|---|---|
| `TEMP/GRAD/tera.out` | TeraChem output of the gradient job |
| `TEMP/NAC_i_j/tera.out` | Coupling job between states i and j (single template) |
| `TEMP/NAD_N1N0/`, `TEMP/NAD_N1N2/` | Neighbour coupling jobs (three-template layout) |
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
| `TeraChem did not finish in <job>` | The run was killed, for example by a licence time limit or the queue | Check the time limit; restart from `INFO_RESTART` |
| `Could not read N state energies` | Fewer states in the output than `nstat`, or the wrong multiplicity | Raise the number of states in the template; check `castargetmult` or `cismult` |
| `... atom lines; expected N` | A gradient or coupling file is incomplete | Read the job's `tera.out` |
| `Unknown option` | A typo in `terachem.par` | See [terachem-par.md](terachem-par.md) |
| `vdoth = ... needs wavefunction overlaps` | `vdoth` is 1 or negative | Use `vdoth = 0` or `2` |
