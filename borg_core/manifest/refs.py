"""The ref vocabulary: what a declared reference IS, and how to read one.

SPLIT OUT OF core.py, which crossed C0302's 1000-line ceiling and whose disable note named this exact
seam: "the ref vocabulary (`parse_ref`, `ref_slug`, `slug_from_remote`, `suggest_full_ref`, and their
regexes) is a self-contained ~120 lines that the validator, the selector and the topology all merely
consume." This is that move, made verbatim -- every function below is byte-identical to the copy it
replaces, so the split itself changes no behaviour and any diff in these bodies is a bug.

PURE. Imports `re` and nothing else. `core.py` re-exports every public name here so no caller moved.

WHY IT IS ITS OWN MODULE AND NOT JUST SMALLER core.py. A ref is the one value every other concern in
this package keys on -- validation, repository selection, edge endpoints, the targeted fetch, recon's
cross-source dedup -- and it is the concept most likely to grow. Growing it inside the validator is
how "a ref is a GitHub PR" became a rule nobody decided.
"""

from __future__ import annotations

import re
from typing import Any


def _text(value: Any) -> str:
    """Local copy of core's coercion. See core._text -- importing it would make this module depend on
    the one that depends on it."""
    return str(value or "").strip()

# A full ref, and nothing looser. Owner and name use GitHub's per-part character class, mirroring the
# adapter's accept test at recon-adapter-github:96-101; the number is literal digits.
#
# `\Z`, NOT `$`: Python's `$` also matches immediately BEFORE a trailing newline, so `"o/r#1\n"` would
# parse and report a slug for a string that can never equal any item's ref. `\Z` is end-of-string and
# nothing else.
_REF_RE = re.compile(r"^([A-Za-z0-9._-]+)/([A-Za-z0-9._-]+)#([0-9]+)\Z")

# Everything up to and including the LAST `github.com` followed by `:` or `/`, then one trailing
# `.git`. Both mirror recon-adapter-github:88's `sed -E 's#^.*github\.com[:/]##; s#\.git$##'`, and
# the greedy `.*` is the load-bearing half: a remote of the form
# `https://x-access-token:<token>@github.com/owner/repo.git` matches neither `git@github.com:` nor
# `https://github.com/`, so a two-prefix pattern would leave the URL -- CREDENTIAL AND ALL -- as the
# slug, which then flows into every ref. That leaked a live token in the adapter, found 2026-08-14.
_HOST_PREFIX_RE = re.compile(r"^.*github\.com[:/]")
_GIT_SUFFIX_RE = re.compile(r"\.git\Z")

# GitHub's per-part character class plus the single `/` separator, mirroring
# recon-adapter-github:96's `*[!A-Za-z0-9._/-]*` reject test.
#
# `\Z`, NOT `$`: Python's `$` also matches immediately BEFORE a trailing newline, so `"owner/repo\n"`
# would pass a character-class test that the shell's `case` glob rejects, and the newline would ride
# into every ref built from the slug. Defense in depth rather than the only guard --
# shell._git_origin_url already strips trailing newlines -- and it is what keeps this correct if that
# strip is ever moved or dropped. An EMBEDDED newline (a remote with several URLs) is rejected either
# way, because a newline is outside the class no matter where it sits.
_SLUG_CHARS_RE = re.compile(r"^[A-Za-z0-9._/-]+\Z")

def parse_ref(ref: Any) -> tuple[str, str, str] | None:
    """Split a full `owner/repo#number` ref into its parts, or None when it is not that shape.

    RETURN SHAPE: a 3-tuple of STRINGS -- `(owner, name, number)`. `stillpoint-labs/ingle#42` yields
    `("stillpoint-labs", "ingle", "42")`. Every element is an exact substring of the input, so
    `f"{owner}/{name}"` reconstructs the slug byte-identically and `number` keeps its literal digits
    (`o/r#007` -> `"007"`, never `7`). None -- not a half-parsed tuple -- for a bare `repo#12`, a Jira
    key like `PROJ-123`, an empty string, `o/r#abc`, `a/b/c#1`, or a padded `" o/r#1 "`.

    IT MUST NOT NORMALIZE, and the whitespace case is the tell. borg_core/recon/core.py:186-194
    deduplicates cross-source items by using the RAW `item["ref"]` string as a dict key -- no case
    fold, no strip, no `.git` handling, no entity resolution -- and states the policy outright at
    :170-172. So `Owner/Repo#12` and `owner/repo#12` are two different items TODAY. A parse that
    folded case, or that stripped padding into a "clean" slug, would report a slug for a ref that can
    never match any item, and the edge built from it would vanish from the graph silently instead of
    raising. Rejecting is the only safe answer: a non-conforming ref is a manifest defect to surface,
    not a string to repair.
    """
    match = _REF_RE.match(ref) if isinstance(ref, str) else None
    if match is None:
        return None
    # JUSTIFICATION: reading the groups of a Match this function just produced, not a foreign object.
    return (match.group(1), match.group(2), match.group(3))  # pylint: disable=clean-arch-demeter



