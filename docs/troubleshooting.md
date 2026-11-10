[Home](../README.md) / Troubleshooting

# Troubleshooting

This page lists every message the interface prints when something goes wrong, with its cause and what to do. Search the page for a few words of the message you see. The "Message contains" column quotes the fixed part of each message as it appears in `run-tera-cas.pl` or `run_tera_ic.pl`, so you can also grep the scripts for it.

## Where messages appear

- **Errors in dynamics:** `run-tera-cas.pl` stops the trajectory with a line that starts with `run-tera-cas.pl: ERROR:`. The line is printed to `moldyn.log` and `RESULTS/nx.log` at every step that NewtonX prints, which is every step with `kt = 1`. It is always written to `DEBUG/runnx.error`. NewtonX then stops with `is dying now during run-tera-cas.pl execution`.
- **Warnings in dynamics:** lines that start with `run-tera-cas.pl: WARNING:` go to `moldyn.log` and `RESULTS/nx.log`. The run continues.
- **Checks at the start of a run:** with the [installer](installation.md)'s NewtonX registration, NewtonX checks the TeraChem path, `vdoth` and `terachem.par` before the first step. Its messages contain `<ERROR>` and appear in `moldyn.log`.
- **Initial conditions:** `run_tera_ic.pl` prints `run_tera_ic.pl: ERROR:` lines in the output of `initcond.pl`, and writes them to `DEBUG/runnx.error`.
- **Terminal:** `run-tera-cas.pl --check-options` and `install/install_nx.pl` print to the terminal.

## Start of a run (moldyn.log)

These checks come from the NewtonX registration that the installer adds. A manual install skips them; the same problems are then caught at the first step.

