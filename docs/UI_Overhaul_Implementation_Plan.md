# Danegild — UI Overhaul Implementation Plan
### Complete rebuild from Founding Sequence through Lineage Screen
---

## Overview

This plan covers every UI screen designed across the overhaul sessions, ordered
for safe incremental delivery. Each phase is self-contained and leaves the game
in a playable state. No phase requires a subsequent phase to run.

**Total scope:** 9 phases · ~35 implementation tasks · 6 screens deleted · 8 new screens built

**Reference outputs produced this session:**
- `founding_sequence_mockup.html` + `FoundingSequence_Spec.gd`
- `autumn_screen_mockup.html` + `AutumnScreen_Spec.gd`
- `winter_screen_mockup.html` + `WinterScreen_Spec.gd`
- `dynasty_sidebar_mockup.html`

---

## Shared Theme Contract

Every new screen uses the following CSS/GDScript variable equivalents.
No screen may introduce its own colour values outside this set.

| Token | Hex | Usage |
|---|---|---|
| `BG_DARK` | `#1a1610` | All full-screen backgrounds |
| `BG_PANEL` | `#211e17` | Panel containers |
| `BG_CARD` | `#16140f` | Card and row backgrounds |
| `BORDER` | `#3d3828` | Default borders |
| `BORDER_GOLD` | `#7a6430` | Hover / active borders |
| `RENOWN` | `#d4a843` | Renown, primary gold accent |
| `GOLD_DIM` | `#7a6430` | Dimmed gold, costs |
| `TEXT_PRIMARY` | `#e8dfc0` | Body text |
| `TEXT_SECONDARY` | `#9a9080` | Labels, captions |
| `TEXT_DIM` | `#5a5548` | Section headers, disabled states |
| `MIGHT` | `#c47a50` | Might pillar, combat |
| `PROSPERITY` | `#7ab648` | Prosperity pillar, food |
| `AUTHORITY` | `#88aadf` | Authority pillar, winter |
| `DANGER` | `#c84040` | Crises, deficits, broken oaths |
| `WARNING` | `#e8a840` | Partial states, cautions |

**Typography:** Cinzel (headers, labels, Cinzel Decorative for epithets) +
Crimson Text italic (narrative prose). Both loaded from Google Fonts or
bundled in `res://ui/fonts/`.

**GDScript theme resource:** `res://ui/themes/DarkSagaTheme.tres`
All new scenes reference this theme. The existing `VikingDynastyTheme.tres`
(parchment) is retained only for scenes not yet overhauled.

---

## Phase 1 — Foundation: Theme Resource + Shared Components
**Effort: ~1 day | Dependency: none**

The groundwork everything else builds on. Do this first.

### Tasks

**1.1 — Create `DarkSagaTheme.tres`**
New Godot Theme resource at `res://ui/themes/DarkSagaTheme.tres`.
Define all token colours and font assignments from the contract above.
Define the following named style variations:
- `PanelContainerDark` — `BG_PANEL` background, `BORDER` 1px border
- `PanelContainerCard` — `BG_CARD` background, `BORDER` 1px border
- `AdvanceButton` — transparent background, `GOLD_DIM` border, `RENOWN` text
- `SectionHeader` — Cinzel 9px, `TEXT_DIM`, letter-spacing 0.3em
- `HouseholdNameLabel` — Cinzel 13px, `TEXT_PRIMARY`
- `SeasonLabel` — Cinzel 11px, `TEXT_SECONDARY`
- `DangerLabel` — Cinzel 13px, `DANGER`
- `SeasonDayLabel` — Cinzel 11px, `AUTHORITY`

**1.2 — Bundle fonts**
Copy Cinzel and Crimson Text .ttf files to `res://ui/fonts/`.
Register both in `DarkSagaTheme.tres` as default font overrides.

**1.3 — Create `AccentLine.tscn`**
Reusable horizontal rule component: `ColorRect`, height 1px,
colour `BORDER_GOLD`, opacity 0.4. Used in every screen header.

**1.4 — Create `ProgressDots.tscn`**
Reusable 4-dot row for founding sequence. Three states per dot:
`pending` (`BORDER`), `active` (`RENOWN`), `done` (`GOLD_DIM`).

