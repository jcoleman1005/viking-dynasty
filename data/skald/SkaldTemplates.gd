class_name SkaldTemplates

static var templates: Dictionary = {
	"harvest_good": "{jarl_name} kept the fields full. The {household_name} worked without complaint.",
	"harvest_poor": "The fields gave less than hoped. {jarl_name} said nothing about it.",
	"harvest_critical": "The harvest failed. {jarl_name} counted the stores and did not sleep.",
	"raid_success": "{jarl_name} led the warband to {target_name} and came home with silver.",
	"raid_partial": "The raid at {target_name} yielded less than expected. The men came home.",
	"raid_failure": "The raid did not go as planned. {casualty_count} men did not return.",
	"raid_heir_success": "{heir_name} led his first raid and came home standing.",
	"raid_heir_death": "{heir_name} did not return from {target_name}. The hall was quiet that night.",
	"raid_jarl_injury": "{jarl_name} took a wound at {target_name}. He does not speak of it.",
	"household_succession": "Old {old_head_name} passed the headship to {new_head_name} before the first snow.",
	"household_left": "The {household_name} took their tools and left before spring. No one stopped them.",
	"household_arrived": "The {household_name} arrived before the thaw. They asked for little.",
	# Para 1 — Activity keys
	"harvest_focus": "{jarl_name} spent the Summer watching the fields. The stores grew, if slowly.",
	"build_focus": "Stone and timber changed hands all Summer. {jarl_name} measured what was built.",
	"scout": "The Summer passed quietly. {jarl_name} sent riders east and heard nothing alarming.",

	# Para 2 — Oath outcome keys
	"oath_kept": "{jarl_name} kept the oath made in Spring. The {household_name} remembered.",
	"oath_partial": "The oath fell short, though not without effort. {jarl_name} said little of it.",
	"oath_broken": "The Spring oath went unfulfilled. {jarl_name} did not speak of it.",
	"oath_none": "No oath was sworn this Spring. The year passed without that weight.",

	# Para 3 — Horizon keys (severity_foodstate)
	"harsh_surplus": "The skald predicts a bitter Winter. The stores will hold — barely.",
	"harsh_deficit": "A harsh Winter is coming and the stores are thin. {jarl_name} will need to find another way.",
	"normal_surplus": "The Winter will be hard enough, but the food is there. Sleep soundly.",
	"normal_deficit": "A difficult Winter ahead. The gap between what is stored and what is needed is real.",
	"mild_surplus": "A mild Winter is forecast and the stores are full. The {household_name} will not go hungry.",
	"mild_deficit": "Even a mild Winter will strain the stores. Something will need to give.",
	"harsh_winter_survived": "The winter was harder than expected. They survived.",
	"brutal_winter_survived": "It was the worst winter in memory. Somehow they endured.",
	"quarantine_fired": "Sickness moved through the settlement. {household_name} bore the worst of it.",
	"feast_held": "{jarl_name} opened the hall. The mead ran long.",
	"feast_saga_worthy": "They will sing of that feast. {jarl_name} did not count the cost.",
	"renown_decay": "{jarl_name}'s name has not traveled far this year.",
	"debt_accepted": "{jarl_name} sent an envoy to {creditor_name}. Grain arrived before the frost.",
	"debt_repaid": "The debt to {creditor_name} is settled. {jarl_name} does not dwell on it.",
	"debt_defaulted": "{creditor_name} has not forgotten. {jarl_name} knows this.",
	"debt_inherited": "{jarl_name} inherits more than the hall. The debt to {creditor_name} remains.",
	"heir_training": "{heir_name} trained under {trainer_name} through the dark months.",
	"jarl_death_old_age": "{jarl_name} did not wake one morning. The hall passed to {heir_name}.",
	"jarl_death_battle": "{jarl_name} fell at {location_name}. {heir_name} took the chair.",
}

static func get_template(event_id: String) -> String:
	return templates.get(event_id, "{jarl_name} — something happened that the skald did not record.")

static func fill_template(event_id: String, variables: Dictionary) -> String:
	var template = get_template(event_id)
	return template.format(variables)
