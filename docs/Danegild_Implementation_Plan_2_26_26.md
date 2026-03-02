# Danegild — Implementation Plan for Claude Code / Gemini
## Phase 1: The Vertical Slice
*This document contains specific implementation tasks. Each task includes the relevant files, expected inputs/outputs, and acceptance criteria. Implement tasks in order within each group. Do not skip ahead.*

---

## TASK GROUP 1: Founding Sequence
**Priority:** Critical — blocks all other Phase 1 work
**Goal:** Replace current placeholder start with a four-screen founding sequence that produces a fully initialised Jarl and settlement

---

### Task 1.1 — Create FoundingData Resource
**File to create:** `res://data/founding/FoundingData.gd`

Create a new Resource class that stores all founding sequence selections before they are applied to the game state.

```gdscript
class_name FoundingData
extends Resource

# Choice 1: Father's Nature
var father_archetype: String # "warrior", "builder", "diplomat"
var father_strength_clause: String # display text
var father_flaw_clause: String # display text
var boosted_stat: String # "command", "prowess", "stewardship", "learning", "diplomacy", "charisma"
var penalised_stat: String # same enum

# Choice 2: Exile Reason
var exile_reason: String # "frankish_persecution", "rival_jarl", "seeking_opportunity"

# Choice 3: First Act
var first_act: String # "oath_of_protection", "challenged_advisor", "generous_gift"

# Choice 4: Founding Location
var founding_location: String # "forest", "sea", "arable", "crags"

# Generated output
var founding_epithet: String # assembled after all four choices
```

---

### Task 1.2 — Create FoundingSequenceManager Autoload
**File to create:** `res://autoload/FoundingSequenceManager.gd`

Manages the founding sequence flow and applies selections to game state on completion.

**Responsibilities:**
- Hold current `FoundingData` instance during sequence
- Signal when sequence is complete
- On completion: call `_apply_founding_to_jarl()` and `_apply_founding_to_settlement()`

**`_apply_founding_to_jarl(founding_data: FoundingData)`**
Apply stat distribution weighting to the current Jarl in DynastyManager:
- Boosted stat: set to random value between 10–15
- Penalised stat: set to random value between 5–8
- All other stats: set to random value between 5–15
- Apply exile reason modifiers (see Task 1.4)
- Store founding_epithet on JarlData

**`_apply_founding_to_settlement(founding_data: FoundingData)`**
Apply founding location bonus to SettlementManager and EconomyManager:
- Forest: register +10% lumber multiplier, +1% construction speed multiplier
- Sea: register -10% warband travel time, enable fisheries passive food income
- Arable: register +25% farming output multiplier
- Crags: register Renown generation event (15 Renown every 2 years, exported var)
- Store location on settlement for situational negative event checks

**Exports for tuning (store on EventBalanceData):**
```gdscript
@export var opportunity_seeker_winter_multiplier: float = 1.5
@export var crags_renown_per_trigger: int = 15
@export var crags_renown_trigger_years: int = 2
```

---

### Task 1.3 — Build Father's Nature Screen
**File to create:** `res://scenes/founding/FatherNatureScreen.tscn` + `res://scenes/founding/FatherNatureScreen.gd`

**Display:** Three cards. Each card shows:
- Archetype label (The Warrior / The Builder / The Diplomat)
- Assembled sentence: *"He [strength_clause], but [flaw_clause]."*
- No stat numbers visible

**Data:** Author initial clause pools as exported arrays on FoundingSequenceManager or a dedicated FoundingClauseData resource:

Warrior strength clauses (minimum 3):
- "never lost a battle"
- "trained his men harder than any jarl alive"
- "was feared across three fjords"

Builder strength clauses (minimum 3):
- "could stretch a winter's grain to feed twice the mouths"
- "knew every timber and stone"
- "planned three winters ahead"

Diplomat strength clauses (minimum 3):
- "could end a blood feud with three words"
- "made alliances that lasted generations"
- "could silence a room with a single word"

Shared flaw clauses (minimum 6, usable by any archetype):
- "carried a grudge to his dying day"
- "never forgave a slight"
- "drank away half his winters"
- "spent gold like it grew on the fjord"
- "trusted no man's word over his own ledger"
- "his own men questioned his nerve"

**On load:** Randomly select one strength clause and one flaw clause per archetype. Store selections on FoundingData when player confirms.

**Stat mapping:** Each clause maps to a specific stat boost or penalty. Store this mapping in a dictionary. Example:
```gdscript
var strength_stat_map = {
    "never lost a battle": "command",
    "trained his men harder than any jarl alive": "command",
    "was feared across three fjords": "prowess",
    # etc.
}
```

---

