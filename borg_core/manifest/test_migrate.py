"""The pure planner. Facts are hand-built here ON PURPOSE and only here: the decision ladder is a function
of its inputs. Whether the shell gathers those inputs correctly from a REAL repository is
`test_migrate_shell.py`'s job, which builds real throwaway git repositories and lets `gather` derive
every fact, so no test there hands the planner an answer production derives.
"""

from __future__ import annotations

import ast
import pathlib

import pytest

from borg_core.manifest import migrate

CHAINS = ".borg/chains"
PROGRAMS = ".borg/programs"


def _facts(path="/r", chains=(), programs=(), stacks=(), **overrides):
    """Facts for a clean top-level repository whose three directories hold the given names."""
    kinds = {CHAINS: "directory", PROGRAMS: "directory", migrate.STACKS_DIR: "directory"}
    listings = {CHAINS: tuple(chains), PROGRAMS: tuple(programs), migrate.STACKS_DIR: tuple(stacks)}
    fields = {"kinds": kinds, "listings": listings}
    fields.update(overrides)
    return migrate.Facts(path, **fields)


def _nul(*tokens):
    return "".join(f"{t}\0" for t in tokens)


def test_parse_status_reads_entries_and_consumes_a_rename_origin():
    text = _nul(" M .borg/chains/a.json", "R  .stacks/b.json", ".borg/chains/b.json", "?? .borg/chains/n", "!! x/")
    assert migrate.parse_status(text) == [
        (" M", ".borg/chains/a.json"),
        ("R ", ".stacks/b.json"),
        ("??", ".borg/chains/n"),
        ("!!", "x/"),
    ]


def test_parse_status_of_nothing_is_nothing():
    assert migrate.parse_status("") == []


def test_a_tracked_manifest_is_a_git_mv_and_an_ignored_one_is_a_move_and_add():
    facts = _facts(
        chains=("a.json", "b.json"),
        ls_files=_nul(".borg/chains/a.json"),
        status=_nul("!! .borg/chains/b.json"),
    )
    plan = migrate.plan_repository(facts)
    assert plan.outcome == migrate.OUTCOME_MIGRATE
    assert plan.moves == (
        migrate.Move(".borg/chains/a.json", ".stacks/a.json", True),
        migrate.Move(".borg/chains/b.json", ".stacks/b.json", False),
    )


def test_a_collapsed_ignored_directory_covers_the_manifests_inside_it():
    facts = _facts(chains=("a.json",), status=_nul("!! .borg/"))
    assert migrate.plan_repository(facts).moves == (migrate.Move(".borg/chains/a.json", ".stacks/a.json", False),)


def test_sources_are_ordered_chains_then_programs_and_names_are_sorted():
    facts = _facts(
        chains=("b.json", "a.json"),
        programs=("c.json",),
        ls_files=_nul(".borg/chains/a.json"),
        status=_nul("!! .borg/"),
    )
    assert [m.source for m in migrate.plan_repository(facts).moves] == [
        ".borg/chains/a.json",
        ".borg/chains/b.json",
        ".borg/programs/c.json",
    ]


def test_a_file_that_is_neither_tracked_nor_ignored_nor_dirty_is_skipped_not_guessed():
    plan = migrate.plan_repository(_facts(chains=("a.json",)))
    assert plan.outcome == migrate.OUTCOME_SKIP
    assert "cannot tell" in plan.reason


@pytest.mark.parametrize(
    "overrides,words",
    [
        ({"exists": False}, "does not exist"),
        ({"in_git": False}, "not a git repository"),
        ({"error": "boom"}, "could not read git state: boom"),
    ],
)
def test_an_unreadable_repository_is_skipped_by_name_with_the_reason(overrides, words):
    plan = migrate.plan_repository(_facts(chains=("a.json",), **overrides))
    assert plan.outcome == migrate.OUTCOME_SKIP
    assert words in plan.reason
    assert migrate.render(plan, dry_run=False) == [f"skipped: /r: {plan.reason}"]


def test_no_manifests_is_a_no_op_even_with_a_staged_deletion_from_the_previous_run():
    facts = _facts(stacks=("a.json",), status=_nul("D  .borg/chains/a.json"))
    plan = migrate.plan_repository(facts)
    assert plan.outcome == migrate.OUTCOME_NOTHING
    assert migrate.render(plan, dry_run=False) == ["nothing to migrate: /r"]


