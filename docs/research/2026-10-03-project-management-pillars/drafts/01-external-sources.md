# External sources: what was fetched, what it says, how strong it is

All URLs accessed 2026-10-03. Strength key: **S1** = the primary text or its publisher, fetched and quoted;
**S2** = secondary summary of a primary I could not fetch; **S3** = practitioner opinion or vendor material.
"Documented best practice" below means a statement in an S1 text. Anything else is labelled opinion.

## PMI: PMBOK Guide and the Standard for Project Management

- Primary page `https://www.pmi.org/standards/pmbok` and `/standards/project-management-standard` returned HTTP 403
  to automated fetch. **No S1 for PMI.** The PMBOK text itself is paywalled (PMI members / purchase).
- S2: PMBOK 7 = 12 principles (Stewardship, Team, Stakeholders, Value, Systems Thinking, Leadership, Tailoring,
  Quality, Complexity, Risk, Adaptability and Resiliency, Change) and 8 performance domains (Stakeholders, Team,
  Development Approach and Life Cycle, Planning, Project Work, Delivery, Measurement, Uncertainty); the domains
  "have no sequence; they must be developed simultaneously". Via the search summary of
  `https://ricardo-vargas.com/podcasts/pmbok-guide-7th-edition-performance-domains-part-3-3/` and
  `https://www.4pmti.com/learn/pmbok-guide-7th-ed/` (both S3 vendor/trainer pages, agreeing with each other).
- S2: PMBOK 8 (2025) consolidates to 6 principles (Holistic View, Focus on Value, Embed Quality, Accountable
  Leader, Integrate Sustainability, Empowered Culture), 7 domains (Governance, Scope, Schedule, Finance,
  Stakeholders, Resources, Risk) and restores 5 focus areas (Initiating, Planning, Executing, Monitoring and
  Controlling, Closing). Source: `https://projectmanagementacademy.net/resources/blog/pmbok-7-vs-pmbok-8-differences/`
  (S3, a PMP exam-prep vendor) and `https://www.brainbok.com/blog/pmp/pmbok-guide-7th-vs-8th-edition-what-has-changed`
  (S3). Two independent vendors agree; **treat the 8th-edition list as unverified until read in the standard.**
- Use in this study: PMI supplies the *vocabulary of coverage* (value, planning, delivery, measurement, uncertainty,
  sustainability) and the claim that no domain is a phase. It is not used as an effectiveness yardstick.

## Scrum Guide (S1)

`https://scrumguides.org/scrum-guide.html` fetched. Quoted:

- Pillars: Transparency ("work must be visible to those performing the work as well as those receiving it"),
  Inspection ("inspected frequently and diligently to detect potentially undesirable variances"), Adaptation.
