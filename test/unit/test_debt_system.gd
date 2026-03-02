extends GutTest

var _original_jarl: JarlData
var _original_balance: EventBalanceData

func before_each() -> void:
	_original_jarl = DynastyManager.current_jarl
	_original_balance = EventManager.balance_data

	var jarl := JarlData.new()
	jarl.renown = 30
	jarl.diplomacy = 8
	jarl.charisma = 8
	DynastyManager.current_jarl = jarl

	var bd := EventBalanceData.new()
	bd.debt_trigger_threshold = 0.3
	bd.debt_inheritance_rate = 1.3
	EventManager.balance_data = bd

	DynastyManager.active_debt = null
	DynastyManager.debt_history = []
	DynastyManager.rival_threat_active = false
	DynastyManager.year_event_log = []

func after_each() -> void:
	DynastyManager.current_jarl = _original_jarl
	EventManager.balance_data = _original_balance
	DynastyManager.active_debt = null

func test_generate_offer_creates_valid_debt() -> void:
	DynastyManager._generate_debt_offer(50)
	assert_not_null(DynastyManager.active_debt,
		"Debt offer is created from deficit")

func test_offer_grain_amount_covers_deficit() -> void:
	DynastyManager._generate_debt_offer(50)
	var offer := DynastyManager.active_debt
	assert_true(offer.grain_amount >= 50,
		"Grain offered at least covers the deficit")

func test_offer_repayment_exceeds_grain_amount() -> void:
	DynastyManager._generate_debt_offer(50)
	var offer := DynastyManager.active_debt
	assert_true(offer.repayment_amount > offer.grain_amount,
		"Repayment includes interest on top of grain received")

func test_offer_has_explanation() -> void:
	DynastyManager._generate_debt_offer(40)
	assert_true(DynastyManager.active_debt.offer_explanation.length() > 0,
		"Creditor explanation text assembled")

func test_offer_sets_repayment_due_year() -> void:
	DynastyManager._generate_debt_offer(40)
	var offer := DynastyManager.active_debt
	assert_eq(offer.repayment_due_year, DynastyManager.current_year + offer.repayment_deadline_years,
		"repayment_due_year calculated from current year + deadline")

func test_no_second_debt_while_active() -> void:
	DynastyManager.active_debt = DebtOfferData.new()
	DynastyManager.active_debt.creditor_name = "Original Creditor"
	var original_offer := DynastyManager.active_debt
	DynastyManager._generate_debt_offer(50)
	assert_eq(DynastyManager.active_debt, original_offer,
		"Existing active debt is not overwritten by _generate_debt_offer")

func test_debt_inherited_on_succession() -> void:
	DynastyManager.active_debt = DebtOfferData.new()
	DynastyManager.active_debt.creditor_name = "Merchant-Jarl Sigurd"
	DynastyManager.active_debt.repayment_amount = 50
	DynastyManager._inherit_debt()
	assert_true(DynastyManager.active_debt.inherited,
		"Debt flagged as inherited after succession")

func test_inherited_debt_amount_increased() -> void:
	DynastyManager.active_debt = DebtOfferData.new()
	DynastyManager.active_debt.repayment_amount = 50
	DynastyManager._inherit_debt()
	assert_eq(DynastyManager.active_debt.repayment_amount, int(50 * 1.3),
		"Inherited debt repayment increased by debt_inheritance_rate")

func test_default_clears_active_debt() -> void:
	DynastyManager.active_debt = DebtOfferData.new()
	DynastyManager.active_debt.creditor_name = "Jarl Sigurd"
	DynastyManager.active_debt.repayment_amount = 60
	DynastyManager._process_debt_default()
	assert_null(DynastyManager.active_debt,
		"Active debt cleared on default")

func test_default_activates_rival_flag() -> void:
	DynastyManager.active_debt = DebtOfferData.new()
	DynastyManager.active_debt.creditor_name = "Jarl Sigurd"
	DynastyManager.active_debt.repayment_amount = 60
	DynastyManager._process_debt_default()
	assert_true(DynastyManager.rival_threat_active,
		"Rival threat activated after debt default")

func test_default_recorded_in_debt_history() -> void:
	DynastyManager.active_debt = DebtOfferData.new()
	DynastyManager.active_debt.creditor_name = "Trader Orm"
	DynastyManager.active_debt.repayment_amount = 80
	DynastyManager._process_debt_default()
	assert_eq(DynastyManager.debt_history.size(), 1,
		"Default appended to debt_history")

func test_deadline_auto_defaults_overdue_debt() -> void:
	DynastyManager.active_debt = DebtOfferData.new()
	DynastyManager.active_debt.creditor_name = "Trader Orm"
	DynastyManager.active_debt.repayment_amount = 60
	DynastyManager.active_debt.repayment_due_year = DynastyManager.current_year - 1
	DynastyManager._check_debt_repayment_deadline()
	assert_null(DynastyManager.active_debt,
		"Overdue debt auto-defaults via deadline check")

func test_deadline_does_not_default_before_due_year() -> void:
	DynastyManager.active_debt = DebtOfferData.new()
	DynastyManager.active_debt.creditor_name = "Trader Orm"
	DynastyManager.active_debt.repayment_amount = 60
	DynastyManager.active_debt.repayment_due_year = DynastyManager.current_year + 1
	DynastyManager._check_debt_repayment_deadline()
	assert_not_null(DynastyManager.active_debt,
		"Debt not cleared before due year")
