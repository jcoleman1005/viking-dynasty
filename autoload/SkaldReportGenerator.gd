# res://autoload/SkaldReportGenerator.gd
# Generates a three-paragraph narrative summary of the year for AutumnScreen.
# Paragraph keys are sourced from SkaldTemplates.gd.
#
# API:
#   generate_report(context: Dictionary) -> String
#   context keys used: year_events, oath_result, forecast, treasury, payout,
#                      jarl_name, current_year, winter_severity
extends Node


## Generates a three-paragraph saga prose report.
## Returns a multi-line string; paragraphs separated by double newline.
func generate_report(context: Dictionary) -> String:
	var vars := _build_vars(context)

	var p1 := _para_1_activity(context, vars)
	var p2 := _para_2_oath(context, vars)
	var p3 := _para_3_horizon(context, vars)

	var parts: Array[String] = []
	for p in [p1, p2, p3]:
		if p != "":
			parts.append(p)

	if parts.is_empty():
		return "[i]The year passed without great deed or great loss. The hall endures.[/i]"

	return "\n\n".join(parts)


# ---------------------------------------------------------------------------
# Paragraph builders
# ---------------------------------------------------------------------------

func _para_1_activity(context: Dictionary, vars: Dictionary) -> String:
	var key := _dominant_activity_key(context)
	return _fill(key, vars)


func _para_2_oath(context: Dictionary, vars: Dictionary) -> String:
	var oath_result: Dictionary = context.get("oath_result", {})
	var outcome: String = oath_result.get("outcome", "none")
	vars["oath_name"] = oath_result.get("oath_id", "")
	return _fill("oath_%s" % outcome, vars)


func _para_3_horizon(context: Dictionary, vars: Dictionary) -> String:
	var severity: String = context.get("winter_severity", "normal")
	var food_state := _food_state(context)
	return _fill("%s_%s" % [severity, food_state], vars)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _dominant_activity_key(context: Dictionary) -> String:
	# Scan year_events for highest-significance entry that maps to a para-1 key.
	var para1_keys := ["raid_success", "raid_failure", "raid_partial",
		"harvest_good", "harvest_poor", "harvest_critical",
		"harvest_focus", "build_focus", "scout"]
	var events: Array = context.get("year_events", [])
	var sorted := events.duplicate()
	sorted.sort_custom(func(a, b): return a.get("significance", 0) > b.get("significance", 0))

	for entry in sorted:
		var eid: String = entry.get("event_id", "")
		if eid in para1_keys:
			return eid

	# Fallback: derive from year_metrics via DynastyManager
	if DynastyManager.year_metrics.get("gold_raided", 0) > 0:
		return "raid_success"
	if DynastyManager.year_metrics.get("food_harvested", 0) > 0:
		return "harvest_focus"
	if DynastyManager.year_metrics.get("buildings_completed", 0) > 0:
		return "build_focus"

	return "scout"


func _food_state(context: Dictionary) -> String:
	var forecast: Dictionary = context.get("forecast", {})
	var treasury: Dictionary = context.get("treasury", {})
	var payout: Dictionary  = context.get("payout", {})

	var demand: int  = int(forecast.get("food", 0))
	var held: int    = int(treasury.get("food", 0))
	var harvest: int = int(payout.get("food", 0))

	return "surplus" if (held + harvest) >= demand else "deficit"


func _build_vars(context: Dictionary) -> Dictionary:
	var settlement := SettlementManager.current_settlement
	var first_household := "the household"
	if settlement and not settlement.households.is_empty():
		var h = settlement.households[0]
		if h.household_name:
			first_household = h.household_name

	return {
		"jarl_name":       context.get("jarl_name", "The Jarl"),
		"current_year":    str(context.get("current_year", 880)),
		"household_name":  first_household,
		"warband_name":    "the warband",
		"target_name":     "the coast",
		"casualty_count":  "some",
	}


func _fill(key: String, vars: Dictionary) -> String:
	if ClassDB.class_exists("SkaldTemplates"):
		return SkaldTemplates.fill_template(key, vars)
	return ""
