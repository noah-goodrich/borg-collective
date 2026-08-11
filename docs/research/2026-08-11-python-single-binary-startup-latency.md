# Python "compile to single binary" options vs process startup latency

**Date:** 2026-08-11
**Question:** For a Python CLI, which "compile Python to a single binary" options exist as of 2026, and do
any of them actually reduce process startup latency versus running `python3 script.py`?

## Executive summary

- **No packaging/compilation approach reduces CPython process-startup latency below what a bare `python3`
  invocation already achieves.** Every compiler/packager (Nuitka, PyInstaller, cx_Freeze, PyOxidizer, PyApp)
  still boots a real CPython interpreter at process start; several of them measurably ADD overhead (unpacking,
  extra binary size, dynamic linking) rather than removing it.
  [dev.to benchmark](https://dev.to/werner_smit/pythons-startup-tax-when-script-startup-time-becomes-the-bottleneck-2np6)
  [2024-2026]
- **PyOxidizer is dormant, not actively maintained.** Its own GitHub commit history shows the last commits
  landed 2024-11-03; there have been no releases in over a year and the maintainer has not refuted "no
  releases in the past year" community reports. Treat it as effectively unmaintained for new adoption.
  [PyOxidizer repo](https://github.com/indygreg/PyOxidizer) [PyOxidizer discussion #737](https://github.com/indygreg/PyOxidizer/discussions/737)
  [2024, stale into 2025-2026]
- **The user's memory of "transpiles to a rust binary" most closely matches `py2many`** (Python→Rust
  source-to-source transpiler, actively maintained, most recent commit within weeks as of late 2025), NOT
  PyOxidizer (which bundles/embeds a real CPython inside a Rust-built launcher — still an interpreter) and
  NOT RustPython (a from-scratch Python interpreter *implemented in* Rust, explicitly non-production-ready).
  These three are fundamentally different propositions — see Findings §2.
  [py2many](https://github.com/py2many/py2many) [2025]
- **CPython's floor is well below the measured 48.4ms on the target machine.** Independent historical
  benchmarks show `python -S` (skip `site` module) at ~8.4ms on 3.7 and ~3ms on 2.7; modern CPython (3.11+)
  ships frozen stdlib modules by default specifically to cut this further. The 48.4ms figure measured on
  the target machine is dominated by `site`-module and `.pth` processing overhead, not by an irreducible
  interpreter-init floor — meaning there IS headroom, but only via interpreter flags/config, never via
  packaging into a "binary."
  [pythondev startup_time notes](https://pythondev.readthedocs.io/startup_time.html) [historical, 2017 data — directionally still valid]
- **The only credible path to sub-10ms-per-invocation behavior is to stop invoking a fresh interpreter at
  all** — a persistent daemon behind a Unix socket with a thin client, in the spirit of tools like
  `quicken`. A per-request Unix-socket round trip costs roughly 0.1ms; this is the only mechanism found in
  this research that plausibly clears the "<10ms per hook firing" bar. No packaging/compiling approach does.
  [CocoIndex daemon architecture post](https://cocoindex.io/blogs/building-an-invisible-daemon/) [2024-2026]

## Findings

### 1. Enumerated options and maintenance status (2025-2026)

| Tool | What it actually produces | Maintenance status |
|---|---|---|
| **Nuitka** | Transpiles Python to C, compiles to a native binary/extension that still embeds/links a CPython runtime for anything not statically resolved | Active; regular releases through 2025-2026. [Nuitka](https://nuitka.net/user-documentation/performance.html) |
| **PyInstaller** | Bundles interpreter + bytecode + deps into `--onefile` (self-extracting archive) or `--onedir` (folder) | Active, mainstream default choice; issues tracker shows ongoing 2024-2025 work on the onefile unpack-overhead problem. [PyInstaller](https://pyinstaller.org/en/stable/common-issues-and-pitfalls.html) |
| **cx_Freeze** | Similar to PyInstaller — freezes interpreter + deps into an executable dir/onefile | Maintained but lower-profile than PyInstaller/Nuitka as of 2025-2026 comparisons. [2025-2026 comparison](https://ahmedsyntax.com/2026-comparison-pyinstaller-vs-cx-freeze-vs-nui/) |
| **PyOxidizer** | Embeds CPython + in-memory module importer inside a Rust-compiled launcher binary | **Dormant.** Last commits 2024-11-03; no 2025/2026 release activity found; community explicitly flagged "no releases in the past year" with no maintainer rebuttal. [repo](https://github.com/indygreg/PyOxidizer) |
| **PyApp** (ofek/Rust) | A small Rust-built launcher that bootstraps/downloads a real CPython + deps (via `uv`) *at first run*, then executes it | Active as of Oct 2025 docs; NOT a "no-interpreter" solution — it still shells out to a full interpreter after bootstrap. [PyApp docs](https://ofek.dev/pyapp/latest/how-to/) |
| **shiv / pex** | Self-contained zipapps (still require a system Python to execute; pex additionally supports "venv" mode) | pex actively maintained (universal lockfiles work ongoing); shiv lower activity by comparison. [handbook](https://pydevtools.com/handbook/explanation/how-do-i-ship-a-python-application-to-end-users/) |
| **RustPython** | A full Python interpreter *implemented in* Rust (alternative to CPython, not a packager) | Explicitly **not production-ready**; partial language/stdlib coverage, positioned for embedding/WASM use cases, not as a CPython drop-in. [RustPython README/HN discussion](https://news.ycombinator.com/item?id=41139595) |
| **py2many** | Source-to-source **transpiler**: Python AST → Rust/C++/Go/etc. source, then compiled by the target language's own toolchain — the output has NO CPython runtime at all for supported subsets | Active; commits within weeks as of late 2025; Python→Rust and Python→C++ are the most mature targets; explicitly limited to a typed subset of Python (dynamic features, much of the stdlib, and most third-party packages incl. typer/click are out of scope). [repo](https://github.com/py2many/py2many) |
| **Cython (compiled entry points)** | Compiles Python/Cython to a C extension; still runs inside a CPython process for anything importing the extension — does not eliminate interpreter init | Active, standard tool. Not evaluated as a startup-latency lever since interpreter boot is unaffected. |

### 2. Which of these is "a Rust binary" — disambiguating three unrelated things

The user's recollection of "a tool that transpiles Python to a Rust binary" conflates three distinct,
non-interchangeable technologies:

- **PyOxidizer** — takes your *actual CPython interpreter and bytecode* and embeds them, plus an in-memory
  module importer, inside a binary built by Rust's toolchain (Rust is the *packaging* language, not what
  your code becomes). Your Python still runs as Python, interpreted, at runtime. Dormant as of 2025-2026
  (see table above).
- **RustPython** — a *Python interpreter*, analogous to CPython or PyPy, written in Rust. Running your
  script under RustPython means swapping interpreters, not compiling anything. Explicitly not
  production-ready.
- **py2many** — an actual *source-to-source transpiler*: it reads your Python AST and emits real Rust (or
  C++/Go/etc.) source code, which `rustc` then compiles into a genuinely native, interpreter-free binary.
  This is the only one of the three where "no CPython process starts" is literally true — but it only works
  for a constrained, statically-typeable subset of Python, and frameworks like `typer`/`click` (dynamic
  decorators, runtime introspection, C-extension dependencies) are not realistic transpilation targets.
  [py2many README](https://github.com/py2many/py2many/blob/main/README.md)

None of the three is a drop-in "make my existing typer CLI a fast native binary" solution. py2many is the
only one that could theoretically deliver a true interpreter-free binary, but at the cost of rewriting the
CLI logic in a transpiler-compatible Python subset — a much bigger lift than the packaging question implies.

### 3. The key question — startup latency, measured (not vendor claims)

- **PyInstaller `--onefile` increases startup**, confirmed by both PyInstaller's own docs and multiple
  independent reports: onefile mode unpacks the embedded archive to a fresh temp directory (`_MEIxxxxx`) on
  *every* run, adding a fixed overhead on top of interpreter init. Reported deltas in the wild range from
  roughly 2-3x slower vs. `--onedir` for the same app (one user reported 4.5s vs 1.5s cold-start on a
  heavier app; the ratio, not the absolute number, is the transferable signal for a thin CLI).
  [GitHub issue #4563](https://github.com/pyinstaller/pyinstaller/issues/4563)
  [GitHub issue #7907](https://github.com/pyinstaller/pyinstaller/issues/7907) [2024-2025]
- **Nuitka does NOT reduce interpreter-init time; it only speeds up hot loops/compute.** Nuitka's own
  documentation discusses only Pystone-style runtime speedups (3.3-3.7x), with zero discussion of
  startup latency. An independent measured benchmark found a Nuitka-compiled script took **257ms vs 152ms**
  for the equivalent plain Python script — 68% *slower* to start, because the compiled binary still performs
  full CPython interpreter initialization plus extra binary-unpacking/linking overhead.
  [Nuitka docs](https://nuitka.net/user-documentation/performance.html)
  [dev.to benchmark](https://dev.to/werner_smit/pythons-startup-tax-when-script-startup-time-becomes-the-bottleneck-2np6) [2024-2026]
- **PyOxidizer's in-memory importer was a real, narrow win for import-heavy startup (avoiding filesystem
  stat-per-module overhead), but no independent, current (2024-2026) benchmark exists** to confirm it beats
  plain `python3` end-to-end once CPython's own init cost is counted — and the project is dormant, so this
  is moot for new adoption regardless of the historical claim.
- **The practical floor for CPython process startup is well under the 48.4ms measured on the target
  machine**, and it is a *configuration* floor, not an *irreducible* one. Historical (2017, still
  directionally valid — `site`-module cost hasn't grown, and 3.11+ added *more* startup optimization, not
  less) measurements: Python 3.7 with `site` = 14.5ms, Python 3.7 with `-S` (skip site) = 8.4ms; Python 2.7
  numbers were 6.4ms / 3.0ms respectively. CPython 3.11+ ships **frozen stdlib modules by default**, which
  the CPython devs measured as an ~15% startup improvement specifically because it removes filesystem/import
  machinery overhead for stdlib modules used during boot.
  [pythondev startup_time notes](https://pythondev.readthedocs.io/startup_time.html)
  [CPython issue #89183 — freeze modules imported during startup](https://github.com/python/cpython/issues/89183)
  [faster-cpython/ideas #82](https://github.com/faster-cpython/ideas/issues/82)

  The 48.4ms figure on the target machine is most plausibly explained by `site`-module init, `.pth` file
  processing, and/or virtualenv machinery — none of which any "compile to a binary" tool removes, because
  they all still run a full CPython init sequence. `-S` and related flags address exactly this, and no
  packaging tool does.

### 4. Other ways to dodge interpreter startup for a frequently-invoked CLI

- **`python3 -S`** (skip `site` initialization): historically ~40-45% reduction in bare startup time (8.4ms
  vs 14.5ms on 3.7). Caveat: skips `site`, so anything relying on `site`-installed packages / `.pth` paths
  (virtualenvs, most package managers) breaks unless paths are set explicitly — meaningful engineering cost,
  not a free win, for a typer-based CLI installed via pip/uv in a venv.
- **`-X frozen_modules`**: already the CPython 3.11+ default; separately toggling it further is a marginal
  (~3% of total startup per the CPython team's own accounting) lever, not a large one.
- **`PYTHONDONTWRITEBYTECODE`**: affects disk writes, not read/import latency on a warm bytecode cache; no
  material effect on measured startup latency in any source found.
- **Lazy-importing `typer`**: directly addressable from the numbers already in hand — `python3 -c pass`
  (48.4ms) vs `python3 -c "import typer"` (57.1ms) is an 8.7ms delta attributable to typer's import graph
  (click, and typer's own module tree). Deferring the `import typer` to only the code path that needs it
  (e.g., only when parsing CLI args interactively, not on every hook invocation) recovers that 8.7ms
  directly — this is a real, measurable, zero-risk win independent of any packaging decision.
- **Persistent daemon + thin client (Unix socket)**: the one mechanism in this research that changes the
  *order of magnitude*, not just shaves milliseconds. Pattern: a long-lived daemon process loads the
  interpreter/imports once; each CLI invocation is a thin client that connects to a Unix socket, sends a
  request, gets a response, and exits — per-connection overhead measured at roughly 0.1ms, with auto-start-
  on-first-use eliminating any manual daemon-management step. `quicken` (PyPI) is a purpose-built Python
  package implementing exactly this pattern for CLI tools; the general pattern is also documented as
  "invisible daemon" architecture for local dev tools.
  [CocoIndex — invisible daemon architecture](https://cocoindex.io/blogs/building-an-invisible-daemon/) [2024-2026]
  [quicken on PyPI](https://pypi.org/project/quicken) — could not independently re-verify current release
  cadence/maintenance status; page did not render for this research pass. Treat the *pattern* as validated,
  the specific package's current health as unverified.

### 5. Is there a credible path to a Python-based hook under ~10ms?

**Not via any compiled/packaged binary.** Every option surveyed either (a) still boots full CPython
(Nuitka, PyInstaller, cx_Freeze, PyApp, Cython entry points) and therefore inherits the same ~15-50ms class
of interpreter-init cost, or (b) adds unpacking/linking overhead on top of that (PyInstaller onefile, Nuitka
per the measured 257ms case), or (c) is dormant/not production-viable (PyOxidizer, RustPython) or requires
rewriting the CLI logic in a restricted transpilable subset that excludes the frameworks already in use
(py2many).

The two levers that *do* stack toward "<10ms":
1. `python3 -S` plus lazy-importing heavy frameworks — gets you from ~48-57ms into roughly the 10-25ms
   range based on the historical `-S` ratio, still short of 10ms and with a real engineering cost (site
   customization) for anything installed in a venv.
2. A resident daemon + thin socket client — this is the only approach in the evidence base that plausibly
   clears 10ms per invocation, because the "hot path" for a hook firing on every tool call is no longer
   "start an interpreter," it's "make one socket round trip to an already-warm process."

**Bottom line for the architecture decision:** compiling/packaging Python does not fix CPython startup —
say this plainly, it is the load-bearing finding. If the exclusion of frequently-firing hooks from the
Python migration was based on the assumption that a compiled binary could close the ~34ms gap to `zsh -c
true`, that assumption is not supported by any evidence found here. The only mechanism that would
legitimately reopen that architectural question is a persistent daemon/thin-client redesign — a materially
different (and more complex, stateful) architecture than "just compile it," not a drop-in packaging swap.

## Evidence gaps and uncertainties

- No independent, current (2024-2026) benchmark of PyOxidizer's in-memory importer was found; its claimed
  startup advantage is unverified either way, and moot given dormancy.
- `quicken`'s PyPI page could not be fetched in this pass; its current maintenance status is unverified —
  the daemon/thin-client *pattern* is corroborated by a separate independent source, but the specific
  package's health is not.
- CPython `-S` numbers cited are from 2017 (Python 2.7/3.7); no 2024-2026 remeasurement of `-S` specifically
  was found, though the mechanism (skipping `site`) has not changed and 3.11+'s frozen-modules work is
  additive to, not a replacement for, that saving. Treat the *ratio* (roughly halving startup) as
  directionally reliable, the absolute ms figures as dated.
- No direct measurement was found of PyInstaller `--onedir` (non-onefile) startup overhead in absolute ms
  for a thin/typer-scale CLI specifically — only relative/anecdotal ratios for larger apps (ML, Flask). The
  qualitative conclusion (onedir avoids the unpack penalty; onefile does not) is well corroborated, but a
  precise ms number for a typer-scale CLI was not found.

## Paywalled must-reads

None identified — all load-bearing sources for this track were openly accessible.

## Sources index

| # | Title | URL | Date | Tier |
|---|-------|-----|------|------|
| 1 | PyOxidizer GitHub repo (commit history) | https://github.com/indygreg/PyOxidizer | 2024 (last commit) | [2024-2026, stale] |
| 2 | PyOxidizer discussion #737 — project status | https://github.com/indygreg/PyOxidizer/discussions/737 | 2024 | [2020-2023 boundary, effectively 2024] |
| 3 | Python's Hidden Bottleneck (dev.to, measured startup benchmarks) | https://dev.to/werner_smit/pythons-startup-tax-when-script-startup-time-becomes-the-bottleneck-2np6 | 2024-2026 | [2024-2026] |
| 4 | Nuitka Performance docs | https://nuitka.net/user-documentation/performance.html | 2025-2026 | [2024-2026] |
| 5 | PyInstaller — Initial startup time with --onedir (issue #4563) | https://github.com/pyinstaller/pyinstaller/issues/4563 | 2019-2024 thread | [2020-2023, still open/active] |
| 6 | PyInstaller — avoid repeated unpacking (issue #7907) | https://github.com/pyinstaller/pyinstaller/issues/7907 | 2023-2025 | [2024-2026] |
| 7 | 2026 Showdown: PyInstaller vs cx_Freeze vs Nuitka | https://ahmedsyntax.com/2026-comparison-pyinstaller-vs-cx-freeze-vs-nui/ | 2026 | [2024-2026] |
| 8 | pythondev — Python Startup Time notes | https://pythondev.readthedocs.io/startup_time.html | 2017 data | [pre-2020, foundational, still cited by CPython devs] |
| 9 | CPython issue #89183 — freeze modules imported during startup | https://github.com/python/cpython/issues/89183 | 2021-2024 | [2020-2023] |
| 10 | faster-cpython/ideas #82 — freeze/link stdlib modules | https://github.com/faster-cpython/ideas/issues/82 | 2021-2022 | [2020-2023] |
| 11 | PyApp docs (ofek.dev) | https://ofek.dev/pyapp/latest/how-to/ | Oct 2025 | [2024-2026] |
| 12 | pydevtools handbook — shipping Python apps | https://pydevtools.com/handbook/explanation/how-do-i-ship-a-python-application-to-end-users/ | 2025 | [2024-2026] |
| 13 | RustPython HN discussion + README | https://news.ycombinator.com/item?id=41139595 | 2024 | [2024-2026] |
| 14 | py2many GitHub repo | https://github.com/py2many/py2many | active, late 2025 | [2024-2026] |
| 15 | CocoIndex — Invisible Daemon architecture pattern | https://cocoindex.io/blogs/building-an-invisible-daemon/ | 2024-2026 | [2024-2026] |
| 16 | quicken (PyPI) — daemon-client CLI accelerator | https://pypi.org/project/quicken | unverified in this pass | unverified |
