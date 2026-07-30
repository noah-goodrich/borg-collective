# ELI10 Brief: How to Pick Shapes and Zoom Levels So People Actually Understand Your Chart

**Date:** 2026-07-30
**Reading level target:** a smart 10-year-old, per the program's ELI10 mandate.

## The one-sentence version

Your eyes are really good at comparing dots on a line, pretty good at comparing bar heights, and bad at
comparing pie-slice angles or blob sizes — so put your most important number where the eyes are strongest, and
if your chart has "zoomed-out" and "zoomed-in" versions, make the zoom smooth so people don't get lost.

## The story, in plain language

Imagine you have two jars of jellybeans and you want to know which jar has more red jellybeans. If someone
draws you two bars — one tall, one short — you can tell in half a second which is bigger. That's because your
eyes are amazing at comparing **how high something is on a line**. Now imagine instead they drew you two pie
charts and asked you to compare the angle of the red slice. That takes longer and you get it wrong more often.
Scientists actually measured this in 1984 (Cleveland & McGill) and found a ranking: your eyes are best at
comparing position on a line, next best at length, then angle, then worst at comparing area (blobs) and color
darkness. [Cleveland & McGill, 1984]

People re-checked this with thousands of internet volunteers in 2010 and it mostly held up. [Heer & Bostock,
2010] But in 2022, other scientists found something important: about **30 out of every 100 people** don't
actually do best with bars — they're the exception to the rule. [Davis et al., 2022] So the ranking is a really
good *starting guess*, not a law of physics that's true for every single person.

There's a second, separate trap: even if you pick the perfect shape, people might not see it at all if they're
busy looking at something else. In a famous experiment, half of people watching a video of people passing a
basketball completely missed a person in a gorilla suit walking through the middle of the screen. [Simons &
Chabris, 1999] The lesson: if something on your dashboard is urgent, it has to visually **pop** — being merely
"visible" isn't enough if the viewer's attention is somewhere else.

Now, on top of "which shape," there's the question of "which zoom level." A famous rule from 1996 says: show
the big picture first, let people zoom and filter, then let them ask for details only when they want them —
"Overview first, zoom and filter, then details-on-demand." [Shneiderman, 1996] That rule sounds obviously
right, and mostly is — but nobody has ever actually run the big experiment proving the *whole rule* works.
[Craft & Cairns, 2005] What we do know, from a big review of many smaller studies, is that the *zooming* part
specifically works well when it's a smooth, animated transition between zoomed-out and zoomed-in — and works
badly, causing people to get lost, when the zoom is jumpy. [Cockburn, Karlson & Bederson, 2008] Brand-new 2025
research on zoomed maps of large systems (software "cities" and supply-chain networks) confirms smooth zoom
between a macro view and a detail view helps people finish tasks faster than a flat, all-at-once view.
[arXiv 2510.00003, 2025; arXiv 2604.08823, 2026]

## The 5-second-story comprehension check

Show the chart to someone for 5 seconds, take it away, and ask: **"What's the one thing this chart wants you
to know?"** Pass criteria:
1. They can say the single most important number/comparison, unprompted, using the channel you chose to carry
   it (e.g., "the blue bar is way taller" — not "there was a blue and orange thing").
2. If the chart has a zoomed-out and zoomed-in mode, they can say **where they'd click or scroll to see more
   detail** without being told — i.e., the zoom affordance itself is visible in 5 seconds, even if they never
   used it.
3. If there's an urgent/anomalous data point, they mention it unprompted — if they don't, the anomaly failed
   the "pop" test (see Simons & Chabris finding above) and needs a stronger visual cue, not just correct
   placement.

If any of the three fail, the fix is (1) move the important number to a higher-ranked channel (position/length
over angle/area/color), (2) make the zoom affordance more visible (a mini-map, a breadcrumb, a labeled "zoom in"
control), or (3) make the anomaly visually louder (color, motion, or isolation from similar-looking neighbors)
— per playbook rules P1, P6, and P3 respectively.

## Sources (see findings synthesis for full citations)

Cleveland & McGill 1984; Heer & Bostock 2010; Davis et al. 2022/2023; Simons & Chabris 1999; Shneiderman 1996;
Craft & Cairns 2005; Cockburn, Karlson & Bederson 2008; arXiv 2510.00003 (2025); arXiv 2604.08823 (2026).