**1.5 — Create `LedgerRow.tscn`**
Three-column grid row for Autumn ledger: label · value · net.
Net column colour-coded via `set_net(value: int)`:
positive → `PROSPERITY`, negative → `DANGER`, zero → `TEXT_SECONDARY`.

**1.6 — GUT tests**
- Theme resource loads without errors
- `LedgerRow.set_net()` assigns correct colour for +, −, and 0

---

## Phase 2 — Founding Sequence
**Effort: ~3 days | Dependency: Phase 1**
**Mockup:** `founding_sequence_mockup.html`
**Spec:** `FoundingSequence_Spec.gd`

The entry point to the entire game. Replaces the placeholder new-game flow.
Player recounts their father's story across three committed choices,
then receives a generated founding epithet before Year 880 begins.

### New files

```
res://data/founding/FoundingData.gd
res://autoload/FoundingGenerator.gd
res://ui/founding/FoundingScreen.tscn + .gd       ← controller
res://ui/founding/FoundingChoice1.tscn + .gd      ← Father's Nature
res://ui/founding/FoundingChoice2.tscn + .gd      ← Exile Reason
res://ui/founding/FoundingChoice3.tscn + .gd      ← First Act
res://ui/founding/FoundingEpithet.tscn + .gd      ← Reveal + name entry
```

### Tasks

**2.1 — `FoundingData.gd` resource class**
```
@export var father_archetype: String   # "warrior" | "builder" | "diplomat"
@export var strength_clause: String
@export var strength_stat: String
@export var flaw_clause: String
@export var flaw_stat: String
@export var exile_reason: String       # "frankish" | "rival" | "opportunity"
@export var first_act: String          # "sworn" | "challenged" | "generous"
@export var jarl_name: String
@export var father_name: String
@export var founding_epithet: String
```

**2.2 — `FoundingGenerator.gd` autoload**

`generate_from_founding(data: FoundingData) -> JarlData`:
- Rolls stats: boosted stat 10–15, penalised stat 5–8, all others 5–15
- Applies exile mechanical effects (see table below)
- Applies first act household state mutations
- Stores `founding_archetype`, `exile_reason`, `first_act`, `founding_epithet`
  on `JarlData` for Spring card weighting

`assemble_epithet(data: FoundingData) -> String`:
- Picks father name from archetype pool (20 names per archetype)
- Appends epithet seed from selected strength clause
- Returns: `"Bjorn, the Iron-Handed"`

Exile mechanical effects applied by generator:

| Exile | Effect |
|---|---|
| Frankish | Starting food −30%, gold −20%, household_1.labor_efficiency = 0.7 first Summer, Jarl trait: `Trait_Dispossessed` |
| Rival Jarl | Starting warband: 1 WarbandData (5 Bondi), household count = 2, Authority −2, rival_jarl_exists = true flag |
| Opportunity | All households loyalty +5, harsh_winter_chance × 1.5 multiplier on EventBalanceData |

First act household state mutations:

| First Act | Effect |
|---|---|
| Sworn | household_1.loyalty = 80, expectation_flag = true (loyalty −25 if food < demand at Autumn) |
| Challenged | household_3.loyalty = 25, departure event triggers if loyalty < 20 by Winter |
| Generous | All households loyalty +10, starting food −40% |

**2.3 — `FoundingScreen.tscn` controller**
CanvasLayer (layer = 0). Sequences the four child panels.
No back navigation — each commit is final.
Assembles `FoundingData` incrementally as panels complete.
On `FoundingEpithet` confirm: emits `founding_complete(data)`.

**2.4 — `FoundingChoice1.tscn` — Father's Nature**
Three-beat interaction:
- Beat A: Three archetype cards. Select one → sentence frame appears
  with two empty slots: `"He [___], but [___]."`
- Beat B: Strength slot active (pulsing border). Clause pool for chosen
  archetype appears (4–5 options). Select → slot fills with Cinzel text.
- Beat C: Flaw slot becomes active. Shared flaw pool appears (7 options).
  Select → sentence completes. Commit button appears.
- Player may re-select strength or flaw before committing.
- Commit locks screen and advances to Choice 2.

