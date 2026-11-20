extends Node
## Monetisation seam. PROTOTYPE: everything is simulated.
## Later: replace the bodies with the AdMob plugin + Google Play Billing,
## without touching the game code (it only calls these functions).

signal no_ads_changed

const INTERSTITIAL_EVERY := 3  # levels between two interstitials

var _levels_since_interstitial := 0


## Called after a level is won, before going to the next one.
func on_level_completed() -> void:
	_levels_since_interstitial += 1
	if GameState.no_ads():
		return
	if _levels_since_interstitial >= INTERSTITIAL_EVERY:
		_levels_since_interstitial = 0
		_show_interstitial()


## Rewarded video: callback(true) if the player watched it to the end.
## Rewarded ads stay available even after "Remove ads" (player's choice).
func show_rewarded(callback: Callable) -> void:
	print("[Ads] rewarded video (simulated) -> reward granted")
	callback.call(true)


## "Remove ads" non-consumable purchase.
func purchase_remove_ads() -> void:
	print("[Billing] purchase remove_ads (simulated) -> success")
	GameState.set_no_ads(true)
	no_ads_changed.emit()


func _show_interstitial() -> void:
	print("[Ads] interstitial (simulated)")
