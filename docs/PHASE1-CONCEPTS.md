# Phase 1 — candidate concepts

Three concepts, each scoped to a 2–3 week build on the Phase 0 pipeline. Pick one,
ship it, measure it against the kill criteria, and either double down or start the
next. Do not build two at once.

---

## What the research actually says

**The breakout pattern is time-to-first-action.** Steal a Brainrot (peaked above 25M
concurrent) and Grow a Garden (above 20M) share one thing: a player reaches a clear,
repeatable activity inside the first minute, and the loop is understandable in about
30 seconds of watching. Neither is mechanically deep. Both are legible instantly.

**Grow a Garden's own reviewers name its discipline as the strength** — it doesn't
punish you for stepping away and doesn't demand reflexes. Its sequel was criticised
for bloat. Restraint is the feature.

**What to avoid isn't a genre, it's a posture.** Generic clones, oversized builds,
concepts that risk an IP strike, and — the one that matters most here — **games that
need a crowd before they're fun.**

**Market concentration is severe.** In some subgenres the top two games hold 80%+ of
revenue. Roblox is countering this by pushing novelty (Standout Games, Incubator and
Jumpstart programmes, the raised DevEx rate). Small, novel, retention-tight is the
bet the platform itself is making.

---

## The constraint that eliminated the obvious answer

**Every concept here must be fun at 1 concurrent player.**

Steal-and-defend is the highest-grossing shape on the platform right now, and it was
the original recommendation. It's the wrong choice for us, because it requires other
players to steal from. A brand-new game has zero players. The format only works once
you already have the audience you're trying to get — a cold-start trap that no amount
of build quality solves.

Anything requiring a populated server is out: PvP, trading, social-deduction, most
co-op. That is a hard filter, not a preference.

**Secondary filter — art burden.** Jonah is strong on systems, economy tuning and
analytics; weak on art, animation and 9–14-year-old taste. Claude shares the same
weakness, so this is a *correlated* gap, not a complementary pairing. Concepts are
therefore chosen so that content is **data** (recipe tables, progression curves,
spawn rules) rather than **authored art**.

---

## Concept A — Push-your-luck grow game

**Loop.** Plant a crop. It grows and mutates over time under a server-wide weather
system. At any moment you choose: harvest now for a guaranteed modest payout, or let
it keep mutating for a bigger one — with a rising chance it rots and you get nothing.

**Why it's not just Grow a Garden.** That game is pure idle: waiting is strictly
good. Adding a harvest-timing decision turns dead waiting time into a real choice,
which is the thing idle games usually lack. One decision, repeated, legible.

**Fun at 1 CCU?** Yes. Fully solo. Weather is global, which makes a shared world feel
populated without needing anyone else present.

**Art burden.** Low. A handful of simple plant meshes at three growth stages, colour
tinted per mutation. Mutations are data, not new models.

**Monetization.** Time skips, extra plots, a rot-insurance pass, seed multipliers.
Simulator-family monetization is the highest revenue-per-visit on the platform.

**Build risk.** Balancing the risk curve. Too punishing and it feels unfair; too soft
and the decision is fake. This is a tuning problem, which is the right kind of problem
for this skill set.

---

## Concept B — NPC-raided tycoon

**Loop.** Build and upgrade a base that generates income. NPC waves periodically raid
it. Defend, repair, expand. Later: opt-in player raids for higher stakes.

**Why it's interesting.** It takes the steal-and-defend tension that's currently
dominating the charts and makes it **PvE-first**, so it works from the first player.
Real-player raiding becomes an upgrade unlocked by having an audience, rather than a
prerequisite for having one.

**Fun at 1 CCU?** Yes, by construction — this concept exists specifically to solve
the cold-start problem that eliminated steal-and-defend.

**Art burden.** Medium — the highest of the three. Base parts can be blocky and
stylized, but raiders need some animation. This is the concept most likely to expose
the art gap.

**Monetization.** Defence upgrades, instant repairs, income multipliers, cosmetic
base skins.

**Build risk.** Scope creep. Tycoons invite endless upgrade trees. Ship with a small
tree and extend only if retention justifies it.

---

## Concept C — Combine-and-discover

**Loop.** Start with a few basic elements. Combine any two to discover a third. Build
a collection, chase rare recipes, show off discoveries.

**Why it fits this skill set better than anything else here.** The content *is* a
recipe table. Hundreds of items with no art authoring — icons and names. Depth comes
from combinatorics, which is a data-design problem, not an art problem.

**Fun at 1 CCU?** Yes. Discovery is inherently solo. A global "who discovered this
first" board adds social pull with zero dependence on anyone being online.

**Art burden.** Lowest of the three by a wide margin.

**Monetization.** Hint packs, extra discovery slots, a reveal-a-recipe pass, cosmetic
display shelves.

**Build risk.** Highest novelty risk. It's the least proven shape for the Roblox
audience specifically — closer to a puzzle game than a simulator, and it may skew
older than the core demographic. Also the most front-loaded content work: a recipe
tree needs to be designed before launch, not after.

---

## Recommendation

**Start with A, then C, then B.**

A is the best risk-adjusted first bet: proven genre shape, one genuine novel twist,
lowest art burden of the proven formats, and the tuning work lands squarely on the
strengths. C is the highest-upside and lowest-art option but carries real audience
risk. B is the most likely to stall on art, so it should not be the first attempt.

Whichever you pick: **scope it to two weeks of build.** The portfolio approach only
works if the bets are small enough that killing one doesn't hurt.

---

## Kill criteria — unchanged, and the whole point

From `METRICS.md`, decided before any of this was designed:

| Gate | Threshold |
|---|---|
| D1 retention | **≥ 20%** after 5,000 organic visits |
| Organic CCU | **≥ 50** within 2 weeks |

Miss either → kill it, start the next concept. Hit both → invest in art, live-ops,
and only then a $100 ad test.

The hard part was never the code. It's killing a game you like that missed the bar.