Clause data arrays live in `FoundingChoice1.gd` as constants.
See `FoundingSequence_Spec.gd` for full clause pools (15 strength + 7 flaw).

**2.5 — `FoundingChoice2.tscn` — Exile Reason**
Three `SituationCard` instances, each showing:
- Title (Cinzel 14px bold)
- 2–3 sentence description (Crimson Text italic)
- Consequence line (Cinzel 10px, TEXT_DIM, all-caps)

No assembly mechanic. Select one, Commit button appears, advance.

**2.6 — `FoundingChoice3.tscn` — First Act**
Identical structure to Choice 2. Three opening-problem cards.

**2.7 — `FoundingEpithet.tscn` — Reveal**
Centred vertical layout, max width 700px:
- Preamble: "Year 880. This is what they said of your father." (dim italic)
- Father epithet name (Cinzel 32px, RENOWN gold)
- Full sentence (Crimson Text 20px italic)
- Divider
- Exile one-liner + First Act one-liner (Crimson Text 15px)
- Pillar inheritance line (e.g. "You carry his iron and his pride.")
- Optional name entry (LineEdit, placeholder = generated Jarl name)
- "Begin — Year 880" AdvanceButton

**2.8 — Wire to `MainMenu.gd`**
"Begin the Saga" button → loads `FoundingScreen`.
`FoundingScreen.founding_complete` →
`FoundingGenerator.generate_from_founding(data)` →
`DynastyManager.start_new_campaign_with_jarl(jarl)` →
`SceneManager.load_main_game()`

**2.9 — Add `start_new_campaign_with_jarl()` to `DynastyManager`**
Accepts `JarlData`, initialises settlement with exile-adjusted starting
resources, applies first act household mutations, sets year to 880,
transitions to Spring.

**2.10 — GUT tests**
- `_roll_stat()` returns 10–15 for boosted stat, 5–8 for penalised
- `assemble_epithet()` returns non-empty string for all 9 archetype × 3
  clause combinations tested
- Frankish exile correctly sets food −30%, household efficiency 0.7
- Rival exile correctly spawns warband, sets household count to 2
- Generous first act correctly sets all loyalties +10 and food −40%

---

## Phase 3 — Spring Screen
**Effort: ~2 days | Dependency: Phase 2**

Replaces the Spring path of `SeasonalCouncilUI`. Player selects one oath
card from a hand of three, commits, and cannot advance until confirmed.

### New files

```
res://ui/seasonal/SpringScreen.tscn + .gd
res://ui/seasonal/SpringOathCard.tscn + .gd
```

### Tasks

**3.1 — `SpringScreen.tscn`**
Full-screen CanvasLayer (layer = 10). Two-column layout:
- Left (65%): Card hand — three `SpringOathCard` instances, fan arrangement
- Right (35%): Context panel — Winter forecast line, current Jarl stats,
  household loyalty summary

Winter forecast line updates live as card selection changes:
`"At current stores, you will enter Winter [secure / short by ~X food]."`

No "End Spring" button. The selected oath card's confirm button is the
only advance path.

**3.2 — `SpringOathCard.tscn`**
Five-section card layout:
1. Oath (Crimson Text italic, first person, no numbers)
2. Condition (Cinzel 11px, narrative phrasing)
3. Reward (two lines: mechanical + narrative)
4. Consequence (red-tinted, "If broken:")
5. Confirm button (AdvanceButton, only on selected card)

Card states: `idle` · `hovered` (scale 1.05, border GOLD) ·
`selected` (border RENOWN, confirm visible) · `locked` (dimmed, no interact)

`SpringOathCard.setup(card: SeasonalCardResource, jarl: JarlData)`:
- Sets all five text fields
- Determines affordability via Jarl stat vs card threshold
- Adjusts oath phrasing based on stat level (low/mid/high thresholds)

**3.3 — Card selection from founding context**
`SpringScreen.gd` reads `current_jarl.founding_archetype` and
`current_jarl.exile_reason` to weight card pool selection.
Year 1 only: founding echo card is always included if exile_reason matches.
Implementation: simple conditional pool — no dynamic scoring needed yet.