### Task 1.4 — Build Exile Reason Screen
**File to create:** `res://scenes/founding/ExileReasonScreen.tscn` + `res://scenes/founding/ExileReasonScreen.gd`

**Display:** Three cards with narrative description. No mechanical tooltips on first read — player chooses based on story.

**Starting conditions applied on FoundingSequenceManager completion:**

**Frankish Persecution:**
- Starting food: -30% from default
- Starting wood: -20% from default
- One random household: set efficiency_modifier = 0.7 for first Summer only
- Add trait to JarlData: "the_dispossessed" — flag checked by raid reward calculator for Frankish target bonus

**Rival Jarl Drove You Out:**
- Starting warband: populated (only exile reason that starts with warband)
- Starting households: one fewer than default (2 instead of 3)
- Jarl Authority score: -2 applied after stat generation
- Add dormant_threat flag to DynastyManager: rival_jarl_threat = true

**Seeking Opportunity:**
- Starting resources: default values
- All households: loyalty += 10 on generation
- WinterManager harsh_chance multiplied by opportunity_seeker_winter_multiplier (exported, default 1.5)

---

### Task 1.5 — Build First Act Screen
**File to create:** `res://scenes/founding/FirstActScreen.tscn` + `res://scenes/founding/FirstActScreen.gd`

**Display:** Three cards. Narrative framing only — problems, not benefits.

**Obligation flags applied to SettlementManager on completion:**

**Oath of Protection ("I called the households together and swore to protect them"):**
- Select one random household
- Set household.obligation_flag = "sworn_protection"
- Set household.loyalty = 80 (elevated expectations)
- Register obligation check: if food < survival threshold OR raid casualty in this household before Winter, loyalty -= 40 and obligation_broken event fires

**Challenged the Advisor ("I challenged my father's oldest advisor to prove my authority"):**
- Select one random household (preferably non-founding if available)
- Set household.loyalty = 25 (watching, not hostile)
- Register recovery condition: loyalty increases by 5 each consecutive oath fulfilment. If loyalty < 30 at Winter, household departure event eligible.

**Generous Gift ("I gave away half the winter stores to the poorest household as a gesture of generosity"):**
- All households: loyalty += 8
- Starting food: multiply by 0.5
- Winter forecast line updates immediately to reflect deficit

---

### Task 1.6 — Build Founding Location Screen
**File to create:** `res://scenes/founding/FoundingLocationScreen.tscn` + `res://scenes/founding/FoundingLocationScreen.gd`

**Display:** Four cards with primary bonus listed. Situational negative NOT shown — discovered through play.

**On selection:** Store location on FoundingData. FoundingSequenceManager generates Great Hall in corresponding map region on settlement initialisation.

**Situational negative event registration** (store flags on SettlementManager for EventManager to check):
- Forest: register `wildfire_risk_enabled = true`
- Sea: register `coastal_storm_risk_enabled = true`
- Arable: register `raid_target_visibility_multiplier = 1.2` (checked by raid defense event probability)
- Crags: register `foreign_threat_visibility_enabled = true`

---

### Task 1.7 — Generate Founding Epithet
**File to modify:** `res://autoload/FoundingSequenceManager.gd`

After all four choices confirmed, assemble founding epithet from selections.

**Format:** `"[Jarl Name], Son of the [Father Epithet], [Exile Epithet]"`

**Father epithet map** (one per archetype/clause combination, examples):
```gdscript
var father_epithet_map = {
    "warrior_command": "Iron-Fisted",
    "warrior_prowess": "Far-Feared",
    "builder_stewardship": "Grain-Counter",
    "builder_learning": "Stone-Knower",
    "diplomat_charisma": "Silver-Tongued",
    "diplomat_diplomacy": "Peace-Maker",
}
```

**Exile epithet map:**
```gdscript
var exile_epithet_map = {
    "frankish_persecution": "the Exile-Born",
    "rival_jarl": "the Dispossessed",
    "seeking_opportunity": "the Willing",
}
```

Store assembled epithet on JarlData.founding_epithet. Display on sequence completion screen before transitioning to game.

---

## TASK GROUP 2: Spring Card Redesign
**Priority:** High — current Spring cards are the primary loop problem
**Goal:** Spring cards function as oaths with real consequences

---

### Task 2.1 — Create SpringCardData Resource
**File to create:** `res://data/spring/SpringCardData.gd`

