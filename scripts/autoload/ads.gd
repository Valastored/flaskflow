extends Node
## Monetisation: AdMob ads (interstitial + rewarded, with GDPR consent via UMP)
## and Google Play Billing ("remove_ads" one-time purchase).
##
## On Android with the plugins exported, everything is real.
## In the editor / on desktop, the plugins are absent: ads and purchase are
## SIMULATED so the game stays testable (the reward is granted immediately).
##
## The game only calls: on_level_completed(), show_rewarded(cb),
## purchase_remove_ads(), restore_purchases(), remove_ads_price().

signal no_ads_changed
## Short message for the player (toast), e.g. "No ad available, try again".
signal notice(text: String)

# ---------------------------------------------------------------- configuration
## false = Google TEST ads (always use this while developing!).
## true  = your real ad units below. Must match is_real in
##         addons/AdmobPlugin/android_export.cfg.
const USE_REAL_ADS := false
const REAL_INTERSTITIAL_ID := "ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX"
const REAL_REWARDED_ID := "ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX"

## Product ID created in Play Console (Monetize > Products > In-app products).
const REMOVE_ADS_PRODUCT := "remove_ads"

const INTERSTITIAL_EVERY := 3  # levels between two interstitials
const ADMOB_SINGLETON := "AdmobPlugin"
const BILLING_SINGLETON := "GodotGooglePlayBilling"

# Billing constants (mirror BillingClient enums, kept numeric on purpose).
const RC_OK := 0
const RC_USER_CANCELED := 1
const RC_ITEM_ALREADY_OWNED := 7
const STATE_PURCHASED := 1
const STATE_PENDING := 2

var _levels_since_interstitial := 0

var _admob: Admob
var _ads_can_load := false  # true once consent is resolved
var _reward_callback: Callable
var _reward_earned := false
var _retry_delay := 2.0

var _billing: BillingClient
var _price := ""  # localised price from Google Play, e.g. "2,99 €"


func _ready() -> void:
	if Engine.has_singleton(ADMOB_SINGLETON):
		_setup_admob()
	if Engine.has_singleton(BILLING_SINGLETON):
		_setup_billing()


func is_simulated() -> bool:
	return _admob == null


# ================================================================ ADMOB

func _setup_admob() -> void:
	_admob = Admob.new()
	_admob.is_real = USE_REAL_ADS
	if USE_REAL_ADS:
		_admob.android_real_interstitial_id = REAL_INTERSTITIAL_ID
		_admob.android_real_rewarded_id = REAL_REWARDED_ID
	# max_ad_content_rating defaults to G (family-friendly ads only).
	_admob.initialization_completed.connect(_on_admob_initialized)
	_admob.consent_info_updated.connect(_on_consent_info_updated)
	_admob.consent_info_update_failed.connect(func(_e): _start_loading_ads())
	_admob.consent_form_loaded.connect(func(): _admob.show_consent_form())
	_admob.consent_form_failed_to_load.connect(func(_e): _start_loading_ads())
	_admob.consent_form_dismissed.connect(func(_e): _process_consent())
	_admob.interstitial_ad_failed_to_load.connect(func(_i, _e): _retry(_load_interstitial))
	_admob.interstitial_ad_dismissed_full_screen_content.connect(
		func(_i): _load_interstitial())
	_admob.rewarded_ad_failed_to_load.connect(func(_i, _e): _retry(_load_rewarded))
	_admob.rewarded_ad_user_earned_reward.connect(func(_i, _r): _reward_earned = true)
	_admob.rewarded_ad_dismissed_full_screen_content.connect(_on_rewarded_closed)
	_admob.rewarded_ad_failed_to_show_full_screen_content.connect(
		func(_i, _e): _finish_reward(false))
	add_child(_admob)
	_admob.initialize()


func _on_admob_initialized(_status) -> void:
	_process_consent()


## GDPR (EU) consent through Google's UMP form, before loading any ad.
func _process_consent() -> void:
	var consent: UserConsent = _admob.get_consent_status()
	if consent == null:
		_start_loading_ads()
		return
	match consent.status:
		UserConsent.Status.UNKNOWN:
			_admob.update_consent_info()
		UserConsent.Status.REQUIRED:
			_admob.load_consent_form()
		_:
			# NOT_REQUIRED or OBTAINED (the user's choice is applied by the SDK).
			_start_loading_ads()


func _on_consent_info_updated() -> void:
	var consent: UserConsent = _admob.get_consent_status()
	if consent != null and consent.status == UserConsent.Status.UNKNOWN:
		_start_loading_ads()  # avoid looping
	else:
		_process_consent()


func _start_loading_ads() -> void:
	if _ads_can_load:
		return
	_ads_can_load = true
	if not GameState.no_ads():
		_load_interstitial()
	_load_rewarded()


func _load_interstitial() -> void:
	if _admob and _ads_can_load and not GameState.no_ads():
		_admob.load_interstitial_ad()


func _load_rewarded() -> void:
	if _admob and _ads_can_load:
		_admob.load_rewarded_ad()


func _retry(loader: Callable) -> void:
	# Exponential back-off, as recommended by Google (max ~1 min).
	get_tree().create_timer(_retry_delay).timeout.connect(loader)
	_retry_delay = minf(_retry_delay * 2.0, 64.0)


