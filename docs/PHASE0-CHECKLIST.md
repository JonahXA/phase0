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

- [ ] Verify the tools resolve:

      rojo --version

      Expect `Rojo 7.7.0`. If it says "not recognized", the PATH change hasn't taken —
      close every terminal and open a fresh one.

- [ ] **Install the Rojo Studio plugin.**
      Studio → **Toolbox** → **Creator Store** → filter to **Plugins** → search "Rojo"
      → install the one by **rojo-rbx**.
      It appears under the **Plugins** tab in the ribbon once installed.

---

## 2. Create and publish the place

- [ ] Studio → **File → New** → **Baseplate**.

- [ ] **File → Publish to Roblox As...** — give it any name. Keep it **Private**.

      Private matters: a half-built clicker picking up stray visits pollutes the very
      retention numbers this whole exercise exists to measure.

- [ ] **Home → Game Settings → Security → enable "Enable Studio Access to API
      Services".** Save.

      This is the single most common way to lose an hour on this setup. Without it
      every DataStore call fails inside Studio and the failure looks like a code bug.

      You do **not** need "Allow HTTP Requests" — nothing here calls an external
      service.

- [ ] **View → Output** so the Output window is visible. You'll need it constantly.

---

## 3. Pass 1 — prove the loop (leave the monetization IDs at `0`)

- [ ] From the repo root, start the sync server and **leave it running**:

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
- [ ] **Hold the click button down.** The counter should climb at roughly **6–7 per
      second and no faster**. If it climbs hundreds per second, the rate limiter is
      not working — stop and tell me.
- [ ] **SHOP** opens a panel with three buttons. Clicking them logs a warning about
      unconfigured IDs — that is correct behavior at this stage, not a bug.

- [ ] **The one that matters most:** stop the playtest, press Play again. **Your coin
      balance should still be there.** If it resets to 0, persistence is broken —
      that's almost always the API Services toggle in step 2, but tell me either way.

- [ ] Scan Output for anything red, or any warning starting `[DataService]`,
      `[Monetization]`, or `[Telemetry]`. Copy them if present.

**Do not continue to Pass 2 until the balance survives a rejoin.**

---

## 4. Pass 2 — monetization

### 4a. Create the products

Creator Dashboard → **Creations** → your experience → **Associated Items**.

- [ ] **Passes → Create Pass.** Name it "2x Coins". Any square image works as the icon.
      After it's created, open it → **Sales** → enable **Item for Sale** → set price to
      **1 Robux**.

      A pass that isn't explicitly put on sale cannot be purchased, and the failure is
      silent.

- [ ] **Developer Products → Create.** Make two, priced at **1 Robux** each:
      one named "100 Coins", one named "500 Coins".

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