```gdscript
class_name SpringCardData
extends Resource

@export var card_id: String
@export var stat_gate: String # which stat gates this card ("command", "stewardship", etc.)
@export var stat_threshold: int # minimum stat value to see this card
@export var oath_phrasings: Array[String] # 3-4 options, one selected randomly on display
@export var condition_template: String # "{jarl_name} must harvest {threshold} food before Winter"
@export var threshold_base: int # base threshold value
@export var threshold_stat_multiplier: float # how much the relevant stat scales the threshold
@export var reward_mechanical: String # internal key for reward handler
@export var reward_narrative_template: String # template for Skald's Report on success
@export var consequence_mechanical: String # internal key for consequence handler
@export var consequence_narrative_template: String # template for Skald's Report on failure
@export var is_founding_echo: bool = false # true for first-year-only cards
@export var founding_echo_exile: String # which exile reason unlocks this card
@export var is_intersection: bool = false # true for dual-stat cards
@export var secondary_stat_gate: String # second stat for intersection cards
@export var secondary_stat_threshold: int
```

---

### Task 2.2 — Build Spring Card Selector
**File to modify:** `res://autoload/DynastyManager.gd` or create `res://autoload/SpringCardSelector.gd`

**`select_spring_cards() -> Array[SpringCardData]`**

Logic:
1. Load all SpringCardData resources from `res://data/spring/cards/`
2. Filter by Jarl stat gates — card visible only if relevant stat meets threshold
3. For intersection cards — both stats must meet their respective thresholds
4. For founding echo cards — only eligible in year 1, filtered by exile reason
5. From eligible cards, select three. Prioritise: one founding echo (year 1 only) → intersection cards if available → single stat cards
6. For each selected card, calculate actual threshold: `threshold_base + (relevant_stat * threshold_stat_multiplier)`
7. Select one random oath phrasing per card
8. Return array of three configured cards

---

### Task 2.3 — Implement Oath Commitment Tracking
**File to modify:** `res://autoload/DynastyManager.gd`

On Spring card selection:
- Store selected card ID on DynastyManager as `active_spring_oath`
- Store calculated threshold as `spring_oath_threshold`
- Store relevant metric key (e.g. "food_harvested", "raid_gold_returned", "building_completed")

On Autumn transition:
- Check actual metric value against threshold
- If met: fire reward handler, generate success Skald entry
- If not met: fire consequence handler, generate failure Skald entry
- Clear active_spring_oath

---

### Task 2.4 — Author Initial Card Set (Six Single-Stat Cards)
**Files to create:** `res://data/spring/cards/` — one .tres file per card

Minimum viable card set for Phase 1:

**card_harvest_oath** (Stewardship gate, threshold ~15)
- Oath: "I swear my people will not go hungry this Winter."
- Condition: Harvest X food before Winter (scales with Stewardship)
- Reward: +15 loyalty all households, Skald entry generated
- Consequence: Household with obligation flag loses 40 loyalty, Renown frozen one year

**card_raid_oath** (Command gate, threshold ~10)
- Oath: "Before the leaves turn I will return with Frankish silver."
- Condition: Raid returns with X gold (scales with Command)
- Reward: +25 Renown, warband morale boost
- Consequence: Captain challenges authority, Authority score -1 next year

**card_build_oath** (Learning gate, threshold ~10)
- Oath: "By Autumn a new hall will stand where there was only mud."
- Condition: Complete one construction project before Autumn
- Reward: +10 loyalty, construction speed bonus next Summer
- Consequence: Unfinished building visible as failure marker, construction efficiency -10% next Summer

**card_diplomacy_oath** (Diplomacy gate, threshold ~12)
- Oath: "I will settle the disputes that fester in my hall before Winter."
- Condition: Resolve X loyalty conflicts before Winter
- Reward: Legitimacy +10, new household recruitment cost reduced
- Consequence: One household loyalty drops, envoy costs increase

**card_prowess_oath** (Prowess gate, threshold ~12)
- Oath: "I will lead the warband myself and prove my arm has not grown weak."
- Condition: Jarl must personally lead a raid this Summer
- Reward: +20 Renown, heir training boost if heir witnesses
- Consequence: Renown frozen, warband morale -10

**card_charisma_oath** (Charisma gate, threshold ~10)
- Oath: "My hall will be known for its welcome before the year is out."
- Condition: Hold a feast before Winter
- Reward: +15 loyalty all households, +10 Renown
- Consequence: Households note the empty tables, loyalty -8 all households

---

### Task 2.5 — Winter Forecast Line
**File to modify:** `res://scenes/spring/SpringPhaseUI.tscn` and controller

Add a persistent forecast line to Spring UI that updates in real time:

`"At current labour, you will enter Winter [short by X food / with X food surplus]."`

Calculated by EconomyManager based on:
- Current household oath assignments
- Days remaining in Summer
- Expected harvest yield at current labor
- Known Winter consumption (population × severity base estimate)

Updates every time player changes a household oath assignment.

---

