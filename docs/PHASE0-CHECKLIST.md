# Phase 0 — do-this-then-report-back checklist

Everything here needs a human: a Roblox account, Studio, and the Creator Dashboard.
None of it can be done from the repo side.

**Work it in order.** Sections 3 and 4 are deliberately separate passes — verify the
gameplay loop *before* adding monetization, so that when something breaks you know
which layer broke it.

Tick boxes as you go. Anything that fails, stop and note it; don't work around it.

---

## 0. Start this first — it has a clock on it

- [ ] **ID-verify your Roblox account.**
      Roblox.com → gear icon → **Settings → Account Info → Verify My Age**.
      Government ID or facial age estimation both work.

Why first: it can take up to a day, DevEx requires it eventually, and it raises your
audio upload allowance from 100 to 2,000 assets per 30 days. Nothing today depends on
it, so kick it off and carry on.

---

## 1. Toolchain and plugin

- [ ] **Open a NEW terminal.** The Rokit install added `~/.rokit/bin` to PATH, but any
      terminal opened before that won't have it.

- [ ] **Change into the repo — every command in this document assumes it.**

      cd C:\Users\Jonah\roblox\phase0

      Rokit resolves tools from the nearest `rokit.toml`, so that different projects
      can pin different versions. Outside a project folder it refuses to guess.

- [ ] Verify the tools resolve:

      rojo --version

      Expect `Rojo 7.7.0`. Two different failures, two different causes:

      - `Failed to find tool 'rojo' in any project manifest file`
        → Rokit is working, you're just not in the repo. Re-run the `cd` above.

      - `'rojo' is not recognized as an internal or external command`
        → PATH hasn't picked up `~/.rokit/bin`. Close every terminal and open a
          fresh one.

- [ ] **Install the Rojo Studio plugin.** Preferred, from the repo directory:

      rojo plugin install

      This installs the plugin build that matches your CLI exactly (7.7.0), which
      rules out version-mismatch sync bugs and avoids the Creator Store entirely.
      Restart Studio afterwards.

      Manual alternative — Studio → **Toolbox** → **Creator Store** → **Plugins** →
      search "Rojo". The legitimate one is published by the group **Rojo Foundation**
      and is asset ID **13916111004**.

      **Match the asset ID, not the name.** Publisher names are trivially
      impersonated, and a Studio plugin runs with full access to your place — it can
      read source, inject scripts, and phone home. The official docs at
      <https://rojo.space/docs/v7/getting-started/installation/> vouch for that ID.

      It appears under the **Plugins** tab in the ribbon once installed.

---

## 2. Create and publish the place

- [ ] Studio → **File → New** → **Baseplate**.

- [ ] **File → Publish to Roblox As...** — give it any name. Keep it **Private**.

      Private matters: a half-built clicker picking up stray visits pollutes the very
      retention numbers this whole exercise exists to measure.

- [ ] **File → Experience Settings → Security → enable "Enable Studio Access to API
      Services".** Then click **Save**.

      Older guides and videos call this "Home → Game Settings". That dialog was
      renamed to **Experience Settings** and moved under **File** — if you're hunting
      the Home ribbon for it, that's why you can't find it.

      If **Experience Settings** is greyed out or missing, you haven't published yet.
      It configures a published experience, so do the publish step above first.

      This is the single most common way to lose an hour on this setup. Without it
      every DataStore call fails inside Studio and the failure looks like a code bug.

      You do **not** need "Allow HTTP Requests" — nothing here calls an external
      service.

- [ ] **View → Output** so the Output window is visible. You'll need it constantly.

---

## 3. Pass 1 — prove the loop (leave the monetization IDs at `0`)

- [ ] From the repo root (`cd C:\Users\Jonah\roblox\phase0` if you opened a new
      terminal), start the sync server and **leave it running**:

      rojo serve

- [ ] In Studio: **Plugins** tab → **Rojo** → **Connect**.

      You should see `Server` appear in ServerScriptService, `Shared` in
      ReplicatedStorage, and `Client` in StarterPlayer → StarterPlayerScripts.

- [ ] Press **Play** (F5).

Now verify each of these. **This is the actual test — don't skim it.**

- [ ] Output prints `[Phase0] server up (data v1)`
- [ ] A yellow neon cube is visible at the origin with a "CLICK ME" label
- [ ] A coin counter sits top-left; it reads `0 coins`, not `loading...`
- [ ] Clicking the cube increments the counter
- [ ] The on-screen **CLICK** button also increments it
- [ ] **Verify the rate limiter.** Holding the button does nothing — `Activated`
      fires once per press and there is no auto-repeat — and hand-tapping can't
      exceed the ~6.7/sec cap anyway, so neither proves anything.

      The threat is a script firing the remote in a loop, so test that. During a
      playtest, open **View → Command Bar** (server context, the default) and run:

          local p = game:GetService("Players"):GetPlayers()[1]
          local E = require(game:GetService("ServerScriptService").Server.EconomyService)
          for i = 1, 100 do E.handleClick(p) end

      - Counter rises by **~1** → working. All 100 calls fell inside one 0.15s
        window; one honored, 99 dropped.
      - Counter rises by **~100** → the limiter is broken. Stop and report it.

      Run it a few times and Output should eventually show
      `[Economy] ... exceeded click rate limit`, confirming the suspicion counter.
- [ ] **SHOP** opens a panel with three buttons. Clicking them logs a warning about
      unconfigured IDs — that is correct behavior at this stage, not a bug.

- [ ] **The one that matters most:** stop the playtest, press Play again. **Your coin
      balance should still be there.** If it resets to 0, persistence is broken —
      that's almost always the API Services toggle in step 2, but tell me either way.

