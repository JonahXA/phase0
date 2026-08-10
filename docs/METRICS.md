# What to measure, and what the numbers have to hit

The instrumentation exists to answer exactly one question per Phase 1 game:
**kill it, or double down?** Anything that doesn't feed that decision is noise.

## The kill criteria

Written down before building, so they can't be rationalized afterward. Mirrored in
`Config.KillCriteria`.

| Gate | Threshold | Where to read it |
|---|---|---|
| D1 retention | **≥ 20%** after 5,000 organic visits | Creator Dashboard → Analytics → **Engagement** |
| Organic CCU | **≥ 50** within 2 weeks | Creator Dashboard → **Overview** (peak CCU) |

Miss either → kill the game and start the next one. Hit both → invest in art, live-ops,
and only then a $100 ad test.

The hardest part of this is not the measurement. It's actually killing the game.

## Why D1 and not revenue

At beginner monetization (~0.15 Robux/visit) a game needs ~200,000 visits just to clear
the 30,000 Robux minimum cashout. You cannot wait for revenue to tell you whether a
game works — you'd burn a month per signal. **D1 retention is the leading indicator**,
and it's also the input Roblox's own discovery algorithm weights most heavily since it
moved to a 28-day multi-phase retention model.

Revenue per visit is a Phase 2 metric. Retention is the Phase 1 metric.

## What this repo emits

**Built-in, no code required:** D1/D7/D28 retention, DAU, session length, and revenue
all appear on the Creator Dashboard automatically for any published experience. Trust
these for the headline numbers.

**Custom events** (Analytics → Custom Events) exist to answer things the built-in
charts can't segment.

> Verifying they arrive: don't wait on the charts, which lag. Each of the Economy,
> Funnel, and Custom analytics pages has a **View Events** button at the top showing a
> near-real-time feed of the most recent events. That is the tool for confirming
> instrumentation works; the charts are for reading results once data accumulates.
>
> Nothing appears from a Studio playtest — events require a **published** experience
> and fire **server-side only**.

| Event | Why it's here |
|---|---|
| `Retention_D1` … `Retention_D28` | Segmentable retention — lets you ask "did players who bought something retain better?" via the `paid` field |
| `NewPlayer` / `ReturningPlayer` | New-vs-returning split per day |
| `SessionHeartbeat` | Session-length floor that survives a server crash |
| `SessionEnd` | Exit balance and purchase count |
| `PurchaseCompleted` | Robux amount + which product |
| `GamePassPurchased` | Pass conversion |
| `DataLoadFailed` | **Watch this.** Nonzero means some players' progress is silently vanishing, which corrupts every retention number above it |
| `SuspiciousClickRate` | Someone is scripting the click remote |

**Onboarding funnel** (Analytics → Funnels): Joined → DataLoaded → FirstClick →
FirstShopOpen → FirstPurchase. The step with the steepest drop is your next task.

**Economy events** (Analytics → Economy): every coin in or out, tagged with a reason
(`ClickReward`, `ProductPurchase`, `ProductRollback`). The ending-balance field is what
makes currency-duplication exploits visible as a divergence between total sourced and
total held.

## Reading it honestly

- **Don't judge retention on paid traffic.** Sponsored visits cost $0.01–0.05 each
  while a visit earns roughly $0.0019 at good monetization. Paid traffic also retains
  worse than organic, so mixing them makes a game look deader than it is. Measure
  organic, then decide whether ads are worth it.
- **Five thousand visits is the minimum for a D1 read.** Below that you're looking at
  noise and will talk yourself into keeping a dead game.
- **A freshness bump is not traction.** Publishing an update temporarily boosts you in
  Trending. If your CCU spike decays to baseline within 48h of an update, that was the
  algorithm, not your game.