## TASK GROUP 3: Summer Day Advance
**Priority:** High — current day advance feels empty
**Goal:** Every day press feels like time is passing and things are happening

---

### Task 3.1 — Expand Starting Households
**File to modify:** `res://autoload/SettlementManager.gd`

Change `_generate_default_households()`:
- Generate 3 households (not population/10)
- Each household: 3–4 villagers (randomised)
- Apply founding sequence modifiers (exile reason may reduce to 2)
- Founding households flagged: `is_founding_household = true` on HouseholdData

Add `is_founding_household: bool = false` to `res://data/settlements/HouseholdData.gd`

---

### Task 3.2 — Active Countdown Display
**File to modify:** Summer phase UI

Add always-visible countdown panel showing:
- `"Winter in X days"`
- `"[Building name] complete in X days"` (when construction active)
- `"Warband returns in X days"` (when raid active)

Countdowns update every day advance. When multiple countdowns converge — warband return within 2 days of Winter — add visual urgency indicator.

---

### Task 3.3 — Scout Oath Trailblazer Implementation
**File to modify:** `res://data/settlements/HouseholdData.gd` — add SCOUT to SeasonalOath enum
**File to modify:** `res://autoload/EconomyManager.gd` — register Scout labor contribution
**File to modify:** `res://autoload/SettlementManager.gd` — daily fog of war reveal logic

Scout oath behavior:
- Costs labor same as any other oath (member_count × labor_efficiency removed from available pool)
- Each day a household holds Scout oath: reveal fog of war tiles adjacent to current revealed area
- Reveal rate: base 3 tiles per day × labor_efficiency multiplier
- When fog of war < 50% unrevealed: update oath label display to "Target Scout" (label only, same mechanics for now)

---

### Task 3.4 — Raid Preparation Cost Screen
**File to create:** `res://scenes/summer/RaidPrepScreen.tscn`

Before raid commits, show player:
- Households assigned to raid (pulled from warband)
- Labor removed from settlement during raid (food forecast impact)
- Estimated departure days (distance + ship quality)
- Estimated return days (distance + encumbrance estimate)
- Winter arrives in X days (for convergence visibility)

Confirm button commits raid. Cancel returns to Summer view.

---

## TASK GROUP 4: Autumn Mirror
**Priority:** Medium — current Autumn is mechanical summary, needs narrative first
**Goal:** Player reads what kind of year they just lived before seeing any numbers

---

### Task 4.1 — Event Log Tag System
**File to modify:** `res://autoload/EventManager.gd`

Add logging call at end of each significant event handler:
```gdscript
func _log_skald_event(event_id: String, variables: Dictionary) -> void:
    DynastyManager.year_event_log.append({
        "event_id": event_id,
        "variables": variables,
        "significance": _get_event_significance(event_id)
    })
```

Significance values: 1 (minor), 2 (notable), 3 (saga-worthy)

Log at minimum these events: harvest result, raid outcome, household succession, jarl injury, quarantine, feast held, harsh winter survival, oath kept, oath broken.

---

### Task 4.2 — Build Skald Report Generator
**File to create:** `res://autoload/SkaldReportGenerator.gd`

**`generate_report(year_event_log: Array) -> String`**

Logic:
1. Sort log by significance descending
2. Take top 3–5 events
3. For each event, pull template from SkaldTemplateLibrary by event_id
4. Fill variable slots: {jarl_name}, {household_name}, {resource_amount}, {outcome}
5. Join sentences with single line breaks
6. Return assembled prose string

---

### Task 4.3 — Author Initial Skald Template Library
**File to create:** `res://data/skald/SkaldTemplates.gd` or .json

Minimum templates for Phase 1 (one per event, terse Norse voice):

```
harvest_good: "{jarl_name} kept the fields full. The {household_name} worked without complaint."
harvest_poor: "The fields gave less than hoped. {jarl_name} said nothing about it."
raid_success: "{jarl_name} led the warband to {target_name} and came home with silver."
raid_failure: "The raid did not go as planned. {casualty_count} men did not return."
raid_heir_success: "{heir_name} led his first raid and came home standing."
raid_heir_death: "{heir_name} did not return from {target_name}. The hall was quiet that night."
household_succession: "Old {old_head_name} passed the headship to {new_head_name} before the first snow."
oath_kept: "{jarl_name} kept the oath made in Spring. The {household_name} remembered."
oath_broken: "The Spring oath went unfulfilled. {jarl_name} did not speak of it."
harsh_winter_survived: "The winter was harder than expected. They survived."
quarantine_fired: "Sickness moved through the settlement. {household_name} bore the worst of it."
feast_held: "{jarl_name} opened the hall. The mead ran long."
```

---

### Task 4.4 — Build Autumn UI
**File to create:** `res://scenes/autumn/AutumnPhaseUI.tscn`