@pytest.mark.parametrize(
    "code,word",
    [(" M", "modified"), ("M ", "staged"), ("MM", "staged"), ("A ", "staged"), ("??", "untracked"), (" D", "modified")],
)
def test_every_uncommitted_change_under_a_source_directory_skips_the_repository(code, word):
    facts = _facts(chains=("a.json",), ls_files=_nul(".borg/chains/a.json"), status=_nul(f"{code} .borg/chains/a.json"))
    plan = migrate.plan_repository(facts)
    assert plan.outcome == migrate.OUTCOME_SKIP
    assert f".borg/chains/a.json ({word})" in plan.reason


def test_an_ignored_manifest_alone_is_not_an_uncommitted_change():
    facts = _facts(chains=("a.json",), status=_nul("!! .borg/chains/a.json"))
    assert migrate.plan_repository(facts).outcome == migrate.OUTCOME_MIGRATE


def test_a_stem_in_two_roots_is_refused_and_named_even_beside_a_dirty_tree():
    facts = _facts(chains=("a.json",), stacks=("a.json",), status=_nul(" M .borg/chains/a.json"))
    plan = migrate.plan_repository(facts)
    assert plan.outcome == migrate.OUTCOME_REFUSE
    assert ".borg/chains/a.json and .stacks/a.json" in plan.reason


def test_the_legacy_root_clashing_with_chains_is_refused_too():
    plan = migrate.plan_repository(_facts(chains=("a.json",), programs=("a.json",)))
    assert plan.outcome == migrate.OUTCOME_REFUSE
    assert ".borg/chains/a.json and .borg/programs/a.json" in plan.reason


@pytest.mark.parametrize(
    "overrides",
    [
        {"stacks_index": _nul(".stacks/a.json")},
        {"stacks_status": _nul("D  .stacks/a.json")},
        {"stacks_status": _nul("AD .stacks/a.json"), "stacks_index": _nul(".stacks/a.json")},
    ],
    ids=["in-the-index", "deletion-staged", "staged-then-deleted"],
)
def test_a_destination_git_holds_is_a_clash_though_the_tree_lacks_it(overrides):
    plan = migrate.plan_repository(_facts(chains=("a.json",), **overrides))
    assert plan.outcome == migrate.OUTCOME_REFUSE
    assert plan.reason.count(".stacks/a.json") == 1
    assert ".borg/chains/a.json and .stacks/a.json" in plan.reason


def test_a_destination_both_listed_and_indexed_is_named_once():
    plan = migrate.plan_repository(_facts(chains=("a.json",), stacks=("a.json",), stacks_index=_nul(".stacks/a.json")))
    assert plan.reason.count(".stacks/a.json") == 1


def test_names_that_differ_only_in_case_clash_because_the_filesystem_may_agree():
    plan = migrate.plan_repository(_facts(chains=("A.json",), stacks=("a.json",)))
    assert plan.outcome == migrate.OUTCOME_REFUSE


def _ignore(*entries):
    """`git check-ignore -v` output for `(source, line, pattern, path)` entries."""
    return "".join(f"{source}:{line}:{pattern}\t{path}\n" for source, line, pattern, path in entries)


def test_ignored_stacks_is_refused_naming_the_rule():
    ignore = _ignore((".gitignore", "4", ".stacks/", ".stacks/a.json"))
    plan = migrate.plan_repository(_facts(chains=("a.json",), stacks_ignore=ignore))
    assert plan.outcome == migrate.OUTCOME_REFUSE
    assert "always version-controlled" in plan.reason
    assert migrate.render(plan, dry_run=True) == [f"refused: /r: {plan.reason}"]


def test_the_ignore_refusal_names_each_ignored_destination_and_its_rule_not_the_whole_directory():
    """H6: a narrow rule ignores only some destinations; the refusal must say which, and by which rule."""
    ignore = _ignore(
        (".gitignore", "2", "a.json", ".stacks/a.json"),
        (".git/info/exclude", "1", "*.local.json", ".stacks/b.local.json"),
    )
    facts = _facts(chains=("a.json", "b.local.json", "c.json"), stacks_ignore=ignore)
    plan = migrate.plan_repository(facts)
    assert plan.outcome == migrate.OUTCOME_REFUSE
    assert ".stacks/a.json (.gitignore:2:a.json)" in plan.reason
    assert ".stacks/b.local.json (.git/info/exclude:1:*.local.json)" in plan.reason
    assert ".stacks/c.json" not in plan.reason
    assert "git ignores .stacks/," not in plan.reason


