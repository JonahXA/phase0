# phase0

Pipeline test for the Roblox project. A deliberately boring clicker that exercises
every system a real game needs, end to end:

- **Rojo** source-of-truth in text, syncing into Studio
- **Server-authoritative economy** with rate limiting
- **DataStore persistence** with retries, migration, autosave, and shutdown flush
- **Monetization** — one game pass, two developer products, with an idempotent
  `ProcessReceipt`
- **Analytics** — retention buckets, onboarding funnel, economy events

**Phase 0 is not trying to be fun or to make money.** It exists so that when a Phase 1
idea is worth building, the plumbing is already solved and the only variable is whether
players like the game.

## Quickstart

```bash
rokit install
rojo serve
```

Then connect the Rojo plugin in Studio. Full walkthrough: [docs/SETUP.md](docs/SETUP.md).

## Before it does anything monetized

Fill in the four IDs in [`src/shared/Config.luau`](src/shared/Config.luau). They're `0`
by default and purchases are inert until you set them.

## Layout

```
src/shared/            Config, remote definitions, saved-data schema
src/server/            DataService, EconomyService, MonetizationService, Telemetry, World
src/client/            HUD and input forwarding
docs/PHASE0-CHECKLIST.md  Ordered do-this-then-report-back list. Start here.
docs/SETUP.md          Reference: empty Studio to measured live experience
docs/METRICS.md        What to measure and the kill criteria
```

## The rule this repo is built around

Every number the client sends is a lie until the server validates it. The click remote
carries no payload, the client never computes a balance, and `EconomyService.addCoins`
is the only function permitted to change coins.

## Next

Phase 1 is a portfolio of small bets: 2–3 week builds in trending, low-art-burden
genres, each measured against the kill criteria in [docs/METRICS.md](docs/METRICS.md).
