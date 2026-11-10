[Home](../README.md) / Documentation style

# Documentation style

This style is shared by the NewtonX interfaces of the Matsika Lab: [nx-qchem-interface](https://github.com/Matsika-Lab/nx-qchem-interface) and [newtonx-terachem-interface](https://github.com/Matsika-Lab/newtonx-terachem-interface). Both repositories keep the same copy of this file. Change it in both, or in neither.

## Principles

- **The README is minimal.** It says what the interface does, how to install it and run a first trajectory, and where everything else is.
- **One home for every number.** Benchmarks, timings and validation runs live in `docs/validation.md`. User pages state the behavior, and give at most a typical figure with a link to it, such as `about 60 s per step on 4 cores ([Validation](validation.md#coupling-modes))`. Example READMEs describe their own run and may give its numbers.
- **Every claim is checked.** A statement about behavior is backed by a test, a run or the source. Features that have not been run are marked "(untested)".
- **Say which NewtonX version.** Where NewtonX 2.4 and 2.6 behave differently (phase correction, interpolation files, output names), a page states which version each statement was checked on.
- **Defaults are always findable.** A user page that mentions a setting gives its default, or links to its row in the settings reference.
- **Written for the user of today.** The code is unpublished: no upgrade or migration notices, no "new", "now" or "fixed" in user pages. History goes in `CHANGELOG.md`.

## Repository layout

| Path | Contents |
|---|---|
| `README.md` | See [README](#readme) |
| `CHANGELOG.md` | Changes per version, [Keep a Changelog](https://keepachangelog.com/) format, ISO dates |
| `CITATION.cff` | Citation metadata, schema-valid |
| `LICENSE` | GPL-3.0-or-later |
| `docs/installation.md` | Install, what the installer changes, manual install, check, update |
| `docs/first-trajectory.md` | Tutorial: from a molecule to a running trajectory |
| `docs/methods.md` or `docs/methods/` | Method tutorials; one page per method, or one section per method on one page |
| `docs/<prog>-par.md` | Reference of the interface's settings file (`qchem.par`, `terachem.par`) |
| `docs/initial-conditions.md` | Initial conditions and spectra |
| `docs/outputs.md` | Output files and plots |
| `docs/troubleshooting.md` | Error messages and what to do |
| `docs/validation.md` | Benchmarks and validation runs; figures and data in `docs/validation/` |
| `docs/development.md` | Tests, replay harness, how to add a test |
| `docs/STYLE.md` | This file |
| `examples/` | Complete inputs or trajectories, each folder with a `README.md` |

Further topic pages (for example `couplings.md` or `dynamics.md`) are fine. File names are lowercase with hyphens.

## README

Sections, in this order:

1. **H1:** `NewtonX–<Program> interface`, optionally followed by a short subtitle.
2. **What it does:** one or two sentences.
3. **Requirements:** table `Software | Version`, with a last row `Environment` for the variables (`$NX`, …). Tested versions are named, for example "2.4 (build 06) or 2.6 (build 01)".
4. **Quick start:** one bash block from `git clone` to the installer, then numbered steps to a running trajectory, with its cost and duration.
5. **Methods:** a table, `Method | Program keyword | Couplings | Tutorial`, plus one sentence on limits.
6. **Where to go next:** table `I want to… | Read`, one row per page under `docs/` and one for `examples/`.
7. **Examples:** one sentence and a link to `examples/README.md`, or a short table `Folder | Molecule | Method | States`.
8. **Credits, citation and license:** bullets, see [Credits](#credits).

## Page anatomy

- **Line 1, breadcrumb:** `[Home](../README.md) / Page title`, or `[Home](../../README.md) / [Methods](README.md) / EOM-IP-CCSD` one level down. The last label equals the H1.
- **H1, then a short intro paragraph** saying what the page covers and when you need it.
- **Headings** are sentence case and name the topic ("Coupling signs", "After a hop"), never "Overview" or "Introduction".
- **The page ends with `## See also`**: 2 to 4 links with a few words each.

### Method tutorials

Every method has the same parts, in this order. They are `##` headings on a page per method, or `###` headings under the method's `##` on a shared page.

1. **When to use it:** one or two sentences, as a `>` blockquote, with a "Couplings:" line.
2. **Keywords:** table `Keyword | Example value | Meaning`, including the reference and the states.
3. **Couplings allowed:** coupling vectors, TD-BA couplings, or both.
4. **Template:** the method block, with a link to the full template file.
5. **Settings:** the settings file keys that matter for this method.
6. **Pitfalls:** what goes wrong, and how you notice it.
7. **Cost:** one typical figure, with a link to `docs/validation.md`; no benchmark tables.

### Settings reference (`docs/<prog>-par.md`)

- An example file first, then the format rules (`key = value`, comments).
- Summary table: `Key | Default | Allowed values | Methods | Effect`. Each key links to its own section. Leave out `Methods` when every key applies to every method.
- One `###` section per key: what it does, when to change it, an example.

### Troubleshooting

Table `Message contains | Cause | What to do`. "Message contains" quotes the fixed part of the message, copied from the code and without values, so it matches every instance and you can grep the source for it. Group the rows by where the message appears (`nx.log`, `DEBUG/runnx.error`, terminal).

### Validation (`docs/validation.md`)

- A summary table first: `# | Test | What it checks | Key number | Result`.
- Then one numbered `##` section per test: **Purpose**, **Setup**, a results table or figure, and a one-sentence **Conclusion**.
- Every section names the interface commit or version and the NewtonX and electronic-structure program versions it ran with.
- Every timing gives its conditions: cores and node load.

### Example READMEs

H1 with the molecule and method, one paragraph saying what the run shows, a settings table (`Setting | Value`), a **Result** section (figure, then bullets with a bold lead-in), and a files table `Path | Contents`.

## Writing

- American English in prose (behavior, license). Code keywords and values stay exactly as the program defines them (`neighbours`).
- Plain, short, declarative sentences in the present tense. Address the reader as "you".
- No marketing words ("powerful", "seamless", "simply"), and no "fixes" in user pages.
- Bullets start with a bold lead-in phrase when they are more than a few words: `- **Hops.** 3 → 2 at 10.25 fs, …`.
- Use tables for settings, requirements, files and error messages, and prose for explanations.
- Say why a step matters when it is not obvious, in one sentence.

## Terms

| Use | For | Not |
|---|---|---|
| active state | The state the trajectory moves on (`nstatdyn`) | current state, running state |
| coupling vectors | Nonadiabatic coupling vectors from the electronic-structure program (`vdoth = 0`); "NAC" only in keywords and file names | NACs, NACMEs |
| TD-BA couplings | Time-dependent Baeck-An couplings that NewtonX computes from energies (`vdoth = 2`); spell out "time-dependent Baeck-An (TD-BA)" at first use on each page | Baeck-An alone, BA |
| hop | A surface hop | jump, except when quoting NewtonX |
| step | One NewtonX time step | iteration |
| interface call | One call of the run script by NewtonX; a step with a hop has two | |
| version | Semantic version, for example 2.0.0 | |

## Formatting

- **Code:** keywords, file names, paths, commands and values in backticks. Code blocks always name a language (`bash`, `text`, `perl`, `python`). Comments in commands are short and follow `#`.
- **Links:** relative within the repository, with descriptive text, never "here".
- **Math:** inline `` $`...`$ ``, display math in ` ```math ` blocks (GitHub needs these forms when the math contains underscores). Use `\mathrm`, not `\operatorname`, which GitHub does not render.
- **Units:** always given (fs, eV, bohr⁻¹, a.u., Å). Unicode for subscripts, superscripts and arrows (CH₄⁺, 10⁻³, 3 → 2), en dashes for ranges (3–4 hours) and in names (NewtonX–Q-Chem).
- **Alerts:** GitHub alerts (`> [!WARNING]`, `> [!IMPORTANT]`, `> [!NOTE]`) only for something that breaks a run without an error message. At most one per page.
- **Dates:** ISO (2026-11-09) in the changelog and credits; month and year (November 2026) in prose.

## Credits

The README credits section has these bullets:

- **Authors:** names, Matsika Lab, Department of Chemistry, Temple University, and the template the interface is built on.
- **AI use:** "The 2026-11-09 revision (version X) was refactored and improved with Claude Code (Anthropic), using the Claude Opus 5.5 model." Never "written with". Then three sub-bullets:
  - **What it covered:** a short list.
  - **Decisions:** "the authors made the design decisions".
  - **Commits:** "the commits of this revision carry `Co-Authored-By: Claude` lines".
- **Citation:** link to `CITATION.cff`, and ask users to also cite NewtonX and the electronic-structure program.
- **License:** "GPL-3.0-or-later, see `LICENSE`", with `LICENSE` linked to the license file.

Every script has `# SPDX-License-Identifier: GPL-3.0-or-later` on line 2.

## See also

- [GitHub Markdown](https://docs.github.com/en/get-started/writing-on-github): alerts and math syntax
- [Keep a Changelog](https://keepachangelog.com/)