def test_a_destination_that_matched_a_negated_rule_is_not_ignored():
    """`check-ignore -v` reports a path that matched `!rule` too; it is tracked-able, so it must not refuse."""
    ignore = _ignore((".gitignore", "3", "!a.json", ".stacks/a.json"))
    assert migrate.parse_ignore_rules(ignore) == []
    facts = _facts(chains=("a.json",), stacks_ignore=ignore, status=_nul("!! .borg/"))
    assert migrate.plan_repository(facts).outcome == migrate.OUTCOME_MIGRATE


def test_parse_ignore_rules_drops_a_line_that_does_not_parse_and_keeps_a_pattern_with_a_colon_whole():
    assert migrate.parse_ignore_rules(".gitignore:1:x") == []
    assert migrate.parse_ignore_rules("not a rule\t.stacks/a.json\n") == []
    assert migrate.parse_ignore_rules("") == []
    assert migrate.parse_ignore_rules(_ignore((".gitignore", "7", "a:b", ".stacks/a.json"))) == [
        (".stacks/a.json", ".gitignore:7:a:b")
    ]


def test_a_stacks_that_is_not_a_directory_is_refused():
    kinds = {CHAINS: "directory", migrate.STACKS_DIR: "other"}
    plan = migrate.plan_repository(_facts(chains=("a.json",), kinds=kinds))
    assert plan.outcome == migrate.OUTCOME_REFUSE
    assert "not a plain directory" in plan.reason


def test_a_stacks_that_is_not_a_directory_is_ignored_when_there_is_nothing_to_move():
    kinds = {migrate.STACKS_DIR: "other"}
    assert migrate.plan_repository(_facts(kinds=kinds)).outcome == migrate.OUTCOME_NOTHING


def test_a_source_directory_that_is_a_symlink_is_refused_even_with_nothing_listed():
    kinds = {CHAINS: "other"}
    plan = migrate.plan_repository(_facts(kinds=kinds))
    assert plan.outcome == migrate.OUTCOME_REFUSE
    assert CHAINS in plan.reason


def test_refusal_wins_over_a_dirty_skip_because_committing_would_not_clear_it():
    ignore = _ignore((".gitignore", "4", ".stacks/", ".stacks/a.json"))
    facts = _facts(chains=("a.json",), stacks_ignore=ignore, status=_nul("?? .borg/chains/n"))
    assert migrate.plan_repository(facts).outcome == migrate.OUTCOME_REFUSE


def test_render_of_a_plan_names_each_move_and_each_newly_tracked_file():
    facts = _facts(
        path="/my repo",
        chains=("a.json", "b.json"),
        ls_files=_nul(".borg/chains/a.json"),
        status=_nul("!! .borg/chains/b.json"),
    )
    plan = migrate.plan_repository(facts)
    lines = migrate.render(plan, dry_run=False)
    assert lines[:5] == [
        "/my repo",
        "  git mv: .borg/chains/a.json -> .stacks/a.json",
        "  move + git add: .borg/chains/b.json -> .stacks/b.json",
        "  now tracked: .stacks/b.json (was ignored)",
        lines[4],
    ]
    assert lines[4].startswith("  to commit: git -C '/my repo' commit -m ")
    assert lines[4].endswith("-- .borg/chains/a.json .stacks/a.json .stacks/b.json")


def test_render_of_a_dry_run_is_the_same_plan_with_would_verbs():
    facts = _facts(chains=("b.json",), status=_nul("!! .borg/chains/b.json"))
    lines = migrate.render(migrate.plan_repository(facts), dry_run=True)
    assert lines[1:3] == [
        "  would move + git add: .borg/chains/b.json -> .stacks/b.json",
        "  would track: .stacks/b.json (was ignored)",
    ]
    assert not any("now tracked" in line for line in lines)