| Message contains | Cause | What to do |
|---|---|---|
| `TeraChem not found. Set the TeraChem variable to the TeraChem folder` | `$TeraChem` is not set, or `$TeraChem/bin/terachem` is not executable | Set `TeraChem` to the folder that contains `bin/terachem` |
| `needs wavefunction overlaps, which the TeraChem interface does not provide` | `vdoth` in `sh.inp` is 1 or negative | Use `vdoth = 0` for coupling vectors or `vdoth = 2` for TD-BA |
| `Problem in` | `terachem.par` has an error; the message reads `Problem in terachem.par:`, and the rest of the line is one of the [settings file](#settings-file) messages | Fix the key or value it names |

## Dynamics errors (moldyn.log, DEBUG/runnx.error)

### Settings file

| Message contains | Cause | What to do |
|---|---|---|
| `Cannot read this line of` | A line of `terachem.par` is not `key = value` | Write one `key = value` per line; see [terachem.par reference](terachem-par.md#format-and-location) |
| `Unknown option '` | A typo in a key, such as `coupling` for `couplings` | Use a key from the list the message gives |
| `must be 0 or 1, not` | A switch key has another value | Use `0` or `1`, or `yes`/`no` |
| `must be nx, neighbours, current or all, not` | Bad value for [`couplings`](terachem-par.md#couplings) | Use one of the listed values; `neighbors` also works |
| `must be previous or last, not` | Bad value for [`phase_ref`](terachem-par.md#phase_ref) | Use `last` or `previous` |

### Environment and step type

| Message contains | Cause | What to do |
|---|---|---|
| `the NX environment variable is not set.` | `$NX` is not set; this message appears only in `DEBUG/runnx.error` | Set `NX` to NewtonX's `bin` folder |
| `The TeraChem environment variable is not set.` | `$TeraChem` is not set | Set `TeraChem` to the TeraChem installation |
| `TeraChem executable not found at` | `$TeraChem/bin/terachem` is missing or not executable | Check the `TeraChem` variable |
| `needs wavefunction overlaps, which the TeraChem interface does not provide.` | `vdoth` is 1 or negative | Use `vdoth = 0` or `2` |
| `Could not determine dynamics type.` | `TEMP/` has neither `JOB_AD` nor `JOB_NAD` | Check that the trajectory folder has `JOB_NAD/` |

### Geometry, templates and coupling pairs

| Message contains | Cause | What to do |
|---|---|---|
| `Bad line in geom:` | A line of `geom` has fewer than 5 fields | Write `geom` in NewtonX format: symbol, charge, x, y, z (Bohr), mass |
| `atoms but control.d says nat =` | The number of atoms in `geom` differs from `nat` in `control.dyn` | Make `nat` match `geom` |
| `No TeraChem template found.` | No `tera.sp`, and no `GRAD/start.sp`, in `JOB_NAD/` | Put the template in `JOB_NAD/tera.sp`; see [Templates](dynamics.md#templates) |
| `Template input file '` | A template the step needs is missing | Check the files in `JOB_NAD/` |
| `No coupling template (NAD_N1N0/start.sp or NAD_N1N2/start.sp) for the pair` | Three-template layout without any coupling template | Add `NAD_N1N0/start.sp` or `NAD_N1N2/start.sp`, or switch to one `tera.sp` |
| `not found. NX writes it every step from jiri.inp and THRES` | `TEMP/transmomin` is missing | Check `jiri.inp`, or set [`couplings`](terachem-par.md#couplings) to a fixed scheme |
| `Bad state pair (` | `transmomin` lists a state outside 1 to `nstat` | Check `nstat` in `control.dyn` and `jiri.inp` |
| `uses full TDDFT (rpa yes). TeraChem gives no RPA coupling vectors` | `rpa yes` with coupling vectors (`vdoth = 0`) | Use TD-BA (`vdoth = 2`) with RPA, or TDA (`cis yes`) for coupling vectors |
| `asks for no singlets (cassinglets 0) but sets no castargetmult.` | A triplet CAS template without `castargetmult` | Add `castargetmult 3` |
| `found, so the target state cannot be set.` | The template has none of `casscf yes`, `casci yes`, `cis yes`, `rpa yes`, `hhtda yes` | Add the method keyword; see [Method tutorials](methods.md) |
| `castargetmult` … `is not supported.` | The multiplicity is not 1 to 5 | Use a supported multiplicity |

### TeraChem runs and results

| Message contains | Cause | What to do |
|---|---|---|
| `TeraChem failed in` | TeraChem returned an error | Read `TEMP/<job>/tera.out` |
| `TeraChem did not finish in` | The run was killed, for example by a license time limit or the queue | Check the time limit. To continue, copy `INFO_RESTART/control.dyn` over `control.dyn`, raise `tmax` if needed, and run `moldyn.pl` again |
| `TeraChem wrote no scratch folder` | TeraChem finished without writing `scr.geom` | Read the job's `tera.out` |
| `No 'Root Total Energy' table in` | The output has neither the `Root Mult. Total Energy` table of CAS methods and hh-TDA nor the excited-state table of TDA and RPA | Read the gradient job's `tera.out` |
| `No 'FINAL ENERGY' line in` | TDA or RPA output without the ground-state energy | Read the gradient job's `tera.out` |
| `Could not read` … `state energies from` | Fewer states in the output than `nstat`, or the wrong multiplicity | Raise the number of states in the template; check `castargetmult` or `cismult` |
| `not found or empty. The calculation may have failed.` | A gradient or coupling file is missing | Read the job's `tera.out` |
| `Bad line in` | A gradient or coupling file has a line without three numbers | Read the job's `tera.out` |
| `atom lines; expected` | A gradient or coupling file is incomplete | Read the job's `tera.out` |
| `Phase adjustment (escalar) failed.` | NewtonX's `escalar` program failed | Check `$NX/escalar` and the `nad_vectors` and `oldh` files in `TEMP/` |

### Files

These messages end with the system's error text, for example "No space left on device".

| Message contains | Cause | What to do |
|---|---|---|
| `Cannot open`, `Could not open` | A file could not be read | Check that the file exists and that you can read it |
| `Cannot write`, `Could not write` | A file could not be written | Check disk space and permissions in the trajectory folder |
| `Failed to copy`, `Failed to move`, `Failed to archive` | A copy or move inside `TEMP/` or `INFO_RESTART/` failed | Check disk space and permissions |
| `Copy of`, `Copy to`, `Copy from`, `Molden file copy from` | A copy of a NewtonX file failed | Check disk space and permissions |

## Dynamics warnings (moldyn.log)

| Message contains | Cause | What to do |
|---|---|---|
| `TeraChem returned an all-zero coupling vector for states` | TeraChem wrote a zero coupling vector, as it does for RPA | Check that the method gives coupling vectors |
| `in sh.inp, but this interface always fixes the coupling phase` | `getphase` is not 1 under NewtonX 2.4; the interface still corrects the signs | Nothing, or set `getphase = 1` |

## Initial conditions (initcond.pl output, DEBUG/runnx.error)

| Message contains | Cause | What to do |
|---|---|---|
| `the NX environment variable is not set.` | `$NX` is not set | Set `NX` to NewtonX's `bin` folder |
| `The TeraChem environment variable is not set.`, `TeraChem executable not found at` | `$TeraChem` is wrong | Check the `TeraChem` variable |
| `in initqp_input must be different states, both 1 or more.` | `nis` equals `nfs`, or one is below 1 | Fix `nis` and `nfs` in `initqp_input` |
| `No TeraChem template in JOB_AD` | No `tera.sp`, `start.sp` or `GRAD/start.sp` in `JOB_AD/` | Put a template in `JOB_AD/`; see [Initial conditions](initial-conditions.md#templates) |
| `no 'casscf yes', 'casci yes', 'cis yes', 'rpa yes' or 'hhtda yes' found` | The template has no method keyword | Add the method keyword |
| `TeraChem failed.` | TeraChem returned an error | Read `geom.out` |
| `TeraChem did not finish (no 'Job finished' line in` | The run was killed | Check the time limit |
| `Could not read` … `state energies from` | Fewer states in the output than `max(nis, nfs)` | Ask TeraChem for more states of the target multiplicity |
| `No oscillator strength or transition dipole between states` | TeraChem printed neither for the pair | Ask TeraChem for more states, and check the multiplicity |
| `guess file` … `not found; using TeraChem's default guess.` | Not an error: the template's `guess` points to a file that does not exist here | Nothing |

## Terminal

| Message contains | Cause | What to do |
|---|---|---|
| `Unknown option '` (from `--check-options`) | A typo in `terachem.par` | See the [settings file](#settings-file) rows |
| `Give the NewtonX bin folder, or set NX.` | The installer got no folder and `$NX` is not set | Run `perl install/install_nx.pl $NX` |
| `not found. Is` … `the NewtonX bin folder?` | The folder has no `lib/colib_perl.pm` | Give NewtonX's `bin` folder |
| `this does not look like NewtonX 2.4 or 2.6.` | `colib_perl.pm` lacks a subroutine the installer edits | Use NewtonX 2.4 or 2.6, or install by hand; see [Manual install](installation.md#manual-install) |
| `insertion point for` … `not found.`, `unbalanced braces in the old TeraChem check_thirdparty block` | The installer cannot place its block in `colib_perl.pm` | Edit `colib_perl.pm` by hand |
| `The edited colib_perl.pm does not compile; nothing was changed.` | The edit would break NewtonX | Read the compiler output below the message |
| `Cannot back up`, `Cannot replace`, `Cannot copy` | A file in the NewtonX tree could not be written | Check permissions on the NewtonX folder |

## See also

- [Running dynamics](dynamics.md): setup, templates and the keywords the interface manages
- [Output files](outputs.md): where each job's `tera.out` is
- [terachem.par reference](terachem-par.md): every key and its allowed values
