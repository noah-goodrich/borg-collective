# ELI10 Brief: How to Build a Status Screen That Doesn't Cry Wolf

**Date:** 2026-08-10
**Reading level target:** a smart 10-year-old, per the program's ELI10 mandate.

## The one-sentence version

A status screen should fit on one screen, show you only the stuff that's weird instead of everything, and never
interrupt you unless you'd actually do something different because of the interruption.

## The story, in plain language

Imagine your bedroom has a smoke alarm. It's great — if it goes off, you leave the house. Now imagine someone
adds a second alarm that beeps whenever the room gets a little dusty, and a third that beeps every hour to remind
you that alarms exist. After a week, what happens? You stop hearing all of them. Including the smoke one.

That's the whole problem this track is about, and it has a name: **alert fatigue**. It's not people being lazy.
It's what happens automatically when too many things ask for your attention and most of them turn out not to
matter.

Google's engineers, who run some of the biggest computer systems on Earth, wrote down a test for this. Before
anything is allowed to interrupt a human, it has to pass **four** checks at once: is it *urgent*, can the person
actually *do* something, does it need a *human's judgment* (not just a robot's), and is it *actually affecting
someone right now*? [Google SRE, 2016] If it fails even one, it doesn't get to interrupt.

They also added a really sharp follow-up rule, and it's the best sentence in this whole track:

> If a page merely merits a robotic response, it shouldn't be a page.

Translation: if your answer to the alert is *the same every single time*, the alert is useless. Not "slightly
annoying" — actually useless, because it isn't telling you anything you didn't already know. A reminder that says
"hey, have you considered doing the thing?" every hour, where the answer is always "yes, already did," is a
dusty-room alarm. It's spending your attention and giving nothing back.

Now, the screen itself. A guy named Stephen Few wrote the most-quoted rule about status screens: it has to fit on
**one screen**. If you have to scroll to see everything, he says, it's not a dashboard anymore — it's just a
report you're squinting at. [Few, 2006] He also says it should show you *exceptions* — the weird stuff — not
every single detail, because "you cannot monitor at a glance all the details."

Here's the honest part, though: **Few never proved this.** He's an expert with a lot of experience, and it sounds
right, but nobody ran an experiment showing that one screen is the magic number. In this program we grade sources
by how strong their evidence is, from Level 1 (a careful review of many experiments) down to Level 8 (one person's
story). Few is a **Level 7** — expert opinion. Out of the six sources in this track, only **one** is Level 1, and
it's about alarm overload, not screen layout. So this whole track is more "smart people's strong opinions" than
"proven science," and we should say so instead of pretending otherwise.

But there's a good reason to still believe the one-screen idea, and it's not Few. It's a separate group of
researchers who studied how people actually hunt for information. They found people behave like animals foraging
for food: they follow the **scent** — how promising something looks — and they give up the moment the effort
stops feeling worth it. [NN/G, 2019] What creates that scent? "The title, images, and the information that is
easily visible above the fold" — meaning **the top of the screen**.

That's a big deal, and it's subtler than "put important stuff first." It means the top of your screen decides
whether anyone looks at the rest of it *at all*. If the first thing someone sees is a logo and a list of boring
stuff, they've already decided your screen isn't worth reading — and the urgent thing you carefully put at the
bottom might as well not exist.

So the one-screen rule works, but not because one screen is magic. It works because people quit early, and a
screen that makes them scroll is a screen they'll quit before finishing.

One more voice, and this one's a cautionary tale about believing things too fast. In 2020 a data analyst wrote a
famous article called "Dashboards are Dead," saying they fail because we ask one screen to do way too many
different jobs at once. Lots of people shared it. Then, three years later, **he changed his mind in public** and
said the real problem wasn't the screens at all — it was "the relationships, communication, processes, and
people" at his company. [Brownlow, 2020/2023] So the most-shared criticism of dashboards was retracted by the guy
who wrote it. That's a Level 8 source: one person's experience. Worth reading for the *question* it makes you
ask. Not worth treating as a rule.

## The three-question test (steal this)

Point these at any status screen or notification you own:

1. **Does it fit on one screen?** Actually count the lines. Don't estimate — people are bad at estimating this
   about things they built.
2. **Does it show the weird stuff, or everything?** If 18 of 20 rows say the same thing, those 18 rows are
   costing you space and giving you nothing.
3. **Would I do something *different* because of this interrupt?** If the answer is the same every time, delete
   the interrupt. Not "tune it." Delete it.

## The comprehension check for this phase

Same spirit as Phase 1's 5-second-story test, adapted for operational displays. Show someone the screen for five
seconds, take it away, then ask:

- **Check A —** "What needs your attention right now?" They should be able to name a specific thing. If they
  describe the *layout* ("a list of projects") instead of a *finding*, the screen failed.
- **Check B —** "How much of what you just saw was normal?" They should be able to say roughly. If everything
  looked equally important, the screen isn't separating exceptions from background.
- **Check C —** For each interrupt the system sends: "What would you do differently if you got this right now
  versus an hour from now?" If there's no difference, it shouldn't be an interrupt.

## What this brief does not claim

The one-screen threshold is an expert's opinion, not a measurement, and no source in this track tested what
happens at 1.5 screens versus 3. The alerting test comes from running huge web services, and applying it to a
developer's command-line tool is an analogy — a good one, but an analogy. And the one genuinely rigorous source
here identified four causes of alert fatigue that **we could not read**, because the paper is behind a paywall
that blocked automated access. So if this brief sounds confident, that confidence is doing more work than the
evidence underneath it, and you should know that.