def test_summary_counts_what_moved_and_what_was_left():
    moved = migrate.plan_repository(_facts(chains=("a.json",), status=_nul("!! .borg/")))
    skipped = migrate.plan_repository(_facts(path="/s", in_git=False))
    assert migrate.summary([moved, skipped], dry_run=False) == (
        "stack migrate: migrated 1 manifest(s) in 1 repository(ies); 1 skipped or refused and left untouched"
    )
    assert migrate.summary([moved], dry_run=True) == "stack migrate: would migrate 1 manifest(s) in 1 repository(ies)"
    assert migrate.incomplete([moved, skipped]) == [skipped]


def test_summary_counts_the_moves_that_landed_in_a_repository_that_failed_part_way():
    """N1: a part-way failure used to read as `migrated 0` although moves had landed."""
    moved = migrate.plan_repository(_facts(chains=("a.json",), status=_nul("!! .borg/")))
    assert migrate.summary([], dry_run=False, partial={"/r": 2}) == (
        "stack migrate: migrated 2 manifest(s) in 1 repository(ies)"
    )
    assert migrate.summary([moved], dry_run=False, partial={"/p": 1}) == (
        "stack migrate: migrated 2 manifest(s) in 2 repository(ies)"
    )
    assert migrate.summary([], dry_run=False, partial={"/r": 0}) == (
        "stack migrate: migrated 0 manifest(s) in 0 repository(ies)"
    )


def test_the_skipped_or_refused_count_is_in_the_summary_and_the_summary_is_where_it_is_printed_once():
    """N2 at the pure seam: the summary carries the count, so the CLI need not print it a second time."""
    skipped = migrate.plan_repository(_facts(path="/s", in_git=False))
    assert migrate.summary([skipped], dry_run=False).endswith("; 1 skipped or refused and left untouched")


@pytest.mark.parametrize("kind", ["symlink", "dangling symlink", "directory", "special file"])
def test_a_source_entry_that_is_not_a_regular_file_refuses_the_repository_by_name(kind):
    """H1: a link would be moved with its link text unchanged and dangle in `.stacks/`."""
    facts = _facts(chains=("ok.json",), irregular={".borg/chains/odd.json": kind})
    plan = migrate.plan_repository(facts)
    assert plan.outcome == migrate.OUTCOME_REFUSE
    assert f".borg/chains/odd.json is a {kind}, not a regular file; move it by hand" in plan.reason


def test_a_source_entry_that_is_not_a_regular_file_refuses_even_when_nothing_else_is_listed():
    """A dangling link is not in the listing, so the repository used to read as `nothing to migrate`."""
    facts = _facts(irregular={".borg/programs/odd.json": "dangling symlink"})
    plan = migrate.plan_repository(facts)
    assert plan.outcome == migrate.OUTCOME_REFUSE
    assert ".borg/programs/odd.json is a dangling symlink" in plan.reason


@pytest.mark.parametrize("kind", ["symlink", "dangling symlink", "directory", "special file"])
def test_a_destination_that_is_not_a_regular_file_is_a_clash_named_with_its_kind(kind):
    """H2: `.stacks/a.json` exists as something else; the dry run must refuse, naming the entry and what it is."""
    facts = _facts(chains=("a.json",), stacks=("a.json",), irregular={".stacks/a.json": kind})
    plan = migrate.plan_repository(facts)
    assert plan.outcome == migrate.OUTCOME_REFUSE
    assert f".borg/chains/a.json and .stacks/a.json (a {kind})" in plan.reason


def test_an_irregular_entry_in_stacks_that_clashes_with_nothing_is_not_a_refusal():
    facts = _facts(
        chains=("a.json",),
        stacks=("other.json",),
        irregular={".stacks/other.json": "symlink"},
        status=_nul("!! .borg/"),
    )
    assert migrate.plan_repository(facts).outcome == migrate.OUTCOME_MIGRATE


