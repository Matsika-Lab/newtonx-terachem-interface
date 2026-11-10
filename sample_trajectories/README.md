[Home](../README.md) / Sample trajectories

# Sample trajectories

These folders hold two complete trajectories, with all inputs and the NewtonX output. Look at them to see what a longer run produces, or to compare with your own run. Both were made with the interface before version 2.0, at commit `35c7390`, under NewtonX 2.4 (build 06). Each has a `terachem.par` with `couplings = neighbours` and `phase_ref = previous`, so version 2.0.0 computes the same couplings with the same signs as the script that made them.

| Folder | Molecule | Method | States | Length | Hops |
|---|---|---|---|---|---|
| [`casscf_cycloctadiene`](casscf_cycloctadiene/README.md) | cyclooctadiene | SA-3-CASSCF(4,3)/cc-pVDZ | 3, start in S1 | 20 fs | none |
| [`fomo_casci_o_nitrophenol`](fomo_casci_o_nitrophenol/README.md) | o-nitrophenol | FOMO-CASCI(12,10)/cc-pVDZ | 5, start in S3 | 40 fs | S3 → S4 at 1.0 fs |

For short, tested inputs of every method, see [Examples](../examples/README.md).

## See also

- [Examples](../examples/README.md): short inputs for every method
- [terachem.par options](../docs/terachem-par.md): `couplings` and `phase_ref`, which the samples set
- [Outputs](../docs/outputs.md): what each result file holds
