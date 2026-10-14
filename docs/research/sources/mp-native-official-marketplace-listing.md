# Source: anthropics/claude-plugins-official marketplace listing

**Full citation:** Anthropic. ".claude-plugin/marketplace.json", repository anthropics/claude-plugins-official, entry "mattpocock-skills". https://github.com/anthropics/claude-plugins-official/blob/main/.claude-plugin/marketplace.json. Fetched 2026-10-13.
**URL:** https://raw.githubusercontent.com/anthropics/claude-plugins-official/main/.claude-plugin/marketplace.json
**Date accessed:** 2026-10-13
**Evidence level:** 4 (vendor registry record)
**Research topic area:** Plugin marketplace status of Matt's skills in Claude Code

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 9/10 | Anthropic-owned registry |
| 2 | Evidence Quality | 6/10 | Registry record, not review |
| 3 | Currency | 10/10 | Current main |
| 4 | Intent | 7/10 | Catalog listing |
| 5 | Bias & Objectivity | 7/10 | Neutral data file |
| 6 | Logic & Coherence | 9/10 | Structured JSON |
| 7 | Corroboration | 9/10 | README install command matches |
| 8 | Intellectual Honesty | 6/10 | No endorsement scope stated |
| 9 | Specificity | 9/10 | Pins a source commit SHA |
| 10 | Relevance | 8/10 | Official channel status |

- Authority: the file is in Anthropic's official plugin marketplace repository.
- Evidence Quality: it proves listing, not vetting depth; no statement of review.
- Currency: fetched from main; the entry pins a commit SHA, so the listing lags the repo head by design.
- Corroboration: Matt's README tells Claude Code users to install `mattpocock-skills@claude-plugins-official`, and the manifest entry confirms that name.
- Honesty: entries carry no endorsement text, so listing should not be read as an Anthropic recommendation.
- Specificity: shows `author`, `category: development`, source URL, and a pinned SHA.
- Relevance: answers whether the skills are an officially distributed plugin.

**Score band:** keep

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- `mattpocock-skills` is a listed plugin in Anthropic's official marketplace, category development, sourced from the author's own repo at a pinned commit.
- This turns a GitHub skill pack into a one-command native install, a distribution path borg-collective already uses as a plugin.
- The pinned SHA means official-marketplace users get updates only when the listing is bumped, a lag compared with direct marketplace add.
- Matt's own ADR 0002 records that the Claude Code plugin manifest accepts an array of skill directory paths, while the Codex manifest accepts one path string, so Codex gets only a deferred native plugin and uses skills.sh meanwhile.

## Verified Quote(s)

**Location reference:** JSON object with `"name": "mattpocock-skills"`, field `"description"`.

> Matt Pocock's agent skills for real engineering — grilling, spec/ticket flows, TDD, code review, domain modelling and more. Plug-and-play, not vibe coding.

**Access status:** live

## Inclusion Decision

**Decision:** Supporting
**Rationale:** Short but decisive for "is it official/native-distributed"; also names the plugin mechanism.

**Redundancy check:** Not redundant: the README states the install command but cannot prove the listing.

**Perspective category:** Institutional
