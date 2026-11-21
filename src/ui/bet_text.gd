class_name BetText
extends RefCounted
## Player-facing names and plain-language descriptions of the bet claims.

const NAMES: Dictionary = {
	&"victory": "Victory",
	&"flawless": "Flawless",
	&"blitz": "Blitz",
	&"last_stand": "Last Stand",
	&"mvp": "MVP",
}
const DESCRIPTIONS: Dictionary = {
	&"victory": "Win the battle.",
	&"flawless": "Win without losing a single monster.",
	&"blitz": "Win the battle fast.",
	&"last_stand": "Win with only one monster left standing.",
	&"mvp": "Your pick deals the most damage in the fight (win or lose).",
}

## Display name of `claim` (falls back to the id).
static func name_of(claim: StringName) -> String:
	return NAMES.get(claim, String(claim)) as String

## Plain description of `claim`.
static func description_of(claim: StringName) -> String:
	if claim == &"blitz":
		return "Win in under %d seconds." % roundi(Tuning.BLITZ_TIME)
	return DESCRIPTIONS.get(claim, "") as String
