[Home](../README.md) / Examples

# Examples

Each folder here is a complete NewtonX input for a 1 fs trajectory of twisted ethylene with one TeraChem method: 6-31G*, three singlet states, starting on S1. Copy a folder, run `moldyn.pl` in the copy, and use its `JOB_NAD/tera.sp` as the starting point for your own molecule. Each input ran unchanged with interface 2.0.0, NewtonX 2.4 (build 06) and TeraChem 1.96 beta; see [Validation](../docs/validation.md#14-example-inputs).

| Folder | Molecule | Method | States | Couplings | Time per step |
|---|---|---|---|---|---|
| [`casscf`](casscf/README.md) | ethylene | SA-3-CASSCF(2,2)/6-31G* | 3, start in S1 | coupling vectors | 13–14 s |
| [`fomo-casci`](fomo-casci/README.md) | ethylene | FOMO-CASCI(4,4)/6-31G* | 3, start in S1 | coupling vectors | 10 s |
| [`tda`](tda/README.md) | ethylene | TDA CAM-B3LYP/6-31G* | 3, start in S1 | coupling vectors | 13 s |
| [`hh-tda`](hh-tda/README.md) | ethylene | hh-TDA BH&HLYP/6-31G* | 3, start in S1 | coupling vectors | 17–19 s |
| [`rpa-tdba`](rpa-tdba/README.md) | ethylene | RPA CAM-B3LYP/6-31G* | 3, start in S1 | TD-BA | 12–13 s |

The time per step is the wall time of the second and third interface calls on one NVIDIA RTX 5000 Ada GPU.

Every folder has the same files:

```text
casscf/
├── control.dyn      # prog = 21.0, nstat = 3, nstatdyn = 2, dt = 0.5, tmax = 1
├── sh.inp           # vdoth = 0 (rpa-tdba: vdoth = 2)
├── jiri.inp         # kross = 0, current = 1: neighbor couplings
├── geom             # twisted ethylene (Bohr)
├── veloc            # zero velocities (a.u.)
├── README.md
└── JOB_NAD/
    └── tera.sp      # TeraChem template
```

To run one:

```bash
cp -r examples/casscf ~/runs/ethylene-casscf
cd ~/runs/ethylene-casscf
export CUDA_VISIBLE_DEVICES=0
$NX/moldyn.pl > moldyn.log
```

For two complete, longer trajectories with their output, see [Sample trajectories](../sample_trajectories/README.md).
