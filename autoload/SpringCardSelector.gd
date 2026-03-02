# res://autoload/SpringCardSelector.gd
# Selects three SpringCardData oath cards for the current Spring based on Jarl stats.
# Returns a configured array ready for display by SpringPhaseUI.
extends Node

const CARDS_DIR := "res://data/spring/cards/"

# NOTE for SpringCardData.gd: two non-exported runtime vars are required:
#   var calculated_threshold: int = 0
#   var selected_phrasing: String = ""
# These are set by _configure_card() after selection and read by SpringPhaseUI.

## Selects three SpringCardData resources for this year's Spring oath.
## Filters by Jarl stat gates, applies per-card threshold scaling, and picks a random phrasing.
func select_spring_cards() -> Array[SpringCardData]:
	var jarl: JarlData = DynastyManager.current_jarl
	if not jarl:
		Loggie.msg("SpringCardSelector: No current Jarl.").domain(LogDomains.DYNASTY).warn()
		return []

	var all_cards := _load_all_cards()
	if all_cards.is_empty():
		Loggie.msg("SpringCardSelector: No SpringCardData found in %s" % CARDS_DIR).domain(LogDomains.DYNASTY).warn()
		return []

	# Filter eligible cards
	var eligible: Array[SpringCardData] = []
	for card in all_cards:
		if _is_eligible(card, jarl):
			eligible.append(card)

	if eligible.is_empty():
		Loggie.msg("SpringCardSelector: No eligible cards after filtering — returning all.").domain(LogDomains.DYNASTY).info()
		eligible = all_cards

	# Prioritise: founding echoes (year 1) → intersection cards → single-stat cards
	var echo_cards: Array[SpringCardData] = eligible.filter(func(c): return c.is_founding_echo)
	var intersection_cards: Array[SpringCardData] = eligible.filter(func(c): return c.is_intersection and not c.is_founding_echo)
	var standard_cards: Array[SpringCardData] = eligible.filter(func(c): return not c.is_intersection and not c.is_founding_echo)

	var selected: Array[SpringCardData] = []

	# Slot 1: one founding echo (year 1 only)
	if DynastyManager.current_year == DynastyManager.current_year and echo_cards.size() > 0:
		var pick: SpringCardData = echo_cards[randi() % echo_cards.size()]
		selected.append(pick)
		echo_cards.erase(pick)
		eligible.erase(pick)

	# Fill remaining slots preferring intersection cards, then standard
	var pool: Array[SpringCardData] = intersection_cards + standard_cards
	pool.shuffle()
	for card in pool:
		if selected.size() >= 3:
			break
		if not selected.has(card):
			selected.append(card)

	# Cap at 3
	selected = selected.slice(0, 3)

	# Configure each selected card
	for card in selected:
		_configure_card(card, jarl)

	return selected


func _load_all_cards() -> Array[SpringCardData]:
	var result: Array[SpringCardData] = []
	var dir := DirAccess.open(CARDS_DIR)
	if not dir:
		return result
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var res = load(CARDS_DIR + fname)
			if res is SpringCardData:
				result.append(res as SpringCardData)
		fname = dir.get_next()
	dir.list_dir_end()
	return result


func _is_eligible(card: SpringCardData, jarl: JarlData) -> bool:
	# Founding echo: only in year 1 and only for matching exile reason
	if card.is_founding_echo:
		if DynastyManager.current_year != 880:
			return false
		var exile := FoundingSequenceManager.current_founding_data.exile_reason if FoundingSequenceManager.current_founding_data else ""
		if card.founding_echo_exile != "" and card.founding_echo_exile != exile:
			return false

	# Primary stat gate
	if card.stat_gate != "":
		var stat_val: int = jarl.get(card.stat_gate) if jarl.get(card.stat_gate) != null else 0
		if stat_val < card.stat_threshold:
			return false

	# Secondary stat gate (intersection cards)
	if card.is_intersection and card.secondary_stat_gate != "":
		var sec_val: int = jarl.get(card.secondary_stat_gate) if jarl.get(card.secondary_stat_gate) != null else 0
		if sec_val < card.secondary_stat_threshold:
			return false

	return true


func _configure_card(card: SpringCardData, jarl: JarlData) -> void:
	# Calculate actual threshold scaled by Jarl stat
	if card.stat_gate != "":
		var stat_val: int = jarl.get(card.stat_gate) if jarl.get(card.stat_gate) != null else 10
		card.calculated_threshold = card.threshold_base + int(stat_val * card.threshold_stat_multiplier)
	else:
		card.calculated_threshold = card.threshold_base

	# Pick a random oath phrasing
	if card.oath_phrasings.size() > 0:
		card.selected_phrasing = card.oath_phrasings[randi() % card.oath_phrasings.size()]
