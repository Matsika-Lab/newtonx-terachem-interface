# NewtonX–TeraChem interface

Runs nonadiabatic surface-hopping dynamics in [NewtonX](https://newtonx.org/) with energies, gradients and couplings from [TeraChem](https://www.petachem.com/).

At every time step, the interface runs TeraChem for the gradient of the active state and for the coupling vectors NewtonX asks for, and hands the results back to NewtonX. It also computes excitation energies and oscillator strengths for NewtonX's initial conditions and spectra.

## Requirements

| Software | Version |
|---|---|
| NewtonX | 2.4 (build 06) or 2.6 (build 01) |
| TeraChem | 1.96 beta, tested |
| Perl | 5.10 or newer |
| Environment | `NX` points to NewtonX's `bin` folder. `TeraChem` points to the TeraChem installation, so that `$TeraChem/bin/terachem` exists. |

## Quick start

```bash
git clone https://github.com/Matsika-Lab/newtonx-terachem-interface.git
cd newtonx-terachem-interface
perl install/install_nx.pl $NX
```

Then run the ethylene CASSCF example as a first trajectory:

1. Copy the example folder, which is a complete input: `cp -r examples/casscf ~/runs/ethylene-casscf`.
2. Go to the copy: `cd ~/runs/ethylene-casscf`.
3. Give the trajectory one GPU and start NewtonX:

   ```bash
   export CUDA_VISIBLE_DEVICES=0
   $NX/moldyn.pl > moldyn.log
   ```

The run is 1 fs long, with 3 interface calls and 9 TeraChem runs. It takes about one minute on one NVIDIA RTX 5000 Ada GPU, about 13–14 s per step ([Validation](docs/validation.md#14-example-inputs)). [Your first trajectory](docs/first-trajectory.md) explains every input and the output.

For your own molecule, copy a template from [`examples/`](examples/README.md) to `JOB_NAD/tera.sp` in the trajectory folder, and set `prog = 21.0` in `control.dyn`.

## Methods

| Method | Program keyword | Couplings | Tutorial |
|---|---|---|---|
| CASSCF | `casscf yes` | coupling vectors, time-derivative couplings from overlaps, time-dependent Baeck-An (TD-BA) | [CASSCF](docs/methods.md#casscf) |
| FOMO-CASCI | `fon yes` + `casci yes` | coupling vectors, overlap couplings, TD-BA | [FOMO-CASCI](docs/methods.md#fomo-casci) |
| TDA/TDDFT | `cis yes` | coupling vectors, TD-BA | [TDA](docs/methods.md#tda-tddft) |
| hh-TDA | `hhtda yes` | coupling vectors, TD-BA | [hh-TDA](docs/methods.md#hh-tda) |
| Full TDDFT | `rpa yes` | TD-BA | [Full TDDFT](docs/methods.md#full-tddft-rpa) |

Overlap couplings (`vdoth = 1`) work with CASSCF and FOMO-CASCI only, and need `adjmom = -1` in `sh.inp`. Triplets: FOMO-CASCI and hh-TDA are tested; CASSCF triplets are untested. Full TDDFT works with TD-BA couplings only.

## Where to go next

| I want to… | Read |
|---|---|
| Install, or see what the installer changes | [Installation](docs/installation.md) |
| Run my first trajectory step by step | [Your first trajectory](docs/first-trajectory.md) |
| Choose a method and write its template | [Method tutorials](docs/methods.md) |
| Set up my own trajectories and choose the couplings | [Running dynamics](docs/dynamics.md) |
| Change an interface setting or look up a default | [terachem.par reference](docs/terachem-par.md) |
| Make initial conditions or an absorption spectrum | [Initial conditions and spectra](docs/initial-conditions.md) |
| Find a file the run wrote | [Output files](docs/outputs.md) |
| Understand an error message | [Troubleshooting](docs/troubleshooting.md) |
| See the tests, benchmarks and timings | [Validation](docs/validation.md) |
| Run the tests or change the code | [Development and testing](docs/development.md) |
| Start from a tested input | [Examples](examples/README.md) |
| See what changed between versions | [Changelog](CHANGELOG.md) |
| Follow the documentation style | [Documentation style](docs/STYLE.md) |

## Examples

[`examples/`](examples/README.md) has one complete, tested 1 fs input per method, for ethylene. [`sample_trajectories/`](sample_trajectories/README.md) has two complete, longer trajectories with their output.

## Credits, citation and license

- **Authors:** Dakshitha Abeygunewardane, Vaibhav Singh and Spiridoula Matsika, Matsika Lab, Department of Chemistry, Temple University. The interface was built from the NewtonX interface template by Mario Barbatti (2021).
- **AI use:** The 2026-11-09 revision (version 2.0.0) was refactored and improved with Claude Code (Anthropic), using the Claude Opus 5.5 model. Version 2.1.0, of 2026-11-10, was made the same way.
  - **What it covered:**
    - the rewrite of `run-tera-cas.pl`: couplings chosen by NewtonX, one template, `terachem.par`, adiabatic steps and TD-BA, triplets and safety checks;
    - the rewrite of `run_tera_ic.pl`;
    - the NewtonX installer;
    - the unit tests and the replay harness;
    - the validation runs;
    - the time-derivative couplings from overlaps of version 2.1.0;
    - the method tutorials, the example inputs and the documentation.
  - **Decisions:** the authors made the design decisions.
  - **Commits:** the commits of this revision carry `Co-Authored-By: Claude` lines.
- **Citation:** see [`CITATION.cff`](CITATION.cff). Please also cite NewtonX and TeraChem.
- **License:** GPL-3.0-or-later, see [`LICENSE`](LICENSE). Versions before 2.0 were released under the MIT license.