- Three commitments, each tied to an artifact: Product Goal ("a future state of the product which can serve as a
  target"), Sprint Goal ("the single objective for the Sprint"), Definition of Done ("a formal description of the
  state of the Increment when it meets the quality measures required").
- Events: Sprint Review "inspect the outcome of the Sprint and determine future adaptations"; Retrospective "plan
  ways to increase quality and effectiveness". Timeboxes: planning max 8h, review max 4h, retro max 3h per month.
- Only the Product Owner may cancel a Sprint.

## Kanban Guide (S1 for the PDF text; one fetch summary was loose)

`https://kanbanguides.org/the-kanban-guide/2020.12/pdf/kanban-guide.v2020.12.en.pdf` fetched. Practices: define and
visualize the workflow, actively manage items, improve the workflow. Four flow measures: **WIP, Cycle Time, Work Item
Age, Throughput**; plus the Service Level Expectation. Cross-check on the metric definitions (different provenance):
`https://www.prokanban.org/blog/https-prokanban-org-blog-the-kanban-pocket-guide-chapter-6-the-basic-metrics-of-flow`
(search result, S3). Note: a first fetch of `kanban.university/kanban-guide/` returned only three metrics and six
"general practices"; that is a different (older) formulation, so cite the 2020.12 PDF for the four-measure form.
Quote retained: "Limiting the work that is allowed to enter the system is an important key to reducing delay and
context switching" (kanban.university page; S1 for that publisher).

## Shape Up, Basecamp (S1; the book is free online)

- Appetite: "Estimates start with a design and end with a number. Appetites start with a number and end with a
  design." `https://basecamp.com/shapeup/1.2-chapter-03`
- Fixed time, variable scope: "When you have a deadline, all of a sudden you have to make decisions." same page.
- Circuit breaker: "Cancel projects that don't ship in one cycle by default instead of extending them by
  default." and "If they don't finish, by default the project doesn't get an extension."
  `https://basecamp.com/shapeup/2.2-chapter-08`
- Betting, no backlog, cooldown: "Backlogs are a big weight we don't need to carry."; a betting table before each
  cycle; cooldown is "a two-week break between cycles to do ad-hoc tasks, fix bugs". `.../2.1-chapter-07`
- Strength note: Shape Up is one company's documented practice, not a controlled study. It is S1 for *what the
  practice is*, opinion for *that it works*.

## Lean, cost of delay, WSJF

- Lean Enterprise Institute lexicon, value stream mapping: lead time vs processing time; "actual processing
  represents only a small fraction of total lead time" (summary of the page). Fetched
  `https://www.lean.org/lexicon-terms/value-stream-mapping/` (S1 for the definition; the "small fraction" claim is
  the fetch tool's paraphrase, weak).
- SAFe WSJF: WSJF = relative cost of delay / relative job duration; Cost of Delay = User-Business Value + Time
  Criticality + Risk Reduction/Opportunity Enablement; quotes Reinertsen "If you only quantify one thing, quantify
  the Cost of Delay." `https://framework.scaledagile.com/wsjf/` (S1 for SAFe's method; the economics originate in
  Reinertsen, *The Principles of Product Development Flow*, 2009, a book I did not read: S2). SAFe's own caveat:
  scores are relative estimates and must be re-ranked continuously.

## DORA and SPACE

- DORA metrics: five, in two groups. Throughput: change lead time, deployment frequency, failed deployment recovery
  time. Instability: change fail rate, deployment rework rate. "Top performers do well across all five." Best
  applied per application or service. `https://dora.dev/guides/dora-metrics-four-keys/` (S1).
- DORA 2025 (AI-assisted development): AI raises throughput but instability still rises; "AI improves throughput,
  but often at the cost of stability if your foundation isn't solid."
  `https://dora.dev/insights/dora-2025-year-in-review/`
  (S1), with a secondary corroboration at `https://www.scrum.org/resources/blog/dora-report-2025-summary-state-ai-assisted-software-development`
  (S3: AI as "amplifier", seven team archetypes).
- SPACE (Forsgren et al., ACM Queue 2021): five dimensions: Satisfaction and well-being, Performance, Activity,
  Communication and collaboration, Efficiency and flow; productivity cannot be captured in one number. Primary at
  `https://queue.acm.org/detail.cfm?id=3454124` returned 403; the dimensions were confirmed from search summaries
  of ResearchGate / vendor pages (S2). Relevant here: *Activity* metrics (commits, PRs) are the weakest dimension
  and borg's cheapest data is exactly that.
- METR randomized trial (July 2025): 16 experienced open-source developers, 246 real issues; AI use made them 19%
  slower while they believed it made them 20% faster. `https://metr.org/blog/2025-07-10-early-2025-ai-experienced-os-dev-study/`
  (S1, small sample, early-2025 tools). Use: **self-reported speed is not evidence**; borg's own docs are self-report.

## Sustainable pace and the solo / ADHD case

- Agile Manifesto principles (S1): "maintain a constant pace indefinitely"; "Simplicity--the art of maximizing the
  amount of work not done"; "Working software is the primary measure of progress"; regular reflection and tuning.
  `https://agilemanifesto.org/principles.html`
- ADHD evidence is **thin and mostly S3**. Found: a 2026 qualitative study of an ADHD-programmer community
  (cognitive load driven by the gap between demand and available executive capacity; feedback loops act as
  external supports) at the CBSoft/SBES paper
  `https://cbsoft.sbc.org.br/2026/data/papers/sbes/Understanding%20ADHD%20Developers_%20Challenges%20Through%20the%20Lens%20of%20Developer%20Experience%20A%20Qualitative%20Study%20of%20the%20rADHD_Programmers%20Community%20on%20Reddit.pdf`
  (S2: I read the search summary, not the paper; a Reddit-corpus qualitative study); a prototype paper, Tether
  (`https://arxiv.org/pdf/2509.01946`, S3, a tool proposal); and an occupational-therapy article on time blindness
  (`https://www.occupationaltherapy.com/articles/time-blindness-critical-executive-function-5790`, S3). What the
  evidence supports: external scaffolding for time, initiation and working memory is the consistent
  recommendation. **There is no controlled evidence that WIP limits or any specific PM method improve ADHD
  developers' delivery.** The ADHD link is borg's design premise (Noah's own context), not a literature finding.
- The WIP-limit claim therefore rests on Kanban's general flow argument (S1 Kanban Guide), not on ADHD research.

## Not fetched (gaps)

- PMBOK 7/8 text (paywalled); Reinertsen's book; the SPACE paper itself (403); *Accelerate* (Forsgren, Humble, Kim,
  2018, the DORA basis); Little's Law primary derivation (Little 1961). All are standard references; none changes a
  conclusion here, but the pillar justification for risk (PMI "Uncertainty") leans on S2/S3 only.
