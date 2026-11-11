[Home](../README.md) / Future work

# Future work

This page lists known limits of the interface that are not yet addressed, each with the evidence and a proposed fix. Read it before you plan a production set where hop times near crossings matter, or before you work on the coupling code.

## Coupling vectors that turn within a step

### The problem

- **The sign rule.** TeraChem gives each coupling vector an arbitrary sign. The interface fixes it with NewtonX's `escalar`, which keeps the sign that makes the new vector point the same way as the vector of the previous step. After a gap, [`phase_ref`](terachem-par.md#phase_ref) decides which earlier vector is used. When the vector turns by more than 90 degrees within one step, this rule picks the wrong sign.
- **The missed peak.** With coupling vectors (`vdoth = 0`), NewtonX interpolates the vector and the velocity linearly between the two ends of a step. When the coupling peaks sharply inside the step, the interpolation misses most of the peak, even with the right sign.
- **Where it happens.** Near crossings, where the two states mix within a fraction of a step. In a production set of 45 uracil FOMO-CASCI trajectories at dt = 0.5 fs, 7 trajectories had a wrong sign ([Validation, section 19](validation.md#19-coupling-vectors-that-turn-within-a-step)).
- **What it changes.** Both effects lower the hop probability at that step. In three S1 → S0 cases, following the coupling inside the step makes the hop nearly certain. The effect on state lifetimes has not been measured.
- **Other NewtonX interfaces.** The Columbus, Gaussian and BAGEL interfaces of NewtonX 2.4 call the same `escalar`, and the linear interpolation is in NewtonX itself, so coupling-vector runs with those programs can meet the same limit. This is from reading the NewtonX 2.4 source (untested).
- **Status.** Left as is in November 2026, because the event is rare. Watch for it when a trajectory passes close to a crossing.

### Proposed fix: coupling points inside the step

The interface computes extra coupling vectors inside a step only when the vector turns sharply, and follows the sign through them.

1. **Detect.** After the coupling jobs of step *k*, take the cosine between each vector and the vector `escalar` compares it with; `escalar` already computes it. Trigger when |cos| is below 0.8, which is a turn of more than about 37 degrees.
2. **Compute.** Run TeraChem coupling jobs at geometries interpolated linearly between steps *k*−1 and *k*. Start with the midpoint, and halve each interval whose neighboring vectors still have |cos| < 0.8. The interface has to keep the previous geometry next to the phase memory in `INFO_RESTART/`. Each point costs one coupling job. In the checks of section 19, a triggered step needed 3 to 7 inner points.
3. **Fix the sign.** Follow the sign from the step *k*−1 vector through the inner points to step *k*, and write the step *k* vector with that sign. This part fits the interface as it is, and it removes the wrong signs.
4. **Pass on the peak.** With `vdoth = 0`, NewtonX reads only the vectors at the ends of the step, so the peak inside the step still needs one of these (all untested):
   - **NewtonX change:** let `sh` read v·h at the substeps from a file that the interface writes.
   - **Overlap couplings:** pass a step-resolved time-derivative coupling through the `vdoth = 1` route. NewtonX then requires `adjmom = -1`, which changes the velocity rescaling after a hop ([Validation, section 18](validation.md#18-time-derivative-couplings-from-overlaps)).
   - **Shorter time step:** NewtonX 2.4 has a fixed time step, so this costs the whole trajectory, not only the steps near crossings.
5. **Guard the SCF.** Inside one step the FOMO SCF can land on a different solution, which breaks the vector chain. Start each inner point from the wavefunction of step *k*−1, and stop with a warning when an energy jumps between neighboring points.

### How to test the fix

- **Same-path replay.** Section 19 replays NewtonX's electronic propagation on a recorded path with the recorded random numbers. Run the 7 trajectories from section 19 with the fix, and compare the hop probabilities with the "resolved" column.
- **Reruns.** Restart the 7 trajectories one step before the turn, with and without the fix, and compare hop times. Then rerun the whole set to see whether the S1 lifetime changes.
- **No change elsewhere.** On steps that do not trigger, the files NewtonX reads must stay byte-identical, as in [section 1](validation.md#1-byte-identity-replay).

## See also

- [Validation, section 19](validation.md#19-coupling-vectors-that-turn-within-a-step): the evidence for the coupling-turn limit
- [terachem.par reference](terachem-par.md#phase_ref): how `phase_ref` chooses the vector the sign is compared with
- [Running dynamics](dynamics.md): choosing the couplings for a production set