**3.4 — Oath commit flow**
On confirm: stores selected `SeasonalCardResource` on
`DynastyManager.active_spring_oath`. Emits `spring_oath_committed`.
Closes SpringScreen. `DynastyManager` transitions to Summer.

**3.5 — Wire to `MainGameUI._update_center_view()`**
Replace `council_panel_scene` for Spring with `spring_screen_scene`.
The existing `SeasonalCouncilUI` Spring path is now unused.

**3.6 — GUT tests**
- Card pool includes founding echo card in Year 1 matching exile reason
- Confirm button disabled when Jarl stat below threshold
- `active_spring_oath` correctly set after commit

---

## Phase 4 — Autumn Screen
**Effort: ~2 days | Dependency: Phase 3**
**Mockup:** `autumn_screen_mockup.html`
**Spec:** `AutumnScreen_Spec.gd`

Replaces `AutumnLedger_UI`. Three-beat sequence: animated ledger →
oath resolution + skald report → Enter Winter gate.

### New files

```
res://ui/seasonal/AutumnScreen.tscn + .gd
res://scripts/ui/SkaldReportGenerator.gd
res://data/skald/SkaldTemplates.gd
```

### Tasks

**4.1 — Extend Autumn context dict in `DynastyManager._transition_to_season("Autumn")`**

Add to existing payout_report:
```
"oath_result":   { oath_name, outcome, renown_delta, notes }
"year_events":   Array[String]  ← dominant summer activity keys
"jarl_name":     String
"current_year":  int
"winter_severity": String  ← from WinterManager.roll_upcoming_severity()
```

**4.2 — `_resolve_spring_oath()` in `DynastyManager`**
Called during `_transition_to_season("Autumn")`.
Evaluates `active_spring_oath` against current game state.
Returns `oath_result` dict with outcome: `"kept" | "partial" | "broken" | "none"`.
Applies renown delta and household loyalty changes.
If broken/none: sets `renown_decay_active = true`.
If kept: `consecutive_safe_oaths += 1`.

**4.3 — `AutumnScreen.tscn`**
Full-screen CanvasLayer (layer = 10). Two-column layout:

Left panel (55%) — The Ledger:
- 5 animated rows (Food · Wood · Gold · Renown · Verdict)
- Each row: resource name · income · expense · net (colour-coded)
- Rows reveal in sequence, 400ms delay each
- Click anywhere on panel to skip animation instantly
- After completion/skip: skald panel fades in automatically

Right panel (45%) — Oath Resolution:
- Oath name (dim gold)
- Outcome badge: KEPT (green) / PARTIAL (amber) / BROKEN (red) / NONE (grey)
- Notes string (e.g. "140 / 200 Food — threshold not reached")
- Renown delta (colour-coded ±)
- One row per household showing loyalty change

Bottom panel (full width, initially hidden) — Skald Report:
- Three-paragraph saga prose from `SkaldReportGenerator`
- Fades in after ledger completes or is skipped

Footer:
- "Enter Winter" button, disabled until skald panel visible

**4.4 — `SkaldReportGenerator.gd`**

`generate_report(context: Dictionary) -> String`:
Assembles three paragraphs from template pools.

Template lookup keys:
- Para 1 (The Year): keyed on dominant summer activity
  → `"raid_success"`, `"raid_failure"`, `"harvest_focus"`, `"build_focus"`, `"scout"`
- Para 2 (The Oath): keyed on `oath_result.outcome`
  → `"oath_kept"`, `"oath_partial"`, `"oath_broken"`, `"oath_none"`
- Para 3 (The Horizon): keyed on `"{severity}_{food_state}"`
  → `"harsh_deficit"`, `"harsh_surplus"`, `"normal_deficit"`, etc.

Variable slots in templates: `{jarl_name}`, `{oath_name}`,
`{household_name}`, `{warband_name}`, `{current_year}`.
`fill_template(template: String, context: Dictionary) -> String`
does simple string replacement.

**4.5 — `SkaldTemplates.gd`**
Static const dictionary. Minimum 3 strings per key = 33 template strings.
Author these separately — placeholder strings sufficient for initial build.

