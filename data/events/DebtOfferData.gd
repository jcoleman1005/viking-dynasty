class_name DebtOfferData
extends Resource

@export var creditor_name: String = ""
@export var creditor_renown: int = 0
@export var grain_amount: int = 0
@export var repayment_type: String = "" # "gold", "warband_service", "heir_hostage", "territorial"
@export var repayment_amount: int = 0
@export var repayment_deadline_years: int = 2
@export var repayment_due_year: int = 0
@export var offer_explanation: String = ""
@export var inherited: bool = false
