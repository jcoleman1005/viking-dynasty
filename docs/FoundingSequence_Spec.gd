# Founding Sequence — Design & Implementation Spec
# ==================================================
# Status: READY FOR IMPLEMENTATION
# New scenes:
#   res://ui/founding/FoundingScreen.tscn + FoundingScreen.gd
#   res://ui/founding/FoundingChoice1.tscn  (Father's Nature)
#   res://ui/founding/FoundingChoice2.tscn  (Exile Reason)
#   res://ui/founding/FoundingChoice3.tscn  (First Act)
#   res://ui/founding/FoundingEpithet.tscn  (Reveal)
#   res://data/founding/FoundingData.gd     (data container)
#   res://autoload/FoundingGenerator.gd     (stat generation + epithet)

# ==============================================================================
# DESIGN INTENT
# ==============================================================================
#
# The player is recounting their father's story. Three choices, each a
# commitment. No back navigation. No numbers visible. Stats emerge from
# narrative — the player discovers who their Jarl is through play.
#
# The sequence ends with a founding epithet assembled from all three choices,
# displayed in full before the game begins. This is the player's first piece
# of saga — generated from what they chose, not from what the game decided.
#
# ==============================================================================
# FLOW
# ==============================================================================
#
# MainMenu → "Begin the Saga" → FoundingScreen
#
# FoundingScreen is a CanvasLayer controller (layer = 0, replaces map entirely).
# It manages four sequential child panels as sub-scenes.
#
# Sequence:
#   FoundingChoice1 (Father's Nature)
#     → player picks archetype → picks strength clause → picks flaw clause
#     → commits → FoundingChoice2 appears
#
#   FoundingChoice2 (Exile Reason)
#     → player picks one of three exile situations
#     → commits → FoundingChoice3 appears
#
#   FoundingChoice3 (First Act)
#     → player picks one of three opening problems
#     → commits → FoundingEpithet appears
#
#   FoundingEpithet (Reveal)
#     → full epithet displayed, stat pillar revealed narratively
#     → "Begin — Year 880" button → DynastyGenerator.generate_from_founding(data)
#     → MainGameUI loads, campaign starts
#
# FoundingData resource is assembled across all four screens and passed to
# FoundingGenerator at the end.
#
# ==============================================================================
# FOUNDING DATA RESOURCE
# ==============================================================================
#
# res://data/founding/FoundingData.gd
# class_name FoundingData extends Resource
#
# @export var father_archetype: String      # "warrior" | "builder" | "diplomat"
# @export var strength_clause: String       # Selected clause text
# @export var strength_stat: String         # stat this clause boosts
# @export var flaw_clause: String           # Selected flaw text
# @export var flaw_stat: String             # stat this clause penalises
# @export var exile_reason: String          # "frankish" | "rival" | "opportunity"
# @export var first_act: String             # "sworn" | "challenged" | "generous"
# @export var jarl_name: String             # Player-entered (optional, can be generated)
# @export var father_name: String           # Generated from archetype
# @export var founding_epithet: String      # Assembled at end
#
# ==============================================================================
# SCREEN 1: FATHER'S NATURE
# ==============================================================================
#
# Three beats within one screen:
#
# Beat A — Archetype selection:
#   Three large options, each showing only the archetype label and a one-line
#   description. No stats mentioned.
#     "The Warrior"   — He built his legacy on iron and blood.
#     "The Builder"   — He built his legacy with timber and patience.
#     "The Diplomat"  — He built his legacy with words and alliances.
#   Player clicks one. Selected archetype highlights. Sentence frame appears:
#     "He [________], but [________]."
#   Both slots shown as blanks, glowing faintly.
#
# Beat B — Strength clause selection:
#   The strength slot is active. A pool of 4–5 clauses appears for the chosen
#   archetype. Player clicks one. The blank fills with the chosen clause text.
#   Sentence so far: "He [never lost a battle], but [________]."
#
# Beat C — Flaw clause selection:
#   The flaw slot becomes active. The shared flaw pool appears (7 options).
#   Player clicks one. Sentence completes:
#     "He [never lost a battle], but [carried a grudge to his dying day]."
#   A "Commit" button appears beneath the completed sentence.
#   Player can re-click strength or flaw to change before committing.
#   Clicking Commit locks Screen 1 and advances to Screen 2.
#
# STRENGTH CLAUSE DATA STRUCTURE (per archetype):
#   {
#     "text": String,          # display text
#     "stat": String,          # boosted stat ("command" | "prowess" etc)
#     "epithet_seed": String,  # word used in epithet generation
#   }
#
# FLAW CLAUSE DATA STRUCTURE:
#   {
#     "text": String,
#     "stat": String,          # penalised stat
#   }
#
# ==============================================================================
# CLAUSE POOLS (content — author before implementation)
# ==============================================================================
#
# WARRIOR STRENGTH CLAUSES (boost Command or Prowess):
#   { text: "never lost a battle",            stat: "command",  epithet_seed: "Iron-Handed" }
#   { text: "trained his men harder than any jarl alive", stat: "command", epithet_seed: "the Unyielding" }
#   { text: "was feared across three fjords", stat: "prowess",  epithet_seed: "the Feared" }
#   { text: "fought at the front of every raid", stat: "prowess", epithet_seed: "the Bold" }
#   { text: "had never been bested in single combat", stat: "prowess", epithet_seed: "the Unbroken" }
#
# BUILDER STRENGTH CLAUSES (boost Stewardship or Learning):
#   { text: "could stretch a winter's grain to feed twice the mouths", stat: "stewardship", epithet_seed: "the Provider" }
#   { text: "knew every timber and stone in the settlement",           stat: "stewardship", epithet_seed: "the Builder" }
#   { text: "planned three winters ahead",                            stat: "learning",    epithet_seed: "the Far-Sighted" }
#   { text: "kept records no other jarl bothered with",               stat: "learning",    epithet_seed: "the Learned" }
#   { text: "never let a harvest go to waste",                        stat: "stewardship", epithet_seed: "the Careful" }
#
# DIPLOMAT STRENGTH CLAUSES (boost Diplomacy or Charisma):
#   { text: "could end a blood feud with three words",   stat: "diplomacy", epithet_seed: "the Peacemaker" }
#   { text: "made alliances that lasted generations",    stat: "diplomacy", epithet_seed: "the Alliance-Maker" }
#   { text: "could silence a room with a single word",   stat: "charisma",  epithet_seed: "the Silver-Tongued" }
#   { text: "inspired loyalty in men who hated each other", stat: "charisma", epithet_seed: "the Beloved" }
#   { text: "was welcomed at every jarl's table",        stat: "diplomacy", epithet_seed: "the Well-Travelled" }
#
# SHARED FLAW CLAUSES (penalise a stat from opposing pillar):
#   { text: "carried a grudge to his dying day",        stat: "diplomacy" }
#   { text: "never forgave a slight",                   stat: "charisma"  }
#   { text: "drank away half his winters",              stat: "stewardship" }
#   { text: "spent gold like it grew on the fjord",    stat: "stewardship" }
#   { text: "trusted no man's word over his own ledger", stat: "diplomacy" }
#   { text: "his own men questioned his nerve",         stat: "command"   }
#   { text: "could never sit still long enough to plan", stat: "learning" }
#
# ==============================================================================
# SCREEN 2: EXILE REASON
# ==============================================================================
#
# Three complete situation cards. Each card shows:
#   - A short title (one line, Cinzel)
#   - A two-to-three sentence situation description (Crimson Text italic)
#   - A "Consequence" line showing the concrete starting state (dimmer text)
#
# Cards do NOT show stats. The consequence line is narrative:
#   "Frankish Persecution" consequence: "You fled with your people but not your stores.
#    One household carries the trauma of what they left behind."
#
# No assembly mechanic — just three whole options. Player selects, reads, commits.
#
# EXILE OPTIONS:
#
#   FRANKISH PERSECUTION
#   Title: "The Franks Took Everything"
#   Description: "Your father built something worth taking. When the missionaries
#     came with soldiers behind them, he had days to choose — convert or flee.
#     He chose the old gods and the open sea. You were born on the water."
#   Consequence: "Fewer starting resources. One household scarred. Raids against
#     Frankish targets earn you more than gold."
#   Mechanical effects:
#     - Starting food: −30%
#     - Starting gold: −20%
#     - Household 1 labor_efficiency: 0.7 for first Summer (trauma modifier)
#     - Jarl trait: "The Dispossessed" — Renown +50% from Frankish raid targets
#
#   RIVAL JARL DROVE YOU OUT
#   Title: "You Lost. Then You Left."
#   Description: "There was another jarl — stronger then, or better connected.
#     Your father challenged him and the thing was settled badly. The men who
#     stayed loyal came with you. The ones who didn't are his now."
#   Consequence: "You have a warband but fewer households. Somewhere, a man
#     remembers what your father did. He has not forgotten."
#   Mechanical effects:
#     - Starting warband: 1 WarbandData (5 Bondi)
#     - Household count: 2 instead of 3
#     - Jarl starts with Authority −2 (legitimacy cost from losing)
#     - Dormant rival flag: rival_jarl_exists = true (EventManager watches for trigger)
#
#   SEEKING OPPORTUNITY
#   Title: "You Came Because the Land Called"
#   Description: "No catastrophe. No defeat. Your father heard something —
#     rumour of good land, a coastline worth holding, a name worth building.
#     The households who came chose to come. That matters."
#   Consequence: "Balanced start. Loyal households. But the winters here are
#     harder than rumour suggested."
#   Mechanical effects:
#     - Standard starting resources
#     - All households: loyalty +5 (they chose to follow)
#     - Harsh winter chance: base × 1.5 (EventBalanceData multiplier)
#     - No warband
#
# ==============================================================================
# SCREEN 3: FIRST ACT
# ==============================================================================
#
# Same card layout as Screen 2 — three full situations, select and commit.
# These are opening problems, not benefits. The language should make that clear.
#
# FIRST ACT OPTIONS:
#
#   SWORN TO PROTECT
#   Title: "You Made a Promise Before You Had the Means"
#   Description: "The households were afraid. You stood in the hall and swore
#     you would keep them fed and safe through the first Winter. Some wept.
#     All of them believed you. You were not certain you believed yourself."
#   Consequence: "One household expects much. If you fail them before Winter,
#     they will remember it differently."
#   Mechanical effects:
#     - Household 1 (founding_household_1): loyalty = 80, expectation_flag = true
#     - expectation_flag: loyalty drops −25 if food < winter demand at Autumn
#     - Visible obligation marker on household in sidebar all year
#
#   CHALLENGED THE ADVISOR
#   Title: "You Proved Yourself to the Room. One Man Disagreed."
#   Description: "Your father's oldest advisor thought he would manage the
#     transition. You disagreed publicly. You won the argument but you read his
#     face as he sat back down. That household is watching you closely."
#   Consequence: "One household's loyalty starts low. Consistent oath-keeping
#     will bring them around. Ignore them and they may not be here by Winter."
#   Mechanical effects:
#     - Household 3 (advisor_household): loyalty = 25
#     - If loyalty < 20 by Winter: household_departure_event triggers
#     - If loyalty >= 50 by Autumn: "Won Over" trait added to household head
#
#   GAVE AWAY THE STORES
#   Title: "You Fed the Poorest Household From Your Own Reserves"
#   Description: "It was your first act as Jarl. Perhaps it was wisdom —
#     loyalty bought cheaply. Perhaps it was foolishness you cannot afford.
#     The winter forecast was already uncertain. You made it worse."
#   Consequence: "All households begin loyal. The Winter forecast is already
#     in the red. The first year will be lean."
#   Mechanical effects:
#     - All households: loyalty +10
#     - Starting food: −40% (significant)
#     - Winter forecast shown in red from day 1 of Summer
#
# ==============================================================================
# SCREEN 4: FOUNDING EPITHET REVEAL
# ==============================================================================
#
# Full screen. Dark background. The player's choices are assembled and displayed.
#
# Layout (centred, vertical):
#
#   [small dim text] "Year 880. This is what they said of your father."
#
#   [large Cinzel, warm gold]
#   "[Father Name], [Epithet from strength_seed]"
#
#   [Crimson Text italic, medium]
#   "He [strength_clause], but [flaw_clause]."
#
#   [small separator line]
#
#   [Crimson Text, secondary]
#   "[Exile situation one-liner — e.g. 'He came from Frankish lands with nothing but his people.']"
#
#   [Crimson Text, secondary]
#   "[First act one-liner — e.g. 'His first act as Jarl was to swear an oath before he had the means to keep it.']"
#
#   [small separator line]
#
#   [dim text]
#   "You are his [son/daughter]. You carry his [pillar strength] and his [pillar weakness]."
#   "What you build from here is yours alone."
#
#   [player name entry — optional, small, below all text]
#   "Your name: [______]"  ← Cinzel input field, placeholder = generated name
#
#   [AdvanceButton]
#   "Begin — Year 880"
#
# EPITHET ASSEMBLY (FoundingGenerator.assemble_epithet()):
#   Full epithet format: "[Father Name], [strength_epithet_seed]"
#   Father name generated from archetype (pool of 20 Norse names per archetype)
#   strength_epithet_seed comes from selected strength clause
#   Example: "Bjorn, the Iron-Handed" (warrior, "never lost a battle")
#   Example: "Halvar, the Far-Sighted" (builder, "planned three winters ahead")
#   Example: "Sigurd, the Silver-Tongued" (diplomat, "could silence a room")
#
# PILLAR LANGUAGE (narrative, not stat names):
#   Warrior → "his iron" and "his pride"
#   Builder → "his patience" and "his restlessness"
#   Diplomat → "his voice" and "his mistrust"
#
# ==============================================================================
# FOUNDING GENERATOR — FoundingGenerator.gd
# ==============================================================================
#
# Called once at end of founding sequence.
# Takes FoundingData, produces JarlData ready for DynastyManager.
#
# func generate_from_founding(data: FoundingData) -> JarlData:
#     var jarl = JarlData.new()
#     jarl.display_name = data.jarl_name if data.jarl_name != "" else _generate_jarl_name()
#
#     # Stat generation
#     jarl.command     = _roll_stat(data, "command")
#     jarl.prowess     = _roll_stat(data, "prowess")
#     jarl.stewardship = _roll_stat(data, "stewardship")
#     jarl.learning    = _roll_stat(data, "learning")
#     jarl.diplomacy   = _roll_stat(data, "diplomacy")
#     jarl.charisma    = _roll_stat(data, "charisma")
#
#     # Apply exile effects
#     _apply_exile_effects(data.exile_reason, jarl)
#
#     # Apply first act effects
#     _apply_first_act_effects(data.first_act)
#
#     # Store founding context on Jarl for Spring card weighting
#     jarl.founding_archetype = data.father_archetype
#     jarl.exile_reason = data.exile_reason
#     jarl.first_act = data.first_act
#     jarl.founding_epithet = data.founding_epithet
#
#     return jarl
#
# func _roll_stat(data: FoundingData, stat: String) -> int:
#     if stat == data.strength_stat:
#         return randi_range(10, 15)   # boosted
#     elif stat == data.flaw_stat:
#         return randi_range(5, 8)     # penalised
#     else:
#         return randi_range(5, 15)    # normal
#
# ==============================================================================
# SCENE STRUCTURE
# ==============================================================================
#
# FoundingScreen (CanvasLayer, layer=0)
#   └── Background (ColorRect, full screen, #1a1610)
#       └── ScreenContainer (Control, full screen)
#           [child panels swap in/out as sequence advances]
#
# FoundingChoice1 (Control, full screen):
#   └── MainLayout (VBoxContainer, centred, max width 900px)
#       ├── ProgressDots (HBoxContainer — 3 dots, dot 1 active)
#       ├── ScreenTitle (Label, "Your Father's Nature", Cinzel 22px)
#       ├── SentenceFrame (HBoxContainer, centred)
#       │   ├── PrefixLabel "He"
#       │   ├── StrengthSlot (PanelContainer, glows when active)
#       │   │   └── SlotLabel (filled with clause text when selected)
#       │   ├── ConjLabel ", but"
#       │   └── FlawSlot (PanelContainer)
#       │       └── SlotLabel
#       ├── ArchetypeRow (HBoxContainer, shown at start, hides after archetype chosen)
#       │   ├── ArchetypeCard × 3
#       ├── ClausePanel (VBoxContainer, shown after archetype chosen)
#       │   └── ClauseOption × 4-5 (switches between strength pool / flaw pool)
#       └── CommitBtn (AdvanceButton, hidden until both slots filled)
#
# FoundingChoice2 + FoundingChoice3 (identical structure):
#   └── MainLayout (VBoxContainer, centred, max width 900px)
#       ├── ProgressDots
#       ├── ScreenTitle
#       ├── SituationCards (HBoxContainer)
#       │   └── SituationCard × 3
#       │       ├── CardTitle
#       │       ├── CardDescription
#       │       └── CardConsequence
#       └── CommitBtn (hidden until card selected)
#
# FoundingEpithet:
#   └── MainLayout (VBoxContainer, centred, max width 700px)
#       ├── PreambleLabel
#       ├── EpithetLabel (large, gold)
#       ├── SentenceLabel
#       ├── Separator
#       ├── ExileLabel
#       ├── FirstActLabel
#       ├── Separator
#       ├── PillarLabel
#       ├── NameEntry (LineEdit, optional)
#       └── BeginBtn (AdvanceButton)
#
# ==============================================================================
# SIGNALS
# ==============================================================================
#
# FoundingScreen signals:
#   signal founding_complete(data: FoundingData)
#
# Connection in SceneManager or MainMenu:
#   FoundingScreen.founding_complete.connect(_on_founding_complete)
#
# func _on_founding_complete(data: FoundingData) -> void:
#     var jarl = FoundingGenerator.generate_from_founding(data)
#     DynastyManager.start_new_campaign_with_jarl(jarl)
#     SceneManager.load_main_game()
#
# ==============================================================================
# IMPLEMENTATION ORDER
# ==============================================================================
#
# 1.  Create FoundingData.gd resource class
# 2.  Create FoundingGenerator.gd autoload with stat rolling + epithet assembly
# 3.  Build FoundingChoice1.tscn — archetype → strength → flaw → commit
# 4.  Build FoundingChoice2.tscn — three exile situation cards
# 5.  Build FoundingChoice3.tscn — three first act cards
# 6.  Build FoundingEpithet.tscn — reveal + name entry + begin
# 7.  Build FoundingScreen.tscn — controller, sequences the four panels
# 8.  Add start_new_campaign_with_jarl() to DynastyManager
# 9.  Wire founding sequence from MainMenu "Begin the Saga" button
# 10. GUT test: _roll_stat returns correct ranges for boosted/penalised/normal
# 11. GUT test: assemble_epithet returns non-empty string for all combinations
# 12. GUT test: exile effects applied correctly to starting settlement state