**Screen layout:**
1. Skald Report text (prominent, first thing seen)
2. Continue button reveals Winter Readiness Assessment below
3. Winter Readiness Assessment:
   - Food: [current] vs [projected Winter consumption] — colour coded
   - Wood: [current] vs [projected Winter heating] — colour coded
   - Gold: [current] vs [potential emergency costs] — colour coded
   - Severity forecast: "Mild / Moderate / Harsh / Brutal" based on current randomised score
4. Proceed to Winter button

No allocation UI. No decision inputs. Witness only.

---

## TASK GROUP 5: Winter Hall
**Priority:** Medium — current Winter is functional but lacks legacy depth
**Goal:** Hall Actions feel like scarce, meaningful currency

---

### Task 5.1 — Remove Winter Day Counter
**File to modify:** `res://autoload/DynastyManager.gd` or WinterManager

Remove day-based Winter loop. Replace with Hall Action-based loop:
- Winter begins with Phase 1 deductions
- After deductions: player has `available_hall_actions` (= Authority Score / 3, clamped 2–6)
- Each action taken decrements counter
- When counter reaches 0 OR player confirms end Winter: transition to Spring

---

### Task 5.2 — Hall Action UI
**File to create:** `res://scenes/winter/WinterHallUI.tscn`

Display:
- Hall Actions remaining (prominent — this is the scarce resource)
- Available actions list (disabled if insufficient actions remain)
- Severity deduction summary (Phase 1 result, always visible)
- Emergency cost options (if deductions couldn't be covered, shown first)

Actions available in Phase 1 (stub if not yet implemented):
- Heir Training (implemented this phase)
- Legacy Projects (stub — "No projects available yet")
- New Household (stub — "No households seeking shelter")
- End Winter Early (always available — pass remaining actions)

---

### Task 5.3 — Heir Training Action
**File to create:** `res://scenes/winter/HeirTrainingAction.tscn`

**On open:**
- List available training sources in settlement
- For each household: show name, current oath tradition depth, estimated stat boost
- Show Jarl as training source with relevant stat values
- Show tutor option (if available based on Renown/diplomatic flags) with gold cost

**Boost calculation:**
```gdscript
func calculate_training_boost(source_type: String, source_data) -> Dictionary:
    match source_type:
        "household":
            var tradition_multiplier = 1.0 + (source_data.consecutive_oath_years * 0.15)
            var base_boost = 2
            return {"stat": source_data.head_trait.relevant_stat, 
                    "amount": int(base_boost * tradition_multiplier)}
        "jarl":
            return {"stat": current_jarl.highest_stat(), "amount": 2}
        "tutor":
            return {"stat": source_data.tutor_stat, "amount": 4} # tutors give larger boost
```

**On confirm:**
- Apply stat boost to heir JarlData
- Store training source on heir for biography generation
- Decrement Hall Actions by 1
- Generate Skald log entry: "heir_training" with source name

---

## TASK GROUP 6: GUT Test Suite
**Priority:** Medium — run after each task group is complete

```gdscript
# test_founding_sequence.gd

func test_stat_distribution_warrior_father():
    var founding_data = FoundingData.new()
    founding_data.father_archetype = "warrior"
    founding_data.boosted_stat = "command"
    founding_data.penalised_stat = "diplomacy"
    FoundingSequenceManager._apply_founding_to_jarl(founding_data)
    var jarl = DynastyManager.current_jarl
    assert_true(jarl.command >= 10 and jarl.command <= 15, "Boosted stat in range 10-15")
    assert_true(jarl.diplomacy >= 5 and jarl.diplomacy <= 8, "Penalised stat in range 5-8")

func test_exile_reason_rival_jarl_starts_with_warband():
    var founding_data = FoundingData.new()
    founding_data.exile_reason = "rival_jarl"
    FoundingSequenceManager._apply_founding_to_settlement(founding_data)
    assert_true(SettlementManager.warband_size > 0, "Rival Jarl exile starts with warband")
    assert_eq(SettlementManager.households.size(), 2, "Rival Jarl exile starts with 2 households")

func test_exile_reason_opportunity_winter_multiplier():
    var founding_data = FoundingData.new()
    founding_data.exile_reason = "seeking_opportunity"
    FoundingSequenceManager._apply_founding_to_settlement(founding_data)
    var base_chance = WinterManager.base_harsh_chance
    var expected = base_chance * FoundingSequenceManager.opportunity_seeker_winter_multiplier
    assert_almost_eq(WinterManager.harsh_chance, expected, 0.01, "Winter multiplier applied correctly")

func test_first_act_generous_gift_reduces_food():
    var founding_data = FoundingData.new()
    founding_data.first_act = "generous_gift"
    var food_before = EconomyManager.food
    FoundingSequenceManager._apply_founding_to_settlement(founding_data)
    assert_almost_eq(EconomyManager.food, food_before * 0.5, 1.0, "Generous gift halves starting food")

func test_spring_card_gate_filters_by_stat():
    DynastyManager.current_jarl.stewardship = 5 # below threshold
    var cards = SpringCardSelector.select_spring_cards()
    var has_harvest_card = cards.any(func(c): return c.card_id == "card_harvest_oath")
    assert_false(has_harvest_card, "Harvest card not shown when Stewardship below threshold")

func test_spring_card_threshold_scales_with_stat():
    DynastyManager.current_jarl.stewardship = 15
    var cards = SpringCardSelector.select_spring_cards()
    var harvest_card = cards.filter(func(c): return c.card_id == "card_harvest_oath")[0]
    var high_stat_threshold = harvest_card.calculated_threshold
    DynastyManager.current_jarl.stewardship = 10
    cards = SpringCardSelector.select_spring_cards()
    harvest_card = cards.filter(func(c): return c.card_id == "card_harvest_oath")[0]
    var low_stat_threshold = harvest_card.calculated_threshold
    assert_true(high_stat_threshold > low_stat_threshold, "Higher stat produces higher threshold")

func test_oath_consequence_fires_on_failure():
    DynastyManager.active_spring_oath = "card_harvest_oath"
    DynastyManager.spring_oath_threshold = 100
    EconomyManager.food_harvested_this_year = 50 # below threshold
    DynastyManager._resolve_spring_oath()
    assert_true(DynastyManager.oath_broken_this_year, "Oath broken flag set on failure")

func test_hall_actions_calculated_correctly():
    DynastyManager.current_jarl.authority_score = 12
    WinterManager.calculate_hall_actions()
    assert_eq(WinterManager.available_hall_actions, 4, "Hall actions = authority_score / 3 clamped")

func test_hall_actions_use_or_lose():
    WinterManager.available_hall_actions = 3
    WinterManager.end_winter()
    assert_eq(WinterManager.available_hall_actions, 0, "Hall actions zeroed on Winter end")

func test_skald_report_generates_from_log():
    DynastyManager.year_event_log = [
        {"event_id": "harvest_good", "variables": {"jarl_name": "Bjorn", "household_name": "The Red-Shields"}, "significance": 2},
        {"event_id": "raid_success", "variables": {"jarl_name": "Bjorn", "target_name": "the Frankish shore"}, "significance": 3}
    ]
    var report = SkaldReportGenerator.generate_report(DynastyManager.year_event_log)
    assert_true(report.length() > 0, "Report generated from event log")
    assert_true(report.contains("Bjorn"), "Jarl name inserted into report")

func test_founding_echo_card_only_year_one():
    DynastyManager.current_year = 2
    var cards = SpringCardSelector.select_spring_cards()
    var has_echo = cards.any(func(c): return c.is_founding_echo)
    assert_false(has_echo, "Founding echo cards not available after year 1")
```

---

## TASK GROUP 7: Renown Decay & Debt System
**Priority:** Medium — add to Phase 1 before vertical slice is considered complete
**Goal:** Boldness has mechanical teeth. Crisis has one costly lifeline.

---

### Task 7.1 — Renown Decay System
**File to modify:** `res://autoload/DynastyManager.gd`
**File to modify:** `res://autoload/EventBalanceData.gd`

**Add to DynastyManager:**
```gdscript
var consecutive_safe_oaths: int = 0
var renown_decay_active: bool = false
```

**Add to EventBalanceData:**
```gdscript
@export var renown_decay_rate: float = 0.05 # 5% per safe year, tunable
@export var renown_decay_grace_period: int = 2 # safe oaths before decay begins
```

**Logic on Spring oath selection:**
- If player selects safe oath (threshold comfortably within reach): increment consecutive_safe_oaths
- If player selects bold oath (threshold at or above comfortable reach): reset consecutive_safe_oaths to 0, set renown_decay_active = false
- If consecutive_safe_oaths == grace_period: display warning in saga voice before player confirms

**Warning text (hand-authored, display as narrative popup):**
*"Three years have passed without a deed worth singing. Your rivals grow bolder. Your allies grow uncertain. Your own hall speaks your name more quietly than before. Another year of stillness and your Renown will begin to fade."*

**On year end if consecutive_safe_oaths > grace_period:**
```gdscript
var decay_amount = int(DynastyManager.renown * EventBalanceData.renown_decay_rate)
DynastyManager.renown -= decay_amount
DynastyManager.year_event_log.append({
    "event_id": "renown_decay",
    "variables": {"amount": decay_amount},
    "significance": 1
})
```

**Skald template for renown_decay:**
`"renown_decay": "{jarl_name}'s name has not traveled far this year."`

**Bold oath definition:** A card whose calculated threshold exceeds the Jarl's comfortable reach — implement as threshold > (relevant_stat * 1.2). Expose multiplier on EventBalanceData.

---

### Task 7.2 — Debt System
**File to modify:** `res://autoload/DynastyManager.gd`
**File to create:** `res://data/events/DebtOfferData.gd`
**File to create:** `res://scenes/autumn/DebtOfferScreen.tscn`

**Add to DynastyManager:**
```gdscript
var active_debt: DebtOfferData = null
var debt_history: Array[Dictionary] = [] # tracks past debts and repayment record
```

**DebtOfferData resource:**
```gdscript
class_name DebtOfferData
extends Resource

var creditor_name: String
var creditor_renown: int
var grain_offered: int
var repayment_type: String # "gold", "warband_service", "heir_hostage", "territorial"
var repayment_amount: int
var repayment_due_season: int # Summer of following year
var offer_explanation: String # assembled narrative text
var inherited: bool = false # true if transferred from previous Jarl
```

**Trigger check on Autumn transition:**
```gdscript
func _check_debt_trigger() -> void:
    if active_debt != null:
        return # already in debt, no second lifeline
    var food_threshold = EconomyManager.projected_winter_consumption * 0.3
    if EconomyManager.food < food_threshold:
        _generate_debt_offer()
```

**`_generate_debt_offer()`**
Evaluate offer terms based on:
- `DynastyManager.renown` — higher Renown = better terms
- `RaidManager.last_raid_outcome` — successful raid = creditor confident in repayment
- `DynastyManager.current_jarl.diplomacy` — affects framing of explanation
- `DynastyManager.current_jarl.charisma` — affects creditor's personal warmth
- `DynastyManager.debt_history` — clean record = better terms, default = worse terms or refusal
- `DynastyManager.lineage` — check for notable ancestor Renown, include in explanation if found

Assemble `offer_explanation` from evaluated factors. Example assembly:
```gdscript
var explanation = ""
if DynastyManager.renown >= 500:
    explanation += "Your name carries weight on the coast. "
if last_raid_outcome == "success":
    explanation += "Your warband came home with silver — we know you can repay. "
if notable_ancestor_found:
    explanation += "Your grandfather {ancestor_name} was known to us. His blood speaks well of you. "
if debt_history_clean:
    explanation += "You have honoured debts before. "
explanation += "We offer {grain_amount} grain. In return, {repayment_description}."
offer_explanation = explanation
```

**Debt offer screen:** Shows creditor name, grain offered, repayment terms, and full explanation text. Two buttons only: Accept / Refuse. No negotiation.

**On acceptance:** Store DebtOfferData on DynastyManager.active_debt. Add grain to EconomyManager.food.

**On Jarl death with active debt:**
```gdscript
func _inherit_debt() -> void:
    if active_debt == null: return
    active_debt.inherited = true
    active_debt.repayment_amount = int(active_debt.repayment_amount * 1.3) # 30% increase
    # Creditor envoy text generated for heir's first Winter
```

**On repayment completion:** Clear active_debt, add clean record to debt_history.

**On default (repayment not met by due season):** Clear active_debt, add default record to debt_history, activate rival threat flag for creditor Jarl.

---

## TASK GROUP 8: GUT Tests — New Systems

```gdscript
# test_renown_decay.gd

func test_decay_not_active_before_grace_period():
    DynastyManager.consecutive_safe_oaths = 1
    DynastyManager._process_year_end()
    assert_false(DynastyManager.renown_decay_active, "No decay before grace period")

func test_warning_fires_on_grace_period_oath():
    DynastyManager.consecutive_safe_oaths = 2
    var warning_fired = false
    DynastyManager.connect("renown_decay_warning", func(): warning_fired = true)
    SpringCardSelector._on_safe_oath_selected()
    assert_true(warning_fired, "Warning fires on third consecutive safe oath")

func test_decay_fires_after_grace_period():
    DynastyManager.consecutive_safe_oaths = 3
    var renown_before = DynastyManager.renown
    DynastyManager._process_year_end()
    var expected = renown_before - int(renown_before * EventBalanceData.renown_decay_rate)
    assert_eq(DynastyManager.renown, expected, "Renown decays by correct amount")

func test_bold_oath_resets_counter():
    DynastyManager.consecutive_safe_oaths = 3
    SpringCardSelector._on_bold_oath_selected()
    assert_eq(DynastyManager.consecutive_safe_oaths, 0, "Bold oath resets counter")

# test_debt_system.gd

func test_debt_not_triggered_above_threshold():
    EconomyManager.food = 100
    EconomyManager.projected_winter_consumption = 100 # food = 100% of threshold
    DynastyManager._check_debt_trigger()
    assert_null(DynastyManager.active_debt, "Debt not triggered above food threshold")

func test_debt_triggered_below_threshold():
    EconomyManager.food = 20
    EconomyManager.projected_winter_consumption = 100 # food = 20% — below 30% threshold
    DynastyManager._check_debt_trigger()
    assert_not_null(DynastyManager.active_debt, "Debt offer generated below threshold")

func test_no_second_debt_while_active():
    DynastyManager.active_debt = DebtOfferData.new()
    EconomyManager.food = 10
    EconomyManager.projected_winter_consumption = 100
    DynastyManager._check_debt_trigger()
    assert_eq(DynastyManager.active_debt, DynastyManager.active_debt, "No second debt generated while active")

func test_debt_inherited_on_jarl_death():
    var original_amount = 50
    DynastyManager.active_debt = DebtOfferData.new()
    DynastyManager.active_debt.repayment_amount = original_amount
    DynastyManager._inherit_debt()
    assert_true(DynastyManager.active_debt.inherited, "Debt flagged as inherited")
    assert_eq(DynastyManager.active_debt.repayment_amount, int(original_amount * 1.3), "Inherited debt increased by 30%")

func test_default_activates_rival_flag():
    DynastyManager.active_debt = DebtOfferData.new()
    DynastyManager.active_debt.creditor_name = "Jarl Sigurd"
    DynastyManager._process_debt_default()
    assert_true(DynastyManager.rival_threat_active, "Default activates rival threat flag")
    assert_null(DynastyManager.active_debt, "Active debt cleared on default")
```

| File | Status | Task |
|------|--------|------|
| `res://data/founding/FoundingData.gd` | Create | 1.1 |
| `res://autoload/FoundingSequenceManager.gd` | Create | 1.2 |
| `res://scenes/founding/FatherNatureScreen.tscn` | Create | 1.3 |
| `res://scenes/founding/ExileReasonScreen.tscn` | Create | 1.4 |
| `res://scenes/founding/FirstActScreen.tscn` | Create | 1.5 |
| `res://scenes/founding/FoundingLocationScreen.tscn` | Create | 1.6 |
| `res://data/spring/SpringCardData.gd` | Create | 2.1 |
| `res://autoload/SpringCardSelector.gd` | Create | 2.2 |
| `res://data/spring/cards/*.tres` | Create | 2.4 |
| `res://autoload/EventManager.gd` | Modify | 4.1 |
| `res://autoload/SkaldReportGenerator.gd` | Create | 4.2 |
| `res://data/skald/SkaldTemplates.gd` | Create | 4.3 |
| `res://scenes/autumn/AutumnPhaseUI.tscn` | Create | 4.4 |
| `res://scenes/winter/WinterHallUI.tscn` | Create | 5.2 |
| `res://scenes/winter/HeirTrainingAction.tscn` | Create | 5.3 |
| `res://data/settlements/HouseholdData.gd` | Modify | 3.1 |
| `res://autoload/SettlementManager.gd` | Modify | 3.1, 1.4, 1.5 |
| `res://autoload/EconomyManager.gd` | Modify | 3.3 |
| `res://autoload/DynastyManager.gd` | Modify | 2.3, 5.1, 7.1, 7.2 |
| `res://autoload/EventBalanceData.gd` | Modify | 1.2, 7.1 |
| `res://data/events/DebtOfferData.gd` | Create | 7.2 |
| `res://scenes/autumn/DebtOfferScreen.tscn` | Create | 7.2 |

---

## Notes for Claude Code / Gemini

- All new autoloads must be registered in `project.godot`
- All new Resource classes need `class_name` declarations
- Use `@export` for any tuning variable that game designers may want to adjust
- Skald template strings use `{variable_name}` format — use `String.format()` or equivalent for substitution
- Event log should be cleared at the start of each new year, not at the end
- Do not modify existing save/load logic until founding sequence is confirmed working in new games
- The `opportunity_seeker_winter_multiplier` and `crags_renown_per_trigger` must live on EventBalanceData alongside existing balance exports
- Founding sequence should only fire on new game, not on load — check DynastyManager for existing `current_year` value
- Renown decay bold oath threshold multiplier (default 1.2) should be exported on EventBalanceData
- Debt trigger threshold (default 0.3) should be exported on EventBalanceData
- Debt inheritance increase rate (default 1.3) should be exported on EventBalanceData
- DebtOfferScreen should only be accessible from AutumnPhaseUI — not callable from any other scene
