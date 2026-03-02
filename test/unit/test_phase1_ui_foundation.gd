# test/unit/test_phase1_ui_foundation.gd
# GUT tests for Phase 1 — Theme resource + shared components
# Run via the Godot GUT panel.
extends GutTest

const THEME_PATH    := "res://ui/themes/DarkSagaTheme.tres"
const LEDGER_SCENE  := preload("res://ui/components/LedgerRow.tscn")
const DOTS_SCENE    := preload("res://ui/components/ProgressDots.tscn")

var _ledger: LedgerRow
var _dots: ProgressDots


func before_each() -> void:
	_ledger = LEDGER_SCENE.instantiate()
	add_child_autofree(_ledger)
	_dots = DOTS_SCENE.instantiate()
	add_child_autofree(_dots)


# --- 1.1 Theme resource ---

func test_dark_saga_theme_loads() -> void:
	var theme: Theme = load(THEME_PATH)
	assert_not_null(theme, "DarkSagaTheme.tres should load without errors")
	assert_is(theme, Theme, "Loaded resource should be a Theme")


func test_dark_saga_theme_has_default_font() -> void:
	var theme: Theme = load(THEME_PATH)
	assert_not_null(theme, "Theme must load")
	# default_font is set — CrimsonText
	assert_true(theme.default_font != null, "Theme should have a default_font assigned")


# --- 1.5 LedgerRow.set_net() colour logic ---

func test_ledger_row_positive_net_color() -> void:
	_ledger.set_net(50)
	var color: Color = _ledger.net_col.get_theme_color("font_color")
	assert_eq(color, LedgerRow.COLOR_POSITIVE,
		"Positive net should use PROSPERITY green")


func test_ledger_row_negative_net_color() -> void:
	_ledger.set_net(-30)
	var color: Color = _ledger.net_col.get_theme_color("font_color")
	assert_eq(color, LedgerRow.COLOR_NEGATIVE,
		"Negative net should use DANGER red")


func test_ledger_row_zero_net_color() -> void:
	_ledger.set_net(0)
	var color: Color = _ledger.net_col.get_theme_color("font_color")
	assert_eq(color, LedgerRow.COLOR_ZERO,
		"Zero net should use TEXT_SECONDARY grey")


func test_ledger_row_positive_net_text() -> void:
	_ledger.set_net(100)
	assert_eq(_ledger.net_col.text, "+100",
		"Positive net text should be prefixed with '+'")


func test_ledger_row_negative_net_text() -> void:
	_ledger.set_net(-15)
	assert_eq(_ledger.net_col.text, "-15",
		"Negative net text should show sign")


func test_ledger_row_zero_net_text() -> void:
	_ledger.set_net(0)
	assert_eq(_ledger.net_col.text, "—",
		"Zero net should display em dash")


func test_ledger_row_setup_populates_all_columns() -> void:
	_ledger.setup("Food", "140", 20)
	assert_eq(_ledger.label_col.text, "Food")
	assert_eq(_ledger.value_col.text, "140")
	assert_eq(_ledger.net_col.text, "+20")


# --- 1.4 ProgressDots ---

func test_progress_dots_has_four_dots() -> void:
	assert_eq(_dots._dots.size(), 4,
		"ProgressDots should have exactly 4 dot nodes")


func test_progress_dots_active_step_sets_colors() -> void:
	_dots.set_active_step(1)
	assert_eq(_dots._dots[0].color, ProgressDots.COLOR_DONE,
		"Step 0 should be DONE when active=1")
	assert_eq(_dots._dots[1].color, ProgressDots.COLOR_ACTIVE,
		"Step 1 should be ACTIVE")
	assert_eq(_dots._dots[2].color, ProgressDots.COLOR_PENDING,
		"Step 2 should be PENDING")
	assert_eq(_dots._dots[3].color, ProgressDots.COLOR_PENDING,
		"Step 3 should be PENDING")


func test_progress_dots_all_done() -> void:
	_dots.set_all_done()
	for dot in _dots._dots:
		assert_eq(dot.color, ProgressDots.COLOR_DONE,
			"All dots should be DONE after set_all_done()")


func test_progress_dots_first_step_has_no_done_dots() -> void:
	_dots.set_active_step(0)
	assert_eq(_dots._dots[0].color, ProgressDots.COLOR_ACTIVE,
		"Step 0 should be ACTIVE")
	assert_eq(_dots._dots[1].color, ProgressDots.COLOR_PENDING,
		"Steps after active should be PENDING")
