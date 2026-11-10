[Home](../README.md) / Installation

# Installation

This page shows how to install the interface into NewtonX, what the installer changes, how to install by hand, and how to check the install. Read it before your first run, and again when you update the interface.

## Automatic install

```bash
git clone https://github.com/Matsika-Lab/newtonx-terachem-interface.git
cd newtonx-terachem-interface
perl install/install_nx.pl --dry-run $NX   # shows what would change
perl install/install_nx.pl $NX             # installs
```

`$NX` is NewtonX's `bin` folder. If you leave it out, the script uses the `NX` environment variable.

| Flag | Effect |
|---|---|
| `--dry-run` | Show every change, write nothing |
| `--no-tests` | Do not add the NewtonX test case or its `test_list` entry |

You can run the installer again after an update. It replaces its own earlier changes instead of adding a second copy.

## What the installer changes

- **Scripts:** copies `run-tera-cas.pl` and `run_tera_ic.pl` into `$NX/` with mode 755.
- **`$NX/lib/colib_perl.pm`:** registers TeraChem as `prog = 21.0`. It changes four subroutines:
  - **`prog_config`:** the program entry, which points NewtonX to both scripts and to `terachem.par`.
  - **`check_thirdparty`:** checks `$TeraChem` and `vdoth` (0, 1 or 2) when a run starts, then validates and prints `terachem.par`.
  - **`read_credits`:** the credit line printed in NewtonX output.
  - **`test_list`:** the test `MD-TERA-CASSCF-NAD-VEC`, when the test is added.
- **Test:** copies the test inputs and reference results into `$NX/../test-nx/`. If that folder does not exist, the test is not added.
- **Backups:** every file it replaces is first saved as `<file>.bak.<date-time>`.
- **Older entries:** removes older hand-made TeraChem blocks for `prog = 21.0`. Blocks for other programs are not touched.

The edits in `colib_perl.pm` sit between `>>> newtonx-terachem-interface` marker comments. The edited file is compile-checked before it is written.

## Manual install

If you cannot run the installer, do the minimum by hand.

1. Copy both scripts into `$NX/` and make them executable:

   ```bash
   cp run-tera-cas.pl run_tera_ic.pl $NX/
   chmod 755 $NX/run-tera-cas.pl $NX/run_tera_ic.pl
   ```

2. Add this block to `prog_config` in `$NX/lib/colib_perl.pm`, just before `return %progconf;`:

   ```perl
     if (($prog >= 20.95) and ($prog < 21.05)){
         %progconf=(progname   => "terachem",
                    methodname => "terachem",
                    ic         => "y",
                    dyn        => "y",
                    hyb        => "n",
                    ip         => "n",
                    key        => sprintf("%4.1f",21.0),
                    label      => "TeraChem",
                    method     => "CASSCF/FOMO-CASCI/TDA/hh-TDA/RPA",
                    parfile    => "terachem.par",
                    nad_exec   => "y",
                    lvprt_d    => 1,
                    vdoth_d    => 0,
                    never_state_d  => 0,
                    cio_options_d  => "NULL",
                    cisc_options_d => "NULL",
                    cprog_d    => 0,
                    progic     => "run_tera_ic.pl",
                    progdyn    => "run-tera-cas.pl");
       }
   ```

A manual install skips the startup checks and the NewtonX test. The interface still checks `terachem.par` and the TeraChem path at every call, and `vdoth` at every nonadiabatic step.

## Check the install

- **Options reader:** in a folder without `terachem.par`, `$NX/run-tera-cas.pl --check-options` should print the default options.
- **NewtonX test:** run `$NX/test-nx.pl` and pick `MD-TERA-CASSCF-NAD-VEC`. It needs a GPU and about one minute ([Validation](validation.md#12-installer)).
- **Unit tests:** see [Development and testing](development.md#unit-tests). They need no GPU.

## Program key and license

`prog = 21.0` is not an official NewtonX key. The NewtonX team assigns keys to interfaces that join the official distribution. Joining requires a GPL license. This repository is licensed under GPL-3.0-or-later, so it meets that condition.

## See also

- [Your first trajectory](first-trajectory.md): the next step after the install
- [Troubleshooting](troubleshooting.md#terminal): installer messages
- [Development and testing](development.md): unit tests and the NewtonX test case