**4.6 — Wire to `MainGameUI._update_center_view()`**
Replace `autumn_panel_scene` with `autumn_screen_scene`.

**4.7 — Delete retired scenes**
- `res://ui/seasonal/AutumnLedger_UI.tscn`
- `res://ui/seasonal/AutumnLedger_UI.gd`

**4.8 — GUT tests**
- `_resolve_spring_oath()` returns correct outcome for kept/partial/broken/none
- `SkaldReportGenerator` returns non-empty string for all 11 template keys
- Ledger row colour correct for positive, negative, zero net values

---

## Phase 5 — Winter Screen
**Effort: ~3 days | Dependency: Phase 4**
**Mockup:** `winter_screen_mockup.html`
**Spec:** `WinterScreen_Spec.gd`

Replaces the Winter path of `SeasonalCouncilUI`. Two-beat sequence:
blocking severity resolution (including crisis path) → Hall Actions menu.

### New files

```
res://ui/seasonal/WinterSeverityBeat.tscn + .gd
res://ui/seasonal/WinterScreen.tscn + .gd
res://ui/seasonal/HeirTrainingScreen.tscn + .gd
res://data/traits/Trait_ChildhoodHardship.tres
```

### Tasks

**5.1 — Extend Winter context dict in `DynastyManager._transition_to_season("Winter")`**

Add:
```
"forecast":        { food_demand: int, wood_demand: int }
"is_crisis":       bool
"food_deficit":    int
"wood_deficit":    int
"hall_actions":    int
"max_hall_actions":int
"heirs":           Array[JarlHeirData]
"households":      Array[Dictionary]
```

**5.2 — `WinterSeverityBeat.tscn`**
Full-screen CanvasLayer (layer = 10). Blocks map. Shows the bill first,
player confirms, then resources are deducted.

Secure path (no deficit):
- Bill table: stores before · demand · after (colour-coded net)
- Verdict: "The stores will hold."
- Single "Accept Winter's toll" AdvanceButton
- On confirm: `EconomyManager.apply_winter_consumption(costs)`

Crisis path (any deficit):
- Same bill table with red net values
- Verdict: "You cannot cover the demand."
- Three crisis option buttons (never locked out entirely):

  | Option | Cost | Effect |
  |---|---|---|
  | Emergency Purchase | `food_deficit × 2` Gold (disabled if insufficient) | Deficit covered, no loyalty impact |
  | Ration Hard | All household loyalty −15 | Deficit absorbed, households remember |
  | Jarl's Family Shares | Heir gains `Trait_ChildhoodHardship`; if no heir: Jarl Prowess −1 | Deficit absorbed, loyalty unaffected, legacy cost |

On any resolution: emits `severity_resolved(choice: String)`.
Hides. `WinterScreen` shows.

**5.3 — `Trait_ChildhoodHardship.tres`**
JarlTraitData resource:
- `display_name`: "Childhood Hardship"
- `description`: "Endured a winter of shortage in their formative years."
- `prowess_mod`: +1 (hardship strengthens)
- `legitimacy_mod`: −5 (damages dynasty reputation)

**5.4 — `_on_severity_resolved()` in `DynastyManager`**
Applies crisis resolution effects based on choice string.
See WinterScreen_Spec.gd for full implementation pseudocode.

**5.5 — `WinterScreen.tscn`**
Full-screen CanvasLayer (layer = 10). Two-column layout:

Left (60%) — Hall Actions list:
- Hall Actions counter with pip indicators at top
- Four category sections: HEIR · LEGACY · HOUSEHOLDS · VARIABLE
- Each action row: name · cost summary · action cost badge
- Rows dim when: 0 actions remaining OR insufficient resources
- Variable section: 2 cards drawn from winter_court_cards pool
  (ports existing `Card_Winter_Feast` and `Card_Winter_Recruit` data)

Right (40%) — Context panel:
- Severity resolved badge
- Post-winter resource snapshot
- Jarl age + succession warning if applicable
- Household list with loyalty and generation depth

Footer:
- "End Year →" AdvanceButton — always available, no gate