## Called after a level is won, before going to the next one.
func on_level_completed() -> void:
	_levels_since_interstitial += 1
	if GameState.no_ads():
		return
	if _levels_since_interstitial < INTERSTITIAL_EVERY:
		return
	if _admob == null:
		_levels_since_interstitial = 0
		print("[Ads] interstitial (simulated)")
	elif _admob.is_interstitial_ad_loaded():
		_levels_since_interstitial = 0
		_retry_delay = 2.0
		_admob.show_interstitial_ad()
	# Not loaded yet: try again after the next level, never block the player.


## Rewarded video: callback(true) if the player watched it to the end.
## Stays available after "Remove ads" because the player chooses to watch it.
func show_rewarded(callback: Callable) -> void:
	if _admob == null:
		print("[Ads] rewarded video (simulated) -> reward granted")
		callback.call(true)
		return
	if not _admob.is_rewarded_ad_loaded():
		notice.emit(tr("AD_UNAVAILABLE"))
		_load_rewarded()
		callback.call(false)
		return
	_reward_callback = callback
	_reward_earned = false
	_admob.show_rewarded_ad()


func is_rewarded_ready() -> bool:
	return _admob == null or _admob.is_rewarded_ad_loaded()


func _on_rewarded_closed(_info) -> void:
	_finish_reward(_reward_earned)
	_retry_delay = 2.0
	_load_rewarded()


func _finish_reward(ok: bool) -> void:
	if _reward_callback.is_valid():
		var cb := _reward_callback
		_reward_callback = Callable()
		# Let the game resume (ad activity closed) before applying the reward.
		cb.call_deferred(ok)


# ================================================================ BILLING

func _setup_billing() -> void:
	_billing = BillingClient.new()
	add_child(_billing)
	_billing.connected.connect(_on_billing_connected)
	_billing.connect_error.connect(func(code, msg): print("[Billing] connect error ", code, " ", msg))
	_billing.query_product_details_response.connect(_on_product_details)
	_billing.query_purchases_response.connect(_on_purchases_query)
	_billing.on_purchase_updated.connect(_on_purchase_updated)
	_billing.acknowledge_purchase_response.connect(_on_acknowledged)
	_billing.start_connection()


func _on_billing_connected() -> void:
	_billing.query_product_details([REMOVE_ADS_PRODUCT], BillingClient.ProductType.INAPP)
	# Restores the purchase automatically (new phone, reinstall...).
	_billing.query_purchases(BillingClient.ProductType.INAPP)


func _on_product_details(result: Dictionary) -> void:
	if int(result.get("response_code", -1)) != RC_OK:
		return
	for p in result.get("product_details", []):
		if p.get("product_id", "") == REMOVE_ADS_PRODUCT:
			var offers = p.get("one_time_purchase_offer_details_list")
			if offers is Array and not offers.is_empty():
				_price = str(offers[0].get("formatted_price", ""))
				no_ads_changed.emit()


## Localised price ("2,99 €"), or "" if unknown (simulation / not loaded yet).
func remove_ads_price() -> String:
	return _price


func purchase_remove_ads() -> void:
	if GameState.no_ads():
		return
	if _billing == null:
		print("[Billing] purchase remove_ads (simulated) -> success")
		_grant_no_ads()
		return
	if not _billing.is_ready():
		notice.emit(tr("STORE_UNAVAILABLE"))
		_billing.start_connection()
		return
	var res: Dictionary = _billing.purchase(REMOVE_ADS_PRODUCT)
	if int(res.get("response_code", -1)) != RC_OK:
		notice.emit(tr("STORE_UNAVAILABLE"))


func restore_purchases() -> void:
	if _billing == null:
		notice.emit(tr("RESTORE_DONE"))
		return
	if _billing.is_ready():
		_billing.query_purchases(BillingClient.ProductType.INAPP)
		notice.emit(tr("RESTORE_DONE"))
	else:
		_billing.start_connection()


func _on_purchase_updated(result: Dictionary) -> void:
	var code := int(result.get("response_code", -1))
	if code == RC_OK:
		for purchase in result.get("purchases", []):
			_process_purchase(purchase)
	elif code == RC_ITEM_ALREADY_OWNED:
		_billing.query_purchases(BillingClient.ProductType.INAPP)
	elif code != RC_USER_CANCELED:
		notice.emit(tr("STORE_UNAVAILABLE"))


func _on_purchases_query(result: Dictionary) -> void:
	if int(result.get("response_code", -1)) != RC_OK:
		return
	for purchase in result.get("purchases", []):
		_process_purchase(purchase)


func _process_purchase(purchase: Dictionary) -> void:
	if not REMOVE_ADS_PRODUCT in purchase.get("product_ids", []):
		return
	var state := int(purchase.get("purchase_state", 0))
	if state == STATE_PENDING:
		notice.emit(tr("PURCHASE_PENDING"))
		return
	if state != STATE_PURCHASED:
		return
	# Google refunds the purchase if it isn't acknowledged within 3 days.
	if not bool(purchase.get("is_acknowledged", false)):
		_billing.acknowledge_purchase(str(purchase.get("purchase_token", "")))
	_grant_no_ads()


func _on_acknowledged(result: Dictionary) -> void:
	if int(result.get("response_code", -1)) != RC_OK:
		# Will be retried at next launch through query_purchases.
		print("[Billing] acknowledge failed: ", result)


func _grant_no_ads() -> void:
	if GameState.no_ads():
		return
	GameState.set_no_ads(true)
	notice.emit(tr("ADS_REMOVED"))
	no_ads_changed.emit()
