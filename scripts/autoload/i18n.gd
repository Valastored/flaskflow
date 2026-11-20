extends Node
## FR / EN texts. Use tr("KEY") anywhere. Add a language = add a dictionary.

signal locale_changed

const SUPPORTED := ["fr", "en"]

const STRINGS := {
	"en": {
		"PLAY": "Play",
		"CONTINUE": "Level %d",
		"LEVELS": "Levels",
		"LEVEL_N": "Level %d",
		"MOVES": "Moves %d / %d",
		"GOAL": "3 stars: %d moves",
		"UNDO": "Undo (%d)",
		"UNDO_AD": "Undo +3 (ad)",
		"RESTART": "Restart",
		"BACK": "Back",
		"WIN": "Well done!",
		"WIN_MOVES": "Solved in %d moves",
		"LOSE": "Out of moves!",
		"STUCK": "No moves left!",
		"NEXT": "Next",
		"REPLAY": "Replay",
		"MORE_MOVES": "+5 moves (ad)",
		"TOTAL_STARS": "%d / %d stars",
		"LANGUAGE": "Français",
		"REMOVE_ADS": "Remove ads",
		"ADS_REMOVED": "Ads removed",
		"ALL_DONE": "You finished every level!",
		"SUBTITLE": "Sort the colours. Fewer moves, more stars.",
		"EVENTS": "Events",
		"DAILY": "Daily reward",
		"DAILY_HINT": "Come back every day: the rewards grow!",
		"DAY_N": "Day %d",
		"CLAIM": "Claim",
		"CLAIMED": "Claimed",
		"COME_BACK": "Come back tomorrow",
		"MISSIONS": "Daily missions",
		"M_win": "Win %d levels",
		"M_stars": "Earn %d stars",
		"M_perfect": "3 stars without using undo",
		"CHEST": "Star chest",
		"CHEST_HINT": "A chest every %d stars",
		"STARS_PROGRESS": "%d / %d stars",
		"ITEM_tube": "+1 tube",
		"ITEM_undo": "+3 undos",
		"INVENTORY": "Your power-ups",
		"TUBE_BTN": "+1 tube (%d)",
		"TUBE_AD": "+1 tube (ad)",
		"TUBE_USED": "+1 tube used",
		"UNDO_ITEM": "Undo +3 (%d)",
		"REWARD": "Reward: %s",
	},
	"fr": {
		"PLAY": "Jouer",
		"CONTINUE": "Niveau %d",
		"LEVELS": "Niveaux",
		"LEVEL_N": "Niveau %d",
		"MOVES": "Coups %d / %d",
		"GOAL": "3 étoiles : %d coups",
		"UNDO": "Annuler (%d)",
		"UNDO_AD": "Annuler +3 (pub)",
		"RESTART": "Recommencer",
		"BACK": "Retour",
		"WIN": "Bravo !",
		"WIN_MOVES": "Réussi en %d coups",
		"LOSE": "Plus de coups !",
		"STUCK": "Plus aucun coup possible !",
		"NEXT": "Suivant",
		"REPLAY": "Rejouer",
		"MORE_MOVES": "+5 coups (pub)",
		"TOTAL_STARS": "%d / %d étoiles",
		"LANGUAGE": "English",
		"REMOVE_ADS": "Supprimer les pubs",
		"ADS_REMOVED": "Pubs supprimées",
		"ALL_DONE": "Tu as fini tous les niveaux !",
		"SUBTITLE": "Trie les couleurs. Moins de coups, plus d'étoiles.",
		"EVENTS": "Événements",
		"DAILY": "Récompense quotidienne",
		"DAILY_HINT": "Reviens chaque jour : les récompenses augmentent !",
		"DAY_N": "Jour %d",
		"CLAIM": "Récupérer",
		"CLAIMED": "Récupéré",
		"COME_BACK": "Reviens demain",
		"MISSIONS": "Missions du jour",
		"M_win": "Gagner %d niveaux",
		"M_stars": "Gagner %d étoiles",
		"M_perfect": "3 étoiles sans annuler",
		"CHEST": "Coffre à étoiles",
		"CHEST_HINT": "Un coffre toutes les %d étoiles",
		"STARS_PROGRESS": "%d / %d étoiles",
		"ITEM_tube": "+1 tube",
		"ITEM_undo": "+3 annulations",
		"INVENTORY": "Tes power-ups",
		"TUBE_BTN": "+1 tube (%d)",
		"TUBE_AD": "+1 tube (pub)",
		"TUBE_USED": "+1 tube utilisé",
		"UNDO_ITEM": "Annuler +3 (%d)",
		"REWARD": "Récompense : %s",
	},
}


func _ready() -> void:
	for loc in STRINGS:
		var t := Translation.new()
		t.locale = loc
		var table: Dictionary = STRINGS[loc]
		for key in table:
			t.add_message(key, table[key])
		TranslationServer.add_translation(t)
	var saved: String = GameState.data.get("locale", "")
	if saved in SUPPORTED:
		TranslationServer.set_locale(saved)
	else:
		var device := OS.get_locale_language()
		TranslationServer.set_locale(device if device in SUPPORTED else "en")


## {"tube": 1, "undo": 2} -> "+1 tube, +2 x +3 undos"-style readable text.
func reward_text(reward: Dictionary) -> String:
	var parts: PackedStringArray = []
	for item in reward:
		var n := int(reward[item])
		var name := tr("ITEM_" + item)
		parts.append(name if n == 1 else "%d × %s" % [n, name])
	return ", ".join(parts)


func current() -> String:
	return TranslationServer.get_locale().substr(0, 2)


func toggle() -> void:
	var next := "en" if current() == "fr" else "fr"
	TranslationServer.set_locale(next)
	GameState.set_locale(next)
	locale_changed.emit()
