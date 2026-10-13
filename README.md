# Showdown for iPhone

[Pokémon Showdown](https://play.pokemonshowdown.com) in a full-screen iPhone app: the real site, exactly as Showdown designed it, without the browser around it.

- **No Safari bars.** The whole screen is Showdown.
- **No ads.** Showdown's ad network and the ad exchanges it calls are blocked, so the ad slots never appear.
- **No zooming.** The page is locked at your screen width; pinch and double-tap zoom are off.
- **Feels like an app.** Stays signed in, keeps your teams, plays battle sounds (respecting the silent switch), opens outside links in an in-app Safari sheet, shows Showdown's prompts as iOS alerts, and lets you share downloaded team backups and replays.

Teams live in the app's own storage, separate from Safari. To bring teams over, use Teambuilder → *Upload to Showdown database* in Safari and load them in the app, or copy a backup from Safari's Teambuilder and import it.

## Installing without the App Store

GitHub Actions builds an unsigned `Showdown.ipa` on every push (**Actions → Build → Artifacts**, or the **Releases** page for tagged versions). Install it with [SideStore](https://sidestore.io) or [AltStore](https://altstore.io), which sign it with your Apple ID. A free Apple ID signature lasts 7 days and SideStore refreshes it automatically.

## Code

| File | What it does |
| --- | --- |
| `App/ShowdownViewController.swift` | The web view: zoom lock, navigation rules, dialogs, downloads, offline screen |
| `App/AdBlocker.swift` | Content-blocker rules for ad and tracking domains |
| `project.yml` | [XcodeGen](https://github.com/yonaskolb/XcodeGen) spec: `xcodegen generate` makes the Xcode project |

---

Unofficial. Pokémon Showdown is by Smogon and its contributors; Pokémon is © Nintendo, Game Freak and The Pokémon Company.
