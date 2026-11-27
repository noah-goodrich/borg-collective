# A decision card under `Waits on you:`

The reader of a checkpoint has read nothing from the session, so a bare "#97, close or restate scope" is useless. A decision item is a top-level bullet holding a one-line title (the question, with its source link), then indented sub-bullets: `Context:` (what the thing is, in words a stranger follows), `Why open:` (what is blocked on it), `Options:` (2 to 4, each with `Pro:`, `Con:` and `Runs:`, the exact command or action choosing it triggers) and `Recommend:` (your pick, also listed first among the options). `borg link` and the arrival brief show only the title line; the whole card is stored for `/borg-link`, which asks it through AskUserQuestion. A chore (a credential to rotate, a file to copy) stays a one-line bullet. Only indented LIST items make a card; a wrapped one-liner stays a one-liner.

```markdown
Waits on you:
- Close or restate noah-goodrich/borg-collective#97? https://github.com/noah-goodrich/borg-collective/issues/97
  - Context: #97 asks for a retry wrapper around gh calls, but #101 shipped one with a different name.
  - Why open: the issue blocks the 0.9.13 release board until it is closed or rewritten.
  - Options:
    - Close it (recommended). Pro: the board is clean. Con: loses the logging ask. Runs: gh issue close 97.
    - Restate it. Pro: keeps the logging ask. Con: the issue stays open another cycle. Runs: gh issue edit 97.
  - Recommend: close it, and file the logging ask as its own issue.
- Rotate the demo token in the vault.
```
