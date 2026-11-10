[Home](../README.md) / Your first trajectory

# Your first trajectory

This tutorial takes you from a molecule to a running NewtonX trajectory with TeraChem, using twisted ethylene with SA-3-CASSCF(2,2)/6-31G*. Do it once after you install the interface, before you set up your own system. The run is 1 fs long and takes about one minute on one GPU.

## Before you start

- **Interface installed:** follow [Installation](installation.md) and check the install.
- **Environment:** `NX` points to NewtonX's `bin` folder, and `TeraChem` points to the TeraChem installation, so that `$TeraChem/bin/terachem` exists.
- **One GPU:** each trajectory uses one GPU.

## 1. Copy the example input

The folder [`examples/casscf`](../examples/casscf/README.md) is a complete trajectory input. Copy it to a place where you run jobs:

```bash
cp -r examples/casscf ~/runs/ethylene-casscf
cd ~/runs/ethylene-casscf
```

The folder has these files:

```text
ethylene-casscf/
├── control.dyn
├── sh.inp
├── jiri.inp
├── geom
├── veloc
└── JOB_NAD/
    └── tera.sp
```

## 2. Read the inputs

### control.dyn

`control.dyn` holds NewtonX's run settings:

```text
&input
 nat = 6
 nstat = 3
 nstatdyn = 2
 dt = 0.5
 tmax = 1
 prog = 21.0
 thres = 100
 etot_jump = 0.5
 etot_drift = 0.5
 lvprt = 2
/
```

- **`prog = 21.0`:** tells NewtonX to call this interface.
- **`nstat = 3`, `nstatdyn = 2`:** three states, and the trajectory starts in state 2, which is S1.
- **`dt = 0.5`, `tmax = 1`:** a 0.5 fs time step and a 1 fs run, so NewtonX calls the interface at 0, 0.5 and 1.0 fs.
- **`thres = 100`:** couplings are computed at every step, because the gaps are always below 100 eV.
- **`lvprt = 2`:** `moldyn.log` shows the coupling pairs of each step.

### geom and veloc

`geom` holds the starting geometry in NewtonX format: symbol, nuclear charge, x, y, z in Bohr, and mass. `veloc` holds the velocities in a.u.; here they are all zero.

To make `geom` for your own molecule, start from an `.xyz` file in Å and run NewtonX's converter, which writes `geom`:

```bash
$NX/xyz2nx < mymolecule.xyz
```

For real dynamics, take geometries and velocities from a Wigner sampling instead. See [Initial conditions and spectra](initial-conditions.md).

### sh.inp and jiri.inp

- **`sh.inp`:** surface-hopping settings. `vdoth = 0` asks for coupling vectors from TeraChem. See [Coupling methods](dynamics.md#coupling-methods).
- **`jiri.inp`:** `kross = 0` and `current = 1` ask for the couplings of the current state with its two neighbors only. Without this file, NewtonX asks for every pair of states, at one TeraChem run per pair. See [Which couplings are computed](dynamics.md#which-couplings-are-computed).

### JOB_NAD/tera.sp

`tera.sp` is an ordinary TeraChem input that describes the method:

```text
# CASSCF: SA-3-CASSCF(2,2)/6-31G* for ethylene (pi, pi*)
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
charge          0
spinmult        1
gpus            1
coordinates     geom.xyz
```

It has no `run`, `castarget`, `nacstate1` or `nacstate2` lines. The interface writes those for each job; see [Keywords the interface manages](dynamics.md#keywords-the-interface-manages).

There is no `terachem.par`, so every interface setting has its default; see [terachem.par reference](terachem-par.md#summary-of-keys).

## 3. Run NewtonX

```bash
export CUDA_VISIBLE_DEVICES=0
$NX/moldyn.pl > moldyn.log
```

`CUDA_VISIBLE_DEVICES` picks the GPU. All TeraChem jobs of the trajectory run on it, one after another.

## 4. Watch moldyn.log

At each step, `moldyn.log` shows the interface version and the settings in effect, then the coupling pairs and the TeraChem jobs. From the first step of the test run, made with NewtonX 2.4 (build 06) and TeraChem 1.96 beta:

```text
run-tera-cas.pl: step type 2, vdoth 0: computing coupling vectors.
run-tera-cas.pl: coupling pairs this step (couplings = nx): 2-1 3-2
---------------------------------------------------------------------------
Starting /bin/terachem GRAD/start.sp  at Mon Nov  9 05:39:00 PM EST 2026
Finished /bin/terachem GRAD/start.sp  successfuly at Mon Nov  9 05:39:09 PM EST 2026
---------------------------------------------------------------------------
Archived molden file to ../INFO_RESTART/MOLDEN_ARCHIVE/0.0000.molden
---------------------------------------------------------------------------
Starting /bin/terachem NAC_1_2/start.sp  at Mon Nov  9 05:39:09 PM EST 2026
Finished /bin/terachem NAC_1_2/start.sp  successfuly at Mon Nov  9 05:39:13 PM EST 2026
---------------------------------------------------------------------------
---------------------------------------------------------------------------
Starting /bin/terachem NAC_2_3/start.sp  at Mon Nov  9 05:39:13 PM EST 2026
Finished /bin/terachem NAC_2_3/start.sp  successfuly at Mon Nov  9 05:39:19 PM EST 2026
---------------------------------------------------------------------------
--------------------------------------------------
run-tera-cas.pl: Energies (Hartree) at time t=0.0000:
State  1:       -78.0196428000
State  2:       -77.7167724700
State  3:       -77.5893752800
--------------------------------------------------
```

- **Three TeraChem jobs per step:** one gradient job for S1, and one coupling job each for the pairs S1–S0 and S2–S1.
- **Energies:** the energies of the three states, which the interface passes to NewtonX.
- **End of the run:** the log ends with `moldyn.pl: End of dynamics`.

If the run stops with a line that contains `ERROR`, look it up in [Troubleshooting](troubleshooting.md).

## 5. Check the results

NewtonX writes its results to `RESULTS/`. Look at these files first:

- **Energies.** `RESULTS/en.dat` has one line per step: the energy of each state, the energy of the current state and the total energy, in Hartree. The total energy should stay nearly constant.
- **Hops.** `RESULTS/sh.out` has a line `SURFACE HOPPING!` for every hop. In this short run there is none, so the trajectory stays on S1.
- **Gaps.** `RESULTS/typeofdyn.log` gives the gaps from the current state to the states below and above, in eV.

The numbers of the test run are in the [example's README](../examples/casscf/README.md#result). [Output files](outputs.md) describes every file.

## Cost and duration

The run makes 9 TeraChem runs, three per interface call, and takes about 13–14 s per step on one NVIDIA RTX 5000 Ada GPU ([Validation](validation.md#14-example-inputs)).

## Next steps

- **Your own molecule:** write `geom`, set `nat` and `nstat` in `control.dyn`, and adapt the template's basis, active space and number of states. [Method tutorials](methods.md) explain the keywords of each method.
- **Starting conditions:** sample geometries and velocities, and pick the initial state, with [Initial conditions and spectra](initial-conditions.md).
- **Settings:** change the couplings, guesses or archives in [`terachem.par`](terachem-par.md).

## See also

- [Running dynamics](dynamics.md): the full setup, templates and coupling choices
- [Examples](../examples/README.md): the same tutorial input for every method
- [Troubleshooting](troubleshooting.md): what an error message means
