#!/usr/bin/env python3
"""build-specimens.py — prepare comprehension-check specimens for the infoviz program.

Both specimens are rendered against SHUFFLED fixture data, not live data. That is the whole point:
the viewer (usually Noah) knows the layout of these artifacts by heart, so a test against live data
measures recall, not comprehension. Randomising which project is urgent restores most of the test's
validity for an insider — they know the design, they do not know the answer.

Writes everything to out/ (gitignored):
    out/story-lens.html   the Story-Lens hub, rendered against a shuffled story.json
    out/borg-ls.html      `borg ls` output against a fixture registry, ANSI converted to HTML
    out/specimens.js      metadata the harness loads (NO answer key)
    out/answer-key.json   what the right answers actually are -- written silently, never printed

The answer key is deliberately kept out of stdout and out of specimens.js so that running this
script in a terminal the viewer can see does not leak the thing being tested.

Usage:
    python3 docs/infoviz/harness/build-specimens.py --seed 7
    cd docs/infoviz/harness/out && python3 -m http.server 8765
    open http://localhost:8765/comprehension-check.html
"""
import argparse
import json
import os
import random
import re
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
DEFAULT_RENDERER = os.path.expanduser(
    "~/.local/state/borg/worktrees/borg-collective/lens-live/merge-tree/render_graph.py"
)
DEFAULT_STATE = os.path.expanduser("~/.local/state/borg/merge-tree")

# The handful of SGR codes borg ls actually emits. Anything else is dropped rather than guessed at.
SGR = {
    "0": None,  # reset
    "1": "font-weight:700",
    "2": "opacity:.55",
    "36": "color:#3fb3c4",
    "0;36": "color:#3fb3c4",
}


def ansi_to_html(text):
    """Convert the SGR subset borg ls uses into nested spans. Unknown codes are dropped."""
    out, depth = [], 0
    pos = 0
    for m in re.finditer(r"\x1b\[([0-9;]*)m", text):
        out.append(_esc(text[pos:m.start()]))
        pos = m.end()
        code = m.group(1)
        if code in ("", "0"):
            out.append("</span>" * depth)
            depth = 0
        elif code in SGR and SGR[code]:
            out.append('<span style="%s">' % SGR[code])
            depth += 1
    out.append(_esc(text[pos:]))
    out.append("</span>" * depth)
    return "".join(out)


def _esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def shuffle_story(story, rng):
    """Permute project priority order and plant needs_you on exactly one workstream.

    Live story.json contains ZERO needs_you flags, so the needs-you treatment that Phase 1's fix 1
    rebuilt never fires on real data. Planting one is required for checks 1 and 3 to be testable at
    all -- and it is the honest test: put the signal somewhere random and see if it is noticed.
    """
    projects = list(story.get("projects", []))
    rng.shuffle(projects)
    for i, p in enumerate(projects, start=1):
        p["priority"] = i
        for ws in p.get("workstreams", []) or []:
            ws.pop("needs_you", None)

    # Plant the signal on a project that is NOT rank 1, so "it's just the top card" doesn't win by
    # accident. Prefer a workstream that isn't blocked, so needs-you and blocked-red compete rather
    # than coincide -- that competition is exactly what check 3 is testing.
    candidates = [p for p in projects[1:] if p.get("workstreams")]
    target = rng.choice(candidates) if candidates else projects[0]
    wss = target["workstreams"]
    preferred = [w for w in wss if w.get("state") != "blocked"] or wss
    chosen = rng.choice(preferred)
    chosen["needs_you"] = True

    story["projects"] = projects
    return story, {
        "needs_you_project_id": target.get("id"),
        "needs_you_project_name": target.get("name"),
        "needs_you_project_rank": target.get("priority"),
        "needs_you_workstream": chosen.get("title"),
        "needs_you_next_action": chosen.get("next_action"),
    }


