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


func current() -> String:
	return TranslationServer.get_locale().substr(0, 2)


func toggle() -> void:
	var next := "en" if current() == "fr" else "fr"
	TranslationServer.set_locale(next)
	GameState.set_locale(next)
	locale_changed.emit()