@pytest.mark.parametrize(
    "names,words",
    [
        (("MERGE_HEAD",), "a merge is in progress (MERGE_HEAD exists)"),
        (("CHERRY_PICK_HEAD",), "a cherry-pick is in progress"),
        (("REVERT_HEAD",), "a revert is in progress"),
        (("rebase-merge",), "a rebase is in progress (rebase-merge exists)"),
        (("rebase-apply",), "a rebase is in progress (rebase-apply exists)"),
        (("MERGE_HEAD", "rebase-merge"), "a merge, a rebase is in progress (MERGE_HEAD, rebase-merge exists)"),
    ],
)
def test_an_operation_in_progress_skips_the_repository_by_name_with_the_reason(names, words):
    """H4: the printed pathspec commit would be refused by git mid-merge, so the repository waits."""
    plan = migrate.plan_repository(_facts(chains=("a.json",), operations=names, status=_nul("!! .borg/")))
    assert plan.outcome == migrate.OUTCOME_SKIP
    assert words in plan.reason
    assert migrate.render(plan, dry_run=True) == [f"skipped: /r: {plan.reason}"]


def test_a_locked_index_skips_the_repository_by_name_with_the_reason():
    plan = migrate.plan_repository(_facts(chains=("a.json",), index_locked=True, status=_nul("!! .borg/")))
    assert plan.outcome == migrate.OUTCOME_SKIP
    assert "index is locked (index.lock exists)" in plan.reason


@pytest.mark.parametrize(
    "unwritable,words",
    [
        ((".borg/chains",), "not writable, so manifests cannot be moved: .borg/chains"),
        ((".stacks",), "moved: .stacks"),
        ((".",), "the repository directory (.stacks/ would be created there)"),
    ],
)
def test_a_directory_that_is_not_writable_skips_the_repository_by_name(unwritable, words):
    """H3: the dry run predicts a failure the real run would otherwise hit part-way."""
    facts = _facts(chains=("a.json",), unwritable=unwritable, status=_nul("!! .borg/"))
    plan = migrate.plan_repository(facts)
    assert plan.outcome == migrate.OUTCOME_SKIP
    assert words in plan.reason


def test_a_refusal_wins_over_every_skip_and_the_skips_are_ordered_operation_lock_writable_dirty():
    ignore = _ignore((".gitignore", "4", ".stacks/", ".stacks/a.json"))
    every = {"operations": ("MERGE_HEAD",), "index_locked": True, "unwritable": (".stacks",)}
    assert migrate.plan_repository(_facts(chains=("a.json",), stacks_ignore=ignore, **every)).outcome == (
        migrate.OUTCOME_REFUSE
    )
    dirty = _nul("?? .borg/chains/n")
    plan = migrate.plan_repository(_facts(chains=("a.json",), status=dirty, **every))
    assert "merge is in progress" in plan.reason
    del every["operations"]
    assert "index is locked" in migrate.plan_repository(_facts(chains=("a.json",), status=dirty, **every)).reason
    del every["index_locked"]
    assert "not writable" in migrate.plan_repository(_facts(chains=("a.json",), status=dirty, **every)).reason
    assert "uncommitted changes" in migrate.plan_repository(_facts(chains=("a.json",), status=dirty)).reason


def test_nothing_to_move_stays_nothing_whatever_the_state_around_it():
    """A repository with no manifest is never skipped for being mid-merge or read-only: there is nothing to do."""
    facts = _facts(operations=("MERGE_HEAD",), index_locked=True, unwritable=(".stacks",))
    assert migrate.plan_repository(facts).outcome == migrate.OUTCOME_NOTHING


def test_the_planner_stays_pure_by_import_roots():
    """No os, subprocess, json or pathlib may creep into the planner: it is facts in, plan out."""
    tree = ast.parse(pathlib.Path(migrate.__file__).read_text(encoding="utf-8"))
    roots = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            roots.update(alias.name.split(".")[0] for alias in node.names)
        elif isinstance(node, ast.ImportFrom) and node.module:
            roots.add(node.module.split(".")[0])
    assert roots == {"__future__", "dataclasses", "typing"}


@pytest.mark.parametrize(
    "text,quoted",
    [
        ("plain/path-1.json", "plain/path-1.json"),
        ("", "''"),
        ("a b", "'a b'"),
        ("it's", "'it'\\''s'"),
        ("$HOME;x", "'$HOME;x'"),
    ],
)
def test_the_commit_command_quotes_for_a_posix_shell(text, quoted):
    assert migrate._quote(text) == quoted  # pylint: disable=protected-access
