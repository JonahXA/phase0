# Phase 0 setup

Goal: prove you can go **idea → live → measured**. Not to make money. If you finish
this doc and see your own retention numbers on the Creator Dashboard, Phase 0 succeeded.

Steps 1 and 3 need decisions only you can make (installing tooling, creating the
experience). Everything else is mechanical.

---

## 1. Install the toolchain

The repo pins tool versions in `rokit.toml` so the build is reproducible. Rokit is
the toolchain manager (successor to Aftman).

Install Rokit from <https://github.com/rojo-rbx/rokit/releases> — grab
`rokit-1.2.0-windows-x86_64.zip` (~3.6 MB), extract `rokit.exe`, then:

```bash
rokit self-install
```

Then from the repo root:

```bash
rokit install
```

That pulls Rojo 7.7.0, StyLua 2.5.2, and Selene 0.31.0 at the pinned versions.

Verify — **from inside the repo**, since Rokit scopes tools to the nearest
`rokit.toml` and will report `Failed to find tool 'rojo'` anywhere else:

```bash
rojo --version
```

> If you'd rather not use Rokit, download `rojo.exe` directly from
> <https://github.com/rojo-rbx/rojo/releases> and put it on your PATH. You lose
> version pinning; everything else works the same.

---

## 2. Install the Rojo Studio plugin

This is the half that receives the sync. Easiest route, from the repo directory:

```bash
rojo plugin install
```

That pulls the plugin matching your pinned CLI version, so the two can't drift.

If you'd rather install by hand: **Toolbox → Creator Store → Plugins**, search "Rojo",
and take the one published by the group **Rojo Foundation** — asset ID
**13916111004**, which is what the [official install docs](https://rojo.space/docs/v7/getting-started/installation/)
link to. Verify the ID rather than the publisher name; names can be impersonated and a
Studio plugin runs with full access to your place.

(`rojo-rbx` is the GitHub organization, not the Roblox publisher. Different names for
the same project.)

---

## 3. Create the experience

1. Studio → **New → Baseplate**.
2. **File → Publish to Roblox As...** — name it whatever, set it **Private** for now.
3. **File → Experience Settings → Security** → turn ON **Enable Studio Access to API
   Services** → **Save**. Without this, every DataStore call fails in Studio and you'll
   spend an hour debugging a setting.
> Older guides say "Home → Game Settings". The dialog is now **Experience Settings**
> under the **File** menu. If it's greyed out, publish the place first — it configures
> a published experience, not a local file.

**There is no analytics setting to enable.** Analytics needs no setup; it has a
constraint instead: `AnalyticsService` events fire **only from the server, only in a
published experience**. Studio playtests and client-side calls produce nothing. That
is expected, not a fault — so don't go looking for a toggle to fix it.

---

## 4. Wire up monetization IDs

All four IDs live in [`src/shared/Config.luau`](../src/shared/Config.luau) and are `0`
until you fill them in. Monetization is inert (and logs a warning) while they're zero,
so the game still runs — you just can't buy anything.

**Game Pass** — Creator Dashboard → your experience → **Associated Items → Passes →
Create Pass**. Set a price. Copy the ID from the URL.

```lua
Config.GamePasses.DoubleCoins = 123456789
```

**Developer Products** — same page, **Developer Products → Create**. Make two:
100 coins and 500 coins. Copy both IDs.

```lua
Config.DeveloperProducts.Coins100 = 987654321
Config.DeveloperProducts.Coins500 = 987654322
```

---

## 5. Sync and run

From the repo root:

```bash
rojo serve
```

In Studio, open the Rojo plugin → **Connect**. Your `src/` tree now lands in
ServerScriptService / ReplicatedStorage / StarterPlayerScripts, and edits to local
files appear in Studio live.

Press **Play**. You should see:

- a yellow neon cube you can click
- a coin counter that goes up
- a SHOP button opening three purchase buttons
- `[Phase0] server up (data v1)` in the Output window

Then **publish again** so the live place has the scripts.

---

## 6. Connect Claude Code to Studio (optional but recommended)

Studio ships an MCP server, which lets me inspect and edit your place directly rather
than only writing files.

In Studio: open the **Assistant** panel → the **⋯** menu → **Manage MCP Servers** →
turn on **Enable Studio as MCP server**. A green indicator with a connected-client
count confirms it worked. The server runs locally over stdio and only works while
Studio is open.

**Quick connect** (in that same panel) lists clients it detects — Claude Desktop,
Cursor, VS Code. Claude Code is configured by file instead, and this repo already
ships it as [`.mcp.json`](../.mcp.json):

```json
{
  "mcpServers": {
    "Roblox_Studio": {
      "command": "cmd.exe",
      "args": ["/c", "%LOCALAPPDATA%\\Roblox\\mcp.bat"]
    }
  }
}
```

Claude Code loads MCP servers at startup, so **restart it** after enabling the toggle.

Rojo and MCP are complementary, and worth keeping both: **Rojo owns the source of
truth** (text, git, reviewable diffs), **MCP is for inspection and one-off surgery**
(reading the live data model, running a quick Luau snippet, poking at a bug). Don't
let me author gameplay code through MCP — it lands in the place file and not in git.

---

## 7. Verify the whole chain

Checklist — this is what "pipeline works" actually means:

- [ ] Coins go up on click, and the rate limiter drops spam (hold the button down; you
      should cap around 6–7/sec, not hundreds)
- [ ] Coins **persist across rejoin** (leave, rejoin, balance is still there)
- [ ] Buying a developer product grants coins exactly once
- [ ] Buying the game pass flips the 2x badge on without a rejoin
- [ ] Creator Dashboard → Analytics shows your custom events (allow up to ~1 hour)
- [ ] Creator Dashboard → Funnels shows the `Onboarding` funnel with drop-off

Test purchases against a real published place. In Studio, product purchases don't hit
`ProcessReceipt` the way they do live — the idempotency path only truly exercises in
production.

---

## Known limitations (deliberate, not bugs)

- **No cross-server session lock.** `DataService` is a readable hand-rolled store. If
  you take any game past Phase 0, swap it for
  [ProfileStore](https://github.com/MadStudioRoblox/ProfileStore). Real money on a
  store without session locking eventually means duplicated or lost purchases.
- **Workspace is built in code.** Fine while the world is one cube. The moment you
  have real art, the `.rbxl` becomes the source of truth for Workspace and Rojo syncs
  only scripts into it.
- **The game is not fun.** That's the point of Phase 0. Fun is Phase 1's problem.
