extends GutTest

var _original_jarl: JarlData
var _original_balance: EventBalanceData

func before_each() -> void:
	_original_jarl = DynastyManager.current_jarl
	_original_balance = EventManager.balance_data

	var jarl := JarlData.new()
	jarl.renown = 100
	DynastyManager.current_jarl = jarl

	var bd := EventBalanceData.new()
	bd.renown_decay_rate = 0.05
	bd.renown_decay_grace_period = 2
	EventManager.balance_data = bd

	DynastyManager.consecutive_safe_oaths = 0
	DynastyManager.year_event_log = []

func after_each() -> void:
	DynastyManager.current_jarl = _original_jarl
	EventManager.balance_data = _original_balance

func test_no_decay_within_grace_period() -> void:
	DynastyManager.consecutive_safe_oaths = 1
	DynastyManager._apply_renown_decay()
	assert_eq(DynastyManager.current_jarl.renown, 100,
		"No renown decay within grace period")

func test_no_decay_at_grace_period_boundary() -> void:
	# consecutive_safe_oaths == grace_period should NOT trigger yet
	DynastyManager.consecutive_safe_oaths = 2
	DynastyManager._apply_renown_decay()
	assert_eq(DynastyManager.current_jarl.renown, 100,
		"No decay at grace period boundary (<=, not <)")

func test_decay_fires_after_grace_period() -> void:
	DynastyManager.consecutive_safe_oaths = 3
	DynastyManager._apply_renown_decay()
	var expected: int = 100 - int(100 * 0.05)
	assert_eq(DynastyManager.current_jarl.renown, expected,
		"Renown decays by correct percentage after grace period")

func test_decay_amount_scales_with_renown() -> void:
	DynastyManager.current_jarl.renown = 200
	DynastyManager.consecutive_safe_oaths = 5
	DynastyManager._apply_renown_decay()
	var expected: int = 200 - int(200 * 0.05)
	assert_eq(DynastyManager.current_jarl.renown, expected,
		"Decay amount scales proportionally to renown")

func test_renown_floors_at_zero() -> void:
	DynastyManager.current_jarl.renown = 1
	DynastyManager.consecutive_safe_oaths = 10
	DynastyManager._apply_renown_decay()
	assert_true(DynastyManager.current_jarl.renown >= 0,
		"Renown cannot go below zero")

func test_decay_logged_in_year_event_log() -> void:
	DynastyManager.consecutive_safe_oaths = 3
	DynastyManager._apply_renown_decay()
	var has_entry: bool = DynastyManager.year_event_log.any(
		func(e: Dictionary) -> bool: return e.get("event_id", "") == "renown_decay"
	)
	assert_true(has_entry, "Renown decay event logged in year_event_log for skald")

func test_no_log_entry_without_decay() -> void:
	DynastyManager.consecutive_safe_oaths = 1
	DynastyManager._apply_renown_decay()
	var has_entry: bool = DynastyManager.year_event_log.any(
		func(e: Dictionary) -> bool: return e.get("event_id", "") == "renown_decay"
	)
	assert_false(has_entry, "No log entry when decay threshold not met")