Fixed Hall Actions (always present):
```
HEIR:       Train the Heir         (1 action) → opens HeirTrainingScreen
LEGACY:     Great Feast            (1 action, 100 Food)
            Legacy Project         (1 action) [stub — picker not yet built]
HOUSEHOLDS: Recruit Household      (1 action, 50 Gold)
            Demand Oaths           (1 action, requires Authority 13+)
            Negotiate Marriage     (1 action)
```

**5.6 — `HeirTrainingScreen.tscn`**
CanvasLayer (layer = 11, above WinterScreen). Opens when Train the Heir
is selected. 1 Hall Action spent immediately on open — no cancel.

Three-column layout:
- Heir panel: name, age, current six stats, stat selector dropdown
- Tutor panel: Hall tutors + external tutors, filtered by selected stat
- Outcome panel: base → after values, live biography line

Tutor types:
- Jarl (self): always available, trains top stat at (Jarl_stat − 1) boost
- Household heads: available for stats matching their oath type,
  boost quality = `base_boost × (1 + (generation − 1) × 0.25)`
- External tutors (stubbed, locked with tooltip for now):
  Brother Aldric (Learning, locked if raided monastery),
  Sigurd One-Eye (Command/Prowess, locked if Renown < 300)

On confirm: applies stat boost, appends biography line to
`heir.training_history`, emits `heir_trained` signal.

**5.7 — Wire to `MainGameUI._update_center_view()`**
Replace Winter path of `council_panel_scene` with `winter_screen_scene`.
Sequence: `WinterSeverityBeat` shown first, then `WinterScreen`.

**5.8 — Delete retired scenes**
- `res://ui/seasonal/SeasonalCouncilUI.tscn` (entire file — both paths now replaced)
- `res://ui/seasonal/SeasonalCouncilUI.gd`
- `res://ui/seasonal/WinterCourt_UI(Pilar Refactor).tscn` (old refactor branch)

**5.9 — GUT tests**
- Each crisis resolution option applies correct mechanical effects
- Emergency purchase disabled when gold insufficient
- Heir training stat boost: gen 1 = +1, gen 4 = +2 (rounds correctly)
- Hall actions decrement on use; End Year available at all times
- `Trait_ChildhoodHardship` applied to heir when family crisis chosen

---

## Phase 6 — Dynasty Sidebar Overhaul
**Effort: ~2 days | Dependency: Phase 1**
**Mockup:** `dynasty_sidebar_mockup.html`

Replaces `DynastyUI.tscn` + `DynastyUI.gd` in-place. Same sidebar slot,
same tween animation, same trigger from TopBar. Internal redesign only.

### Tasks

**6.1 — Rebuild `Dynasty_UI.tscn`**
Width: 440px (update `SidebarPanel` `custom_minimum_size`).
Two-tab structure using `TabContainer` or manual tab row + panel swap:

**Tab 1 — The Jarl:**
- Portrait hero block: 88×88 portrait, name, epithet, age/reign meta,
  renown bar with tier badge
- Three pillar rows (expandable): score + one-line summary at rest,
  full stat breakdown + shadow penalty on click
- Authority section: pip indicators (filled = remaining)
- Heirs section: `HeirCard` instances (width 116px each),
  right-click context menu for Designate / Expedition / Marriage / Captain

**Tab 2 — Lineage:**
- Ancestor scroll: horizontal row, each ancestor shows portrait,
  name, epithet (or "— no epithet —"), final renown
- Founding block: father epithet name, full sentence, three founding tags
- Founding Echo card: exile consequence card with dim gold border,
  mechanical effect line

**6.2 — Rewrite `DynastyUI.gd`**
Replace `_on_jarl_stats_updated()` BBCode wall with structured node updates:
- `_update_jarl_hero(jarl)` — portrait, name, epithet, renown bar
- `_update_pillars(jarl)` — three expandable pillar rows
- `_update_authority(jarl)` — pip row
- `_update_heirs(jarl)` — heir cards via updated `HeirCard.setup()`
- `_update_lineage(jarl)` — ancestor scroll + founding block

**6.3 — Update `HeirCard.tscn` + `HeirCard.gd`**
New layout: 116×auto card, portrait 60×60, name, age, status badge,
training history line (most recent only).
`setup(heir: JarlHeirData)` fills all fields.
`card_clicked` signal unchanged (PopupMenu still triggered in DynastyUI).

