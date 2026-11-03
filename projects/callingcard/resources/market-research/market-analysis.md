# CallingCard: Market Analysis

*Market Analyst (performed by the Master Orchestrator in role) · 2026-11-03 · Phase: Design*

> **Framing.** This is an **unofficial design pitch** about a feature of an existing game, Call of Duty (Activision). We describe how its calling cards work today only as context. We use no Activision artwork, logos or text. Any prototype would be a **standalone concept demo with original placeholder art**. It would not be a mod or a recreation of Call of Duty.
>
> **About the numbers.** This is desk research from general industry knowledge, without live data access. **Every figure is an estimate** (marked "est.") and should be checked before it goes into any external pitch. Feature descriptions reflect these games as we understand them in late 2026. Live-service games change often.

## 1. Executive summary

**Recommendation: GO for the design pitch and a small web concept demo.**

- **The problem is real.** CoD players earn a large number of calling cards each year (est. several hundred per annual release, from challenges, weapon camos/mastery, events, prestige, ranked play, battle passes and store bundles). Only one can be equipped, and it is mostly seen briefly in lobbies, killcams and scoreboards. The collection has no *use*. Its only value is the flex of the one card on show.
- **Other games have solved parts of this.** Four patterns give cosmetic collections value: (1) **showing more** (multi-slot showcases, titles), (2) **completion meta** (sets, albums, seals), (3) **collection-powered minigames** (Gwent, Triple Triad, Marvel Snap's variant chase), and (4) **trackable proof of skill** (Apex badges and trackers, Destiny's gilded seals). CoD uses (4) a little and (1) to (3) barely at all.
- **The biggest opportunity** is a **side mode where the cards you have earned are playable pieces**. It lives outside the shooter's balance, so it carries no competitive-integrity risk. Precedent: Gwent in The Witcher 3 grew into a standalone game, and Triple Triad in Final Fantasy VIII is still fondly remembered decades later. Both turned collectibles into a game people chased.
- **The biggest risks** are a **pay-to-win perception** (if store-bundle cards become strong) and **gatekeeping** (if veterans' collections crush newcomers). Both can be solved with rules (Section 6).

## 2. How calling cards work today (context)

| Aspect | Today (as we understand it) |
|---|---|
| Sources | Challenge completions (including hidden "dark ops"-style challenges), weapon camo/mastery progress, limited-time events, prestige/seasonal levels, ranked-play rewards, battle-pass tiers, store bundles |
| Count | Est. several hundred per annual title; some carry forward between titles |
| Equip | **One** at a time, shown with the emblem and player name |
| Where it's seen | Pre-/post-game lobby, killcam/"killed by" banner, scoreboard, player card |
| Value | Pure flex. A rare mastery card signals skill or grind. Most cards are never equipped or looked at again. |
| Player sentiment (qualitative, est.) | Players treat mastery/hard-challenge cards as prestige. Battle-pass and bundle cards are seen as filler. "Too many cards, no reason to care" is a common sentiment in community discussion. |

## 3. How other games give cosmetic collections value

| Game | System | What creates value | Lesson for calling cards |
|---|---|---|---|
| **Apex Legends** | Banner with **3 badge slots** plus **3 stat trackers** per legend | Badges prove feats ("20 bombs", "4K damage"). Tracker choice is self-expression. Rare badges are respected because they can't be bought. | **Multi-slot showcase.** Earned proof beats purchased flair. |
| **Destiny 2** | **Triumphs** and **Seals**, which grant **titles** shown over the player's name. Seals can be **gilded** each season. | Long, visible completion goals. A title signals a whole set of feats, not one item. Gilding brings back an old goal. | **Sets that grant a visible title.** Seasonal re-gilding. |
| **Halo (Infinite / MCC)** | Armor cores and coatings, nameplates, emblems. MCC hidden **skulls** and achievements. | Customization depth. Hidden collectibles create community hunts. | **Hidden collectibles** give "secret knowledge" value. |
| **Fortnite** | Locker, banners, **styles unlocked by challenges**, set groupings (e.g. themed sets), loading screens with hidden clues (historically used for secret challenges) | Cosmetics that change state through play. Loading-screen art used as treasure-map puzzles. | **Card art that hides puzzle clues**, and cards that upgrade visually through play. |
| **Marvel Snap** | **Collection Level**, card **variants** (borders, flares, art variants, split levels), card Series | Cosmetic upgrades of a card you *play with* every match. Collection Level is the main progression. | **Cards that are also gameplay pieces** get looked at hundreds of times, so upgrades feel meaningful. |
| **Hearthstone** | Golden/Signature/Diamond card treatments, collection completion | Premium treatment of cards you already use | Animated/premium frames can be the *monetized* layer, as long as power isn't. |
| **The Witcher 3 (Gwent) / FF VIII (Triple Triad) / FF IX (Tetra Master)** | **In-game card minigames** using collectible cards found and won in the world | Players hunted cards *because* they played the minigame. Gwent became a standalone product. | **Strongest precedent** for "a mode that gives a collection value". |
| **Valorant** | Player cards (wide banner + tall art) plus titles | Close analog to CoD calling cards; also low-value for many players | Shows the "just a banner" problem isn't unique to CoD |
| **Overwatch 2** | Player icons, name cards, titles, highlight intros, sprays | Sprays and intros are *used in play* (expressive, non-stat) | **Expressive in-match use** that is non-stat |
| **CS2** | Stickers on weapons, tournament capsules, real-money market | Combinations and scarcity create huge value | Shows the power of combinations. **Avoid** real-money trading and gambling-style mechanics (regulatory and reputational risk). |
| **Sticker albums (Panini) / Pokemon TCG Pocket binders** | Physical-style album pages with empty slots and set completion | The **empty slot** is the motivator. "Got, got, need" trading culture. | **Album pages with silhouettes** turn a pile into a checklist |

**Pattern summary (est. strength of effect on collection engagement):**
1. Collection-powered minigame: **very high** (but the highest cost)
2. Set completion that grants a visible title or reward: **high**, at low cost
3. Multi-slot showcase: **medium-high**, at low cost
4. Hidden combinations and puzzles: **high for a core minority** (est. 5 to 15% of players), with **outsized community buzz**
5. Premium visual treatments: **medium**, and the safest place for monetization

## 4. What CoD players respond to

- **Prestige and proof of grind.** Mastery camos and hard-challenge cards are status symbols. Players want others to *see* the hard ones and know what they cost.
- **Flex in the killcam and lobby.** The calling card is shown to the player you just eliminated. That "you got carded" moment is the existing emotional hook.
- **Challenges as content.** Many players play *for* challenges (camo grinds are a long-running retention driver, est. a large share of long-session play).
- **Short sessions and downtime.** Matchmaking, lobby and pre-game waits are short dead time (est. 30 to 90 s per match) that players fill on their phones.
- **Low tolerance for pay-to-win.** Any hint that purchased items affect matches draws strong backlash.
- **Competitive integrity in ranked.** Ranked players want nothing visual or audio that could hide information or distract.

## 5. Opportunity

| Gap | Evidence | Size (est.) |
|---|---|---|
| **Earned cards have no use** | One equip slot. Hundreds of unlocked, unseen cards. | Affects nearly all active players; CoD MAU est. tens of millions across titles |
| **Hard-earned cards look like cheap ones** | Players already value mastery cards more, but nothing in the system expresses that | Core and hardcore segment, est. 20 to 35% of players |
| **Lobby downtime is unused** | Wait times every match | Est. 1 to 3 minutes per session |
| **No community puzzle layer for cards** | CoD has hidden challenges, but cards themselves never hide anything | Small core group, high buzz (streams, guides) |

**Positioning line:** *"Every card you earned is a piece you can play."*

## 6. Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| **Pay-to-win perception** (store cards stronger) | High if unmanaged | High | **Power comes only from earned difficulty.** Store and bundle cards get the lowest power tier and no trait. They get *visual* premium treatment only. State this rule publicly. |
| **Competitive integrity** in ranked | Medium | High | Card features never change shooter stats, information or visibility. Any in-match effect stays **out of ranked** or is purely cosmetic and opt-out. |
| **Gatekeeping** (veterans' collections crush newcomers) | Medium | Medium | A **Clearance cap** on lineups, matchmaking by collection size, loaner starter lineups, and puzzles that use fixed hands |
| **Balance of hundreds of existing cards** | High | Medium | Derive stats from card metadata with a formula (origin, difficulty, rarity). Hand-tune only top-tier cards. |
| **Clutter or distraction** in the main game | Medium | Medium | The side mode lives in menus, lobby and companion app. Nothing extra on the shooter HUD. |
| **"Minigame nobody asked for"** | Medium | Medium | Keep it optional, quick (3 min) and rewarding in cosmetics players already want (titles, frames) |
| **IP and legal** for this pitch | Low (pitch only) | High | Unofficial concept; original art and names only; standalone demo |
| **Mechanic similarity** to existing card minigames | Low | Low | Edge-capture games are a broad genre. Our brick-wall board, 3-value banner cards and origin traits are distinct. |

## 7. Go/No-Go

**GO** for the design pitch and a small web concept demo (est. 5 to 7 days of build).
The demo should prove one question: *"Does knowing that my hard-earned cards are stronger pieces make me want to earn more of them?"* That's measured by playtester intent-to-collect ratings and by how often players open the album to chase specific cards (see the prototype scope).

**Not recommended:** any feature that gives calling cards a stat effect in the shooter, and any trading or real-money market for cards.
