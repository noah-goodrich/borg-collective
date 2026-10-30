# Automatically Learning Skills for Coding Agents (gskill)

- Citation: Shangyin Tan, Lakshya A Agrawal, Rohit Sandadi, Dan Klein, Koushik Sen, Alexandros G. Dimakis, Matei Zaharia, "Automatically Learning Skills for Coding Agents", GEPA blog, February 18, 2026.
- URL: https://gepa-ai.github.io/gepa/blog/2026/02/18/automatically-learning-skills-for-coding-agents
- Date accessed: 2026-10-30
- Evidence level: practitioner (tool authors' blog; two repositories; no variance reported)
- Access status: live

## Verified Quote(s)

Section "The Recipe":

> Generate ~300 SWE-smith tasks per repository

> train (~200), validation (~50), and test (~60) splits from the tasks

Section "Experiments":

> from 55% to 82% on Jinja and from 24% to 93% on Bleve

Section "Transfer to Claude Code":

> although the pass rate saturated, we still observe significant task duration reduction with the learned skills

## Key finding

GEPA-optimized SKILL.md files, learned on gpt-5-mini plus Mini-SWE-Agent with about 200 train, 50 validation and 60 test generated tasks per repository, transferred to Claude Code (Haiku 4.5 and Sonnet 4.5) and shortened task duration even where the pass rate was saturated. Caveats: the text and charts disagree on some numbers, Sonnet regressed slightly on Jinja (100.0% to 98.5%), there are only two repositories, and no run-to-run variance is reported.