**6.4 — Add epithet + founding fields to `JarlData.gd`**
```gdscript
@export var founding_epithet: String = ""      # "Bjorn, the Iron-Handed"
@export var founding_archetype: String = ""    # from founding sequence
@export var exile_reason: String = ""
@export var first_act: String = ""
@export var living_epithet: String = ""        # awarded during play
```
These are set by `FoundingGenerator` in Phase 2. Dynasty sidebar reads them.

**6.5 — GUT tests**
- `_update_pillars()` correctly calculates shadow penalty for all three pillars
- Pillar expand/collapse toggles detail panel visibility
- Heir card context menu disables expedition/marriage when status = OnExpedition

---

## Phase 7 — Succession Crisis UI Retheme
**Effort: ~1 day | Dependency: Phase 1**

The existing `Succession_Crisis_UI.gd` logic is correct — it applies
renown and gold tax choices, unpauses the game, and queue_frees itself.
This phase is presentation only: dark theme, narrative framing.

### Tasks

**7.1 — Rebuild `Succession_Crisis_UI.tscn`**
Keep `Succession_Crisis_UI.gd` unchanged. Replace scene node structure:

Full-screen dim overlay (ColorRect, #000000 at 70% alpha).
Centred panel (480px wide, `PanelContainerDark`):
- Header: "The Jarl is Dead" / current year (Cinzel 18px)
- Separator
- Description block (Crimson Text italic, ~4 lines, narrative prose)
- Legitimacy display: "New Legitimacy: X / 100" with colour bar
- Renown tax section: title + description + Pay / Refuse button pair
- Gold tax section: same structure
- Separator
- Confirm button (AdvanceButton, disabled until both choices made)

All existing `@onready` node paths updated to match new structure.
Logic in `.gd` is untouched.

**7.2 — Author narrative description strings**
`Succession_Crisis_UI.gd` currently sets `desc_label.text` to
"The Jarl is dead. Your rule is fragile..." — replace with authored
prose that names the deceased Jarl and references their epithet if set.
`desc_label.text = "%s is dead. The hall is quiet." % [old_jarl_name]`

**7.3 — GUT test**
- UI still correctly applies renown_choice and gold_choice on confirm
- Game unpauses after confirm

---

## Phase 8 — Event Modal Retheme
**Effort: ~1 day | Dependency: Phase 1**

`EventManager.gd` and the event trigger/choice system are unchanged.
`EventUI.tscn` and `EventUI.gd` (not seen in source but confirmed to exist
via `event_ui_scene` export in `EventManager`) get a presentation overhaul.

### Tasks

**8.1 — Rebuild `EventUI.tscn`**
Full-screen dim overlay. Centred panel (560px wide, `PanelContainerDark`).
- Event title (Cinzel 18px)
- Flavour text (Crimson Text italic, multi-line)
- Separator
- Choice buttons: vertical stack, each a full-width `PanelContainerCard`
  with choice text + consequence summary below in `TEXT_SECONDARY`
- Buttons highlight on hover (`BORDER_GOLD`), confirm on click

**8.2 — Update `EventUI.gd` `display_event()` method**
Node paths updated to match new structure.
`choice_made` signal unchanged — `EventManager` connections unaffected.

---

## Phase 9 — `MainGameUI` Wiring Cleanup
**Effort: ~0.5 days | Dependency: Phases 3–6**

Final pass to clean up `MainGameUI.gd` and `.tscn` after all scene
replacements are confirmed working.

### Tasks

**9.1 — Update `MainGameUI.tscn` export references**
Replace:
- `council_panel_scene` → split into `spring_screen_scene` + `winter_severity_scene` + `winter_screen_scene`
- `autumn_panel_scene` → `autumn_screen_scene`
- `dynasty_ui_scene` → updated `Dynasty_UI.tscn` (same path, rebuilt content)

**9.2 — Update `_update_center_view()` in `MainGameUI.gd`**
```gdscript
match season_enum:
    DynastyManager.Season.SPRING:
        scene_to_load = spring_screen_scene
        season_string_name = "Spring"
    DynastyManager.Season.SUMMER:
        return  # unchanged — RTS view
    DynastyManager.Season.AUTUMN:
        scene_to_load = autumn_screen_scene
        season_string_name = "Autumn"
    DynastyManager.Season.WINTER:
        # WinterSeverityBeat loads first, then WinterScreen on severity_resolved
        scene_to_load = winter_severity_scene
        season_string_name = "Winter"
```

**9.3 — Remove `SeasonAdvanceBtn` from Spring path**
`season_advance_btn.visible` already set to false in Spring.
Confirm no path re-enables it during Spring after new screen is wired.

**9.4 — Remove `idle_worker_warning` Summer-only guard**
Confirm it still only fires during Summer after routing cleanup.

**9.5 — Delete `MainUIDebugger.gd` Winter Council references**
`council_ui` export was wired to old `SeasonalCouncilUI`.
Replace with null or remove if debugger is no longer needed.

---

## Deletion Manifest

All files listed here are safe to delete after the phase that replaces them
is confirmed working. Do not delete before that phase passes its GUT tests.

| File | Replaced in Phase | Replacement |
|---|---|---|
| `res://ui/seasonal/SeasonalCouncilUI.tscn` | 5 | SpringScreen + WinterScreen |
| `res://ui/seasonal/SeasonalCouncilUI.gd` | 5 | SpringScreen.gd + WinterScreen.gd |
| `res://ui/seasonal/WinterCourt_UI(Pilar Refactor).tscn` | 5 | WinterScreen |
| `res://ui/seasonal/AutumnLedger_UI.tscn` | 4 | AutumnScreen |
| `res://ui/seasonal/AutumnLedger_UI.gd` | 4 | AutumnScreen.gd |
| `res://ui/Dynasty_UI.tscn` (old layout) | 6 | Rebuilt in-place |

---

## Delivery Sequence Summary

```
Phase 1 — Theme + shared components      [~1 day,  no dependencies]
Phase 2 — Founding Sequence              [~3 days, needs Phase 1]
Phase 6 — Dynasty Sidebar                [~2 days, needs Phase 1]
  ↓ (Phase 1 complete, Phases 2+6 can run in parallel)
Phase 3 — Spring Screen                  [~2 days, needs Phase 2]
Phase 4 — Autumn Screen                  [~2 days, needs Phase 3]
Phase 5 — Winter Screen                  [~3 days, needs Phase 4]
  ↓ (complete seasonal loop)
Phase 7 — Succession Crisis retheme      [~1 day,  needs Phase 1]
Phase 8 — Event Modal retheme            [~1 day,  needs Phase 1]
Phase 9 — MainGameUI wiring cleanup      [~0.5 day, needs 3–6]
```

**Critical path:** 1 → 2 → 3 → 4 → 5 → 9 (~11.5 days for playable vertical slice)

Phases 6, 7, and 8 can be interleaved with Phases 3–5 without risk.

---

## Content Work Required (Not Implementation Tasks)

These are writing tasks, not code tasks. They can be done in parallel with
any phase and should be ready before that phase ships.

| Content | Needed For | Volume |
|---|---|---|
| Father archetype strength clause pools (final) | Phase 2 | 15 clauses (5 per archetype) |
| Shared flaw clause pools (final) | Phase 2 | 7 clauses |
| Exile situation card copy | Phase 2 | 3 × 3 text blocks |
| First Act card copy | Phase 2 | 3 × 3 text blocks |
| Father name pools | Phase 2 | 20 names × 3 archetypes |
| Spring oath card content | Phase 3 | 18 card types × 3–4 phrasings ≈ 60–70 sentences |
| Skald template strings | Phase 4 | 11 keys × 3 variants = 33 strings minimum |
| Succession crisis description prose | Phase 7 | 1 dynamic string |

---

*Plan compiled from session outputs: AutumnScreen_Spec.gd, WinterScreen_Spec.gd,*
*FoundingSequence_Spec.gd, and dynasty_sidebar_mockup.html.*
*Cross-referenced against live codebase: MainGameUI.gd, DynastyUI.gd,*
*SeasonalCouncilUI.gd, WinterManager.gd, DynastyGenerator.gd.*