def ref_slug(ref: Any) -> str:
    """The `owner/repo` half of a full ref, or "" when the ref is not a full ref.

    Never a prefix match on the raw string: `stillpoint-labs/stillpoint-web#1` starts with
    `stillpoint-labs/stillpoint`, so a prefix test would attribute a web-repository manifest to the
    `stillpoint` repository. See select_for_repository, which exists to be exactly that strict.
    """
    parts = parse_ref(ref)
    return f"{parts[0]}/{parts[1]}" if parts else ""



def slug_from_remote(remote: str) -> str:
    """The `owner/repo` a git origin URL names, or "" when it is not exactly one GitHub repository.

    PURE, and here rather than in shell.py on purpose: this is a string->string rule table with no
    I/O in it, and while it lived beside the subprocess every one of its ~17 cases -- including the
    credentialed URL that pins the 2026-08-14 token leak -- could only be asserted by spawning
    `git init` + `git remote add` + `git remote get-url`. shell.repository_slug supplies the URL;
    this decides what it means.

    MIRRORS lib/recon/adapters/recon-adapter-github:81-101 RULE FOR RULE, because the refs a manifest
    declares are the refs that adapter emits (`ref: ($m.repo + "#" + (.number|tostring))` at :177)
    and a slug derived by any other rule would match nothing:

      :81  the URL must name the GitHub host.
      :88  strip everything through the last `github.com[:/]`, then one trailing `.git`.
      :89  an empty result is rejected.
      :96  reject any character outside `[A-Za-z0-9._/-]`; owner and name are interpolated into a
           GraphQL document, so they are validated rather than escaped -- reject, never repair.
      :97-101  reject more than one slash, a leading or trailing slash, or no slash at all. Exactly
           `owner/name` is the only accepted shape.

    THE HOST TEST IS NOT REDUNDANT with the character class, which is why it has its own cases: a
    relative remote like `../sibling` or `mirrors/repo.git` survives every other rule here (`.`, `/`
    and `-` are all inside GitHub's class and the shape is exactly one slash), so without the host
    test it would be reported as a real slug and select whatever manifest happens to declare
    `mirrors/repo#N`.

    CASE IS PRESERVED. Nothing here lowercases: the accepted slug flows verbatim into refs, and
    borg_core/recon/core.py:186-194 dedups on the exact string, so folding case would produce a slug
    matching no item.

    RECORDED DIVERGENCE in an unreachable corner: the adapter's host test is the shell glob
    `*github.com*`, where `.` matches ANY character, so `githubXcom/o` passes it. This uses a literal
    substring test. The two agree everywhere it matters, because the strip at :88 requires a literal
    `github.com` and anything that reached it without one is rejected by the character-class or
    slash-shape tests -- the sole survivor being a bare relative remote like `githubXcom/o`, which is
    not a GitHub repository and which this correctly refuses.
    """
    if "github.com" not in remote:
        return ""
    slug = _GIT_SUFFIX_RE.sub("", _HOST_PREFIX_RE.sub("", remote))
    if not slug or not _SLUG_CHARS_RE.match(slug):
        return ""
    if slug.count("/") != 1 or slug.startswith("/") or slug.endswith("/"):
        return ""
    return slug



def suggest_full_ref(ref: str, slug: str) -> str:
    """`owner/repo#num` for a shorthand ref that can only have meant THIS repository, else "".

    A SUGGESTION IS NOT A REPAIR, and the distinction is the whole reason this returns a string for a
    message instead of rewriting the row. `parse_ref`'s docstring forbids normalizing a ref, because
    a repaired-but-wrong slug produces an edge that resolves against nothing and vanishes from the
    graph silently -- strictly worse than the loud rejection it replaced. What is safe is telling the
    author the exact token to type, and letting them type it.

    The guard is deliberately narrow: the shorthand's repo half must equal the local repository's
    repo half EXACTLY. `borg-collective#191` inside `noah-goodrich/borg-collective` is answerable;
    `stillpoint#4` inside it is not, and gets no suggestion rather than a confident wrong one. A
    manifest's whole purpose is naming PRs in OTHER repositories, so "the containing repository" is
    the least reliable guess available and is only offered when the author already named the repo.

    Case is compared as written. `Borg-Collective#191` earns no suggestion here even though it would
    pass `validate`, because it is a different defect -- see the recon dedup note in `parse_ref`.

    TAKES AN ALREADY-COERCED `str`, unlike most of this module, which funnels declared fields through
    `_text`. Coercing here would make every subsequent read a method call on another function's
    return value, which W9006 rejects as a Demeter chain -- and the one caller is
    `shell._write_refusal`, which is already holding the substring it parsed out of a validator
    message. A non-string ref cannot reach here: `_row_ref_error` rejects it before a suggestion is
    ever sought.
    """
    if not slug or "#" not in ref or "/" in ref:
        return ""
    stem, _, number = ref.partition("#")
    if not number.isdigit() or not stem:
        return ""
    owner, _, repo = slug.partition("/")
    if not owner or repo != stem:
        return ""
    return f"{slug}#{number}"