- [ ] Scan Output for anything red, or any warning starting `[DataService]`,
      `[Monetization]`, or `[Telemetry]`. Copy them if present.

> **Expect zero analytics during Pass 1.** `AnalyticsService` only emits from the
> server in a *published* experience — Studio playtests produce nothing, by design.
> There is no setting to turn on. You verify telemetry in Pass 2, live.

**Do not continue to Pass 2 until the balance survives a rejoin.**

---

## 4. Pass 2 — monetization

### 4a. Create the products

This happens on the **Creator Dashboard**, which is a website — not Roblox Studio.
<https://create.roblox.com/dashboard/creations> → select your experience.

Icons are required for both, max **512×512**, `.jpg`/`.png`/`.bmp`. Any square image.

- [ ] **Monetization → Passes → Create pass.** Name it "2x Coins", add an icon and
      description, pick a category, create.

- [ ] **Set its price — a separate step, and the navigation is genuinely hidden.**

      Open the pass, then click the **☰ hamburger at the top-left of the page**. That
      expands a sidebar with **Basic Settings** and **Sales**. Choose **Sales** →
      enable **Item for sale** → price **1** → **Save Changes**.

      Or go straight there:
      `/dashboard/creations/experiences/{universeId}/passes/{passId}/sales`

      Roblox's own docs say to hover the pass and pick "Sales" from the ⋯ menu. That
      is wrong as of Aug 2026 — that menu holds only Edit settings, Copy Pass ID, and
      Copy Thumbnail ID. The sidebar is the only in-UI route.

      A pass that isn't explicitly put on sale cannot be purchased, and the failure is
      silent — it reads as a code bug.

      If the save is rejected, check the pass has an **icon uploaded** under Basic
      Settings.

- [ ] **Monetization → Developer Products → Create developer product.** Make two,
      named "100 Coins" and "500 Coins". Unlike passes, **price is set at creation** —
      1 Robux each.

- [ ] **Collect the four IDs:** hover an item's thumbnail → **⋯** → **Copy Asset ID**.

Price them at 1 Robux purely so self-testing is free in practice. Note you'll earn
**0** Robux back from a 1-Robux sale — the 70% share rounds down to zero. That's
expected; it is not a broken payout.

### 4b. Wire the IDs in

- [ ] Copy each of the four IDs (they're in the URL of each item's page, and listed on
      the dashboard) into `src/shared/Config.luau`:

      Config.GamePasses.DoubleCoins  = <pass id>
      Config.DeveloperProducts.Coins100 = <product id>
      Config.DeveloperProducts.Coins500 = <product id>

- [ ] Save. Rojo pushes the change into Studio automatically if it's still connected.

- [ ] **File → Publish to Roblox** so the live place has the updated scripts.

### 4c. Test against the LIVE game, not Studio

- [ ] Close Studio's playtest. Open the experience from **roblox.com** and join it.

      This is not optional pedantry: Studio does not exercise `ProcessReceipt` the way
      production does. The idempotency logic — the highest-risk code in the project —
      only truly runs live.

- [ ] Buy **100 Coins**. Verify:
      - [ ] Your balance goes up by exactly **100** — not 0, not 200
      - [ ] It goes up **once**

- [ ] Buy **500 Coins**. Balance goes up by exactly 500.

- [ ] Buy the **2x Coins** pass. Verify:
      - [ ] The green `2x ACTIVE` badge appears **without rejoining**
      - [ ] The "2x Coins (Pass)" shop button disappears
      - [ ] Clicking now grants **2** coins per click instead of 1

- [ ] Leave and rejoin. Balance and the 2x badge both persist.

### 4d. Confirm telemetry is actually arriving

- [ ] Creator Dashboard → your experience → **Analytics**. Open the **Custom**,
      **Funnel**, and **Economy** pages, and on each click **View Events** at the top.

      That's a near-real-time feed of incoming events — use it rather than waiting on
      the charts, which lag well behind.

- [ ] Confirm you can see, roughly in order: `NewPlayer`, the `Onboarding` funnel
      steps (Joined → DataLoaded → FirstClick → FirstShopOpen → FirstPurchase),
      `PurchaseCompleted`, and `Coins` economy events tagged `ClickReward` and
      `ProductPurchase`.

- [ ] **Check `DataLoadFailed` is absent.** If it's firing, some players' progress is
      silently vanishing and every retention number downstream is polluted.

---

## 5. Then check back in with me

Bring these four things — they're what I need to tell whether it actually worked:

1. **Any red errors or `[Prefix]` warnings** from Output or the live game's console.
2. **Did the balance survive a rejoin?** (Pass 1 and again in Pass 2.)
3. **Did the click rate cap hold** at ~6–7/sec under a held button?
4. **Did each purchase grant exactly once**, and did the 2x badge flip live?

If you want me poking at the live data model directly rather than reading your log
paste, turn on **Assistant Settings → MCP Servers → Enable Studio as MCP server** and
leave Studio open.

---

## 6. Do NOT do these yet

- **Don't make the experience public.** Not until it's verified and you've decided
  it's a Phase 1 candidate.
- **Don't buy ads.** Paid visits cost 5–26× what a visit earns. Ads are for a game
  with proven retention, and this one has no players by design.
- **Don't commission art.** Same logic. Money spent before a D1 number is a multiplier
  on an unknown.
- **Don't start building a Phase 1 game.** Phase 0 isn't done until the checklist above
  is green.
- **Don't skip the Pass 1 / Pass 2 split** by wiring the IDs in from the start. If it
  breaks you won't know which layer did it.
