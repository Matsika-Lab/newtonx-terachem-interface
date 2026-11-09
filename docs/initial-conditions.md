[← README](../README.md)

# Initial conditions and spectra

NewtonX's `initcond.pl` uses `run_tera_ic.pl` when `prog = 21.0` is set in `initqp_input`. It computes vertical excitation energies and oscillator strengths for each sampled geometry. You can use these to filter initial conditions by energy window or to build an absorption spectrum.

## Setup

1. Install the interface. See [installation.md](installation.md).
2. In `initqp_input`, set `prog = 21.0`, and `nis` and `nfs` for the lowest and highest state.
3. Put a TeraChem template in `JOB_AD/`, as `tera.sp` or `start.sp`.
4. Run `$NX/initcond.pl` as usual.

## Templates

The template describes the method in the same way as for [dynamics](dynamics.md#templates). The interface writes `ic.sp` from it with `run energy` and leaves the template unchanged. Ask TeraChem for at least `nfs` states of the chosen multiplicity.

All four methods work: CASSCF, FOMO-CASCI, TDA/TDDFT and hh-TDA. The multiplicity rules are the same as for dynamics.

## Outputs

For each final state `ifs` from `nis + 1` to `nfs`, the interface writes:

| File | Content |
|---|---|
| `epot.<ifs>` | Energy of state `nis`, then of state `ifs` (Hartree) |
| `epot0.<ifs>` | The same, for the reference geometry (NewtonX marks it with a file named `zero`) |
| `oos.<ifs>` | Oscillator strength from `nis` to `ifs` |
| `geom.out` | TeraChem output |

Oscillator strengths are in the length gauge. When `nis = 1`, they are the values TeraChem prints:

| Method | Where TeraChem prints them |
|---|---|
| CASSCF, FOMO-CASCI | `Transition … Osc.` table of the state's multiplicity |
| hh-TDA | `Osc.` column of the `Root Mult. Total Energy` table |
| TDA/TDDFT | `Osc.` column of the excited-state table |

## Several initial states

When `nis > 1`, for example for emission, TeraChem prints no ready-made oscillator strengths from that state. The interface computes them from the transition dipole moment:

f = 2/3 · ΔE · |T|²

ΔE is the energy gap in Hartree and |T| the transition dipole in a.u. Both come from the same TeraChem output.

For TDA/TDDFT, these dipoles come from TeraChem's table of transitions between excited states. Every state up to `nfs` must therefore be in the output.