def build_registry(rng):
    """A fixture registry with a real answer to 'what needs your attention?'

    Live borg ls currently shows 20/20 projects idle, so check A has no correct answer to find. The
    fixture plants one waiting and one active project among idles, at a random position.
    """
    names = [
        "keypair-migration", "ai-rbac-remediation", "sme-self-service-pat", "self-service-snowpipe",
        "dcm-cutover-option-c", "dbt-eval-program", "borg-pr-hub-tooling", "segment-transforms",
        "data-eng-dags", "permifrost", "dbtguard", "o-vault",
    ]
    rng.shuffle(names)
    waiting, active = names[0], names[1]
    projects = {}
    for i, n in enumerate(names):
        if n == waiting:
            status, last, summary = "waiting", "2026-08-10T18:40:00Z", "Blocked on review from a colleague"
        elif n == active:
            status, last, summary = "active", "2026-08-10T19:10:00Z", "Mid-refactor, tests failing"
        else:
            status = "idle"
            last = "2026-0%d-%02dT12:00:00Z" % (rng.randint(4, 7), rng.randint(1, 28))
            summary = None
        projects[n] = {
            "path": "/Users/noahgoodrich/dev/%s" % n,
            "status": status,
            "last_activity": last,
            "summary": summary,
        }
    return {"projects": projects}, {
        "waiting_project": waiting,
        "active_project": active,
        "n_idle": len(names) - 2,
    }


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--seed", type=int, default=None,
                    help="RNG seed. Omit for a fresh unpredictable run; set for reproducibility.")
    ap.add_argument("--renderer", default=DEFAULT_RENDERER, help="path to render_graph.py")
    ap.add_argument("--state", default=DEFAULT_STATE, help="merge-tree state dir (story/data json)")
    args = ap.parse_args()

    seed = args.seed if args.seed is not None else random.SystemRandom().randint(1, 10**9)
    rng = random.Random(seed)

    if not os.path.exists(args.renderer):
        sys.exit("render_graph.py not found at %s\n"
                 "It lives on the feature/hub-story-lens branch (PR #104), not on main.\n"
                 "Pass --renderer <path> or check out that branch in a worktree." % args.renderer)

    os.makedirs(OUT, exist_ok=True)
    key = {"seed": seed}

    # ---- Specimen 1: Story-Lens against shuffled data -------------------------------------
    with open(os.path.join(args.state, "story.json")) as f:
        story = json.load(f)
    story, story_key = shuffle_story(story, rng)
    key.update(story_key)

    shuffled_path = os.path.join(OUT, "story.shuffled.json")
    with open(shuffled_path, "w") as f:
        json.dump(story, f)

    subprocess.run(
        [sys.executable, args.renderer,
         "--story", shuffled_path,
         "--data", os.path.join(args.state, "data.json"),
         "--out", os.path.join(OUT, "story-lens.html")],
        check=True, stdout=subprocess.DEVNULL,
    )

    # ---- Specimen 2: borg ls against a fixture registry -----------------------------------
    registry, reg_key = build_registry(rng)
    key.update(reg_key)

    fixture_home = os.path.join(OUT, ".fixture-config")
    borg_dir = os.path.join(fixture_home, "borg")
    shutil.rmtree(fixture_home, ignore_errors=True)
    os.makedirs(borg_dir, exist_ok=True)
    with open(os.path.join(borg_dir, "registry.json"), "w") as f:
        json.dump(registry, f)

    env = dict(os.environ, XDG_CONFIG_HOME=fixture_home)
    env.pop("TMUX", None)  # don't let live tmux windows leak status into the fixture
    proc = subprocess.run(["borg", "ls"], env=env, capture_output=True, text=True)
    raw = proc.stdout or ""
    if not raw.strip():
        sys.exit("borg ls produced no output against the fixture registry.\nstderr: %s" % proc.stderr)

    with open(os.path.join(OUT, "borg-ls.html"), "w") as f:
        f.write(ansi_to_html(raw))
    key["borg_ls_line_count"] = len(raw.splitlines())

    # ---- Harness metadata (deliberately excludes the answer key) --------------------------
    with open(os.path.join(OUT, "specimens.js"), "w") as f:
        f.write("window.SPECIMENS_BUILT = %s;\n" % json.dumps({"seed": seed}))

    with open(os.path.join(OUT, "answer-key.json"), "w") as f:
        json.dump(key, f, indent=2)

    shutil.copy(os.path.join(HERE, "comprehension-check.html"),
                os.path.join(OUT, "comprehension-check.html"))

    # Print only what is safe to show the viewer. The answer key is NOT echoed.
    print("built specimens in %s" % OUT)
    print("  story-lens.html   (shuffled projects, needs-you planted)")
    print("  borg-ls.html      (fixture registry, %d lines)" % key["borg_ls_line_count"])
    print("  answer-key.json   (written, not printed -- do not open before running)")
    print()
    print("run:  cd %s && python3 -m http.server 8765" % OUT)
    print("open: http://localhost:8765/comprehension-check.html")


if __name__ == "__main__":
    main()
