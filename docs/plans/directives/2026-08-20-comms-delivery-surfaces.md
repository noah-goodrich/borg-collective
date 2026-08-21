# Directive: Comms Delivery Surfaces

*Filed: 2026-08-20 · Status: Proposed · Parent: 2026-08-20-communication-program.md*

**tl;dr** — There is no standard way to put a document beside the conversation, regenerate the PR-chain map,
or keep chat replies in the shape Noah actually reads. Build three small delivery mechanisms in borg:
`borg show`, `borg chains`, and a chat-format contract enforced at response time.

## Problem

The 2026-08-18/20 prototypes proved the mechanics work (nvim side pane loaded via tmux, a linked chain map
from live recon data) but both were hand-driven one-offs. Nothing in borg can repeat them, so they will not
happen again without this directive.

## Solution

- **S1 — `borg show <file> [line]`.** Open a file in the current window's nvim side pane. Mechanics: find a
  pane running nvim in the caller's window; send Escape, then `:e +<line> <file>`, then Enter as separate
  `send-keys` calls (bundled Enter becomes a literal newline; see tmux memory). No nvim pane: split one
  (reuse `drone pane` logic). Exit nonzero only when tmux itself is absent.
  **HARD REQUIREMENT: resolve the window from `$TMUX_PANE` (the calling pane's own id), never from the
  client's active window.** Proven failure 2026-08-20: the borg:5 drone asked tmux for "the current window",
  got the window the USER was looking at (borg:4), and overwrote another session's nvim buffer. A bats test
  must cover the two-sessions-two-windows case.
- **S2 — `borg chains`, terminal-first.** One data pipeline (recon since-mark → gather with declared edges,
  `--programs-dir` resolved from the registry, closing #158's known gap → chain JSON), three renderers in
  strict priority order:
    1. **Default: ANSI to stdout.** Vertical, merge order top to bottom, generous spacing, color state
       tags, OSC-8 hyperlinks on refs (Ghostty-clickable; degrades to plain text). Reading size is the
       terminal's own font — that is the accessibility feature, not a limitation.
    2. **`--md`:** reading-first markdown written to `~/.local/state/borg/merge-tree/chains.md` and opened
       in the window's nvim side pane via S1. No inline URLs in the reading flow; gx-able link index at the
       bottom.
    3. **`--html [--open|--publish]`:** explicit request only. Self-contained file opened locally
       (enterprise Claude Code has no artifact-publish tool); browser context-switch is a flow breaker, so
       HTML is never the default. Small mono type is rejected; if HTML renders, body type is large sans.
  Horizontal chains with arrows tested poorly and are rejected everywhere. Prototypes to productize:
  `~/.local/state/borg/merge-tree/prototypes/` (2026-08-20 session).
  Format requirements from review: each program carries a one-sentence `desc` under its heading; each lane
  gets a one-line summary (counts + next ref); repos listed in full; an "At a glance" strip at the top (one
  row per lane, one cell per PR, `>` marking next). Refs are always the FULL `owner/repo#num` form — they
  are self-addressing (see S5).
  **ONE treatment for every program: the topological grid, picture first, always vertical.** A linear
  chain is a one-column DAG — no separate rail rendering (Noah, 2026-08-20: the common case is one PR
  fanning out to several that all go ready simultaneously, which a rail cannot express). Rows are levels
  (time flows down), columns are branches, box-drawing connectors, state glyphs per node; compact nodes
  (glyph + id + full ref) in the picture, "Node details" blocks below. Every node gets a short unique id
  (n1, n2 …) appearing EXACTLY twice — picture and its detail heading — so vim `*` toggles picture ↔
  detail with no plugin; detail blocks carry full refs so `gp` opens the PR. "Next" is a SET: READY =
  open AND every parent merged; all READY nodes are announced together.
  Approved mock (fork case): `~/.local/state/borg/merge-tree/chains-dag-mock.md`. True forks need one
  manifest addition: row-level `after: [refs]`, since lanes only express linear tracks.
- **S5 — self-addressing refs + editor keymap.** Generated docs never embed URLs in the reading flow; the
  ref itself is the address. The `gp` nvim keymap (shipped 2026-08-20 in dotfiles
  `nvim/lua/custom/plugins/overrides.lua`) opens `owner/repo#num` under the cursor in the browser, and bare
  `#num` via `gh pr view --web` in the buffer's repo. A URL index stays at the bottom of generated docs as
  fallback only.
- **S3 — chat contract.** A delivery skill (installed via `borg setup`) that enforces: short body, bold only
  load-bearing figures, `file:line` references for jump targets, and a two-line tl;dr at the BOTTOM of chat
  replies (documents carry it at the top). Source principles: front-load the point, state why it matters,
  push depth to "go deeper" links, conditions before instructions (developers.google.com/style/tone,
  /style/highlights; Smart Brevity method unbranded, flattening-critique respected).
- **S4 — promote the PoC manifests.** Add `!.borg/programs/` to `.gitignore` (and document the carve-out for
  consuming repos), then land the two hand-authored manifests (`ingle-t1-cutover`, `viz-program`) in their
  owning repos so S2 has real declared edges on day one. When S4 lands, re-file manifest-driven chain
  position for `/pr-description` in claude-plugins (its plan deferred it on "no manifests exist yet").
- **S6 — every status surface adopts or is exempted, by name.** (Added 2026-08-20 after the gap sweep;
  Noah: "this new rendering would inform the way that all enquiries about status, de-briefings, borg-link,
  etc" — that is the adopt decision for the big surfaces.) Inventory:

  | Surface | Decision |
  |---|---|
  | `borg link` overview + deep (borg_core/link/render.py, /borg-link skill) | ADOPT: glance strip + derived status; goldens regenerated; engine and skill skeletons updated in one change |
  | /borg-recon briefing skeleton | ADOPT: S3 contract + full refs |
  | /borg-link-up checkpoint template | ADOPT: tl;dr at top, full refs (see deriver directive for the state-restatement shrink) |
  | /borg-next, `borg next` CLI | ADOPT: full refs; S3 skip-threshold applies (short replies carry no tl;dr block) |
  | orchestrator SessionStart overview, `borg watch`, `drone status`, `borg nanoprobes` | EXEMPT for now: operational glances, revisit after S1-S5 ship |
  | merge-tree `render.py` + `render_graph.py` HTML | SUPERSEDED by `borg chains --html`; sever when S2 ships (zero consumers measured) |

  Precedence rule: the S3 chat contract wins over any per-skill output skeleton; skills reference it
  rather than restating format rules (single source: K2's portable spine in claude-plugins).

## Acceptance criteria

- [ ] AC1 `borg show README.md 40` opens nvim in the side pane at line 40 from a bare window and from a
      window that already has an nvim pane; bats-tested against a scripted tmux session.
- [ ] AC2 `borg chains` produces the map from live recon with zero dangling endpoints on the shipped
      manifests; a fixture test drives recon-doc → HTML without network.
- [ ] AC3 The chat-contract skill exists, is installed by `borg setup`, and its rules match the parent
      directive's reading-mechanics findings (tl;dr at bottom for chat, top for documents).
- [ ] AC4 `.gitignore` carve-out landed; `git check-ignore .borg/programs/x.json` fails (not ignored); both
      manifests committed in their repos.
- [ ] AC5 Full bats suite and macOS contract leg green.
- [ ] AC6 A fixture manifest using row-level `after: [refs]` renders the fork/join grid of the approved
      mock (branch columns, join, READY-set announced together). Schema addition owned by S2, spec'd in
      SCHEMA.md on the rider branch.
- [ ] AC7 The S6 inventory is enforced: adopted surfaces render the house grammar (goldens regenerated),
      superseded renderers severed, and every exemption is a line in this file, not an omission.

## Non-Goals

- Not the directive-state deriver (separate directive per the audit; S2 consumes it later).
- Not merging #158 wholesale; S2 needs only `programs.py` + the registry-resolved `--programs-dir` caller.
- Not auto-refresh, not hooks that interrupt; regeneration is explicit.

## Alternatives Considered

- **Web-first delivery for everything**: rejected, parent's Non-Goals; terminal context wins for reading.
- **Pipe docs through `less` in the chat pane**: rejected; loses the conversation while reading, which is the
  exact failure being fixed.
- **A tmux popup instead of the nvim pane**: rejected for v1; popups steal focus and vanish on keypress,
  and the nvim pane already exists in every drone window.
