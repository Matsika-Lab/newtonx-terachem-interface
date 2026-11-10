[← README](../README.md)

# Initial conditions and spectra

NewtonX's `initcond.pl` uses `run_tera_ic.pl` when `prog = 21.0` is set in `initqp_input`. It computes vertical excitation energies and oscillator strengths for each sampled geometry. You can use these to filter initial conditions by energy window or to build an absorption spectrum.

## Setup

1. Install the interface. See [installation.md](installation.md).
2. In `initqp_input`, set `prog = 21.0` and `chk_e = 1`. Set `nis` to the initial state and `nfs` to the highest final state. Without `chk_e = 1`, `initcond.pl` never calls the interface.
3. Put a TeraChem template in `JOB_AD/`, as `tera.sp` or `start.sp`. A copy of a dynamics `JOB_NAD/` folder also works. With the three-template layout, the interface uses `GRAD/start.sp`.
4. Run `$NX/initcond.pl` as usual.

## Templates

The template describes the method in the same way as for [dynamics](dynamics.md#templates); the templates in [`examples/`](../examples) work unchanged. The interface writes `ic.sp` from it with `run energy` and leaves the template itself unchanged.

- **States:** ask TeraChem for at least `max(nis, nfs)` states of the chosen multiplicity.
- **Dynamics-only keywords:** `castarget`, `cistarget`, `nacstate1`, `nacstate2` and `scrdir` are removed. A `guess` line whose file does not exist, for example a path into `INFO_RESTART`, is removed too, together with `maxit` and `convthre`.
- **Log line:** the output of `initcond.pl` shows the interface version, the template used, the method, the multiplicity and the states.

All five methods work: CASSCF, FOMO-CASCI, TDA, hh-TDA and full TDDFT (RPA). Couplings are not needed here, so RPA has no restriction. The multiplicity rules are the same as for dynamics.

## Outputs

For every state `ifs` from 1 to `max(nis, nfs)` other than `nis`, the interface writes the files `initcond.pl` reads:

| File | Content |
|---|---|
| `epot.<ifs>` | Energies of states `nis` and `ifs`, lower state number first (Hartree) |
| `epot0.<ifs>` | The same, for the reference geometry (NewtonX marks it with a file named `zero`) |
| `oos.<ifs>` | Oscillator strength between `nis` and `ifs` |
| `geom.out` | TeraChem output |

Oscillator strengths are in the length gauge. Where TeraChem prints them, its values are used:

| Method | Where TeraChem prints them |
|---|---|
| CASSCF, FOMO-CASCI | `Transition … Osc.` table of the state's multiplicity |
| hh-TDA | `Osc.` column of the `Root Mult. Total Energy` table |
| TDA/TDDFT | `Osc.` column of the excited-state table |

## Several initial states

When `nis > 1`, for example for emission, TeraChem often prints no oscillator strength for the pair. The interface then computes it from the transition dipole moment:

f = 2/3 · |ΔE| · |T|²

|ΔE| is the energy gap in Hartree and |T| the transition dipole in a.u. Both come from the same TeraChem output.

For TDA/TDDFT, these dipoles come from TeraChem's table of transitions between excited states. Every state up to `max(nis, nfs)` must therefore be in the output.
