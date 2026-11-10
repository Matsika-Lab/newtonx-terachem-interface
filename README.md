# NewtonX–TeraChem interface

Runs nonadiabatic surface-hopping dynamics in [NewtonX](https://newtonx.org/) with energies, gradients and couplings from [TeraChem](https://www.petachem.com/).

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

Then, in a trajectory folder:

1. Set `prog = 21.0` in `control.dyn`.
2. Set `vdoth = 0` in `sh.inp` for coupling vectors, or `vdoth = 2` for time-dependent Baeck-An (TD-BA) couplings. If `sh.inp` has no `vdoth`, NewtonX uses 2.
3. Choose the couplings in `jiri.inp`. Without it, NewtonX asks for every pair of states, at one TeraChem run per pair. See [Which couplings are computed](docs/dynamics.md#which-couplings-are-computed).
4. Copy a template from [`examples/`](examples) to `JOB_NAD/tera.sp` and adapt it.
5. Give the trajectory one GPU and start NewtonX:

   ```bash
   export CUDA_VISIBLE_DEVICES=0
   $NX/moldyn.pl > moldyn.log
   ```

## Methods

Five TeraChem methods are supported: CASSCF, FOMO-CASCI, TDA/TDDFT, hole-hole TDA (hh-TDA) and full TDDFT (RPA). Full TDDFT works with TD-BA couplings only. Triplets work with CASSCF, FOMO-CASCI and hh-TDA. See [Method tutorials](docs/methods.md).

## Documentation

- [Installation](docs/installation.md)
- [Method tutorials](docs/methods.md)
- [Running dynamics](docs/dynamics.md)
- [terachem.par options](docs/terachem-par.md)
- [Initial conditions and spectra](docs/initial-conditions.md)
- [Validation](docs/validation.md)
- [Development and testing](docs/development.md)
- [Changelog](CHANGELOG.md)

## Examples and samples

- **[`examples/`](examples):** one TeraChem template for each method, for ethylene.
- **[`sample_trajectories/`](sample_trajectories):** two complete short trajectories with all inputs and NewtonX output. They were made with a version before 2.0, so each has a `terachem.par` that keeps the old coupling behaviour.

| Folder | Molecule | Method | States |
|---|---|---|---|
| `casscf_cycloctadiene` | cyclooctadiene | SA-3 CASSCF(4,3)/cc-pVDZ | 3, start in S1 |
| `fomo_casci_o_nitrophenol` | o-nitrophenol | FOMO-CASCI(12,10)/cc-pVDZ | 5, start in S3 |

## Credits

- **Authors:** Dakshitha Abeygunewardane, Vaibhav Singh and Spiridoula Matsika, Matsika Lab, Department of Chemistry, Temple University. The interface was built from the NewtonX interface template by Mario Barbatti (2021).
- **AI use:** the 2026-11-09 revision (version 2.0) was refactored and improved with Claude Code (Anthropic), using the Claude Opus 5.5 model.
  - **What it covered:**
    - the rewrite of `run-tera-cas.pl`: couplings chosen by NewtonX, one template, `terachem.par`, adiabatic steps and TD-BA, triplets and safety checks;
    - the rewrite of `run_tera_ic.pl`;
    - the NewtonX installer;
    - the unit tests and the replay harness;
    - the validation runs;
    - the method tutorials, the example templates and the documentation.
  - **Decisions:** the authors made the design decisions.
  - **Commits:** the commits of this revision carry `Co-Authored-By: Claude` lines.
- **Citation:** see [`CITATION.cff`](CITATION.cff). Please also cite NewtonX and TeraChem.
- **Licence:** GPL-3.0-or-later, see [`LICENSE`](LICENSE). Versions before 2.0 were released under the MIT licence.
