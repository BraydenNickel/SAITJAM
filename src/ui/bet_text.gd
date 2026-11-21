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
	&"mvp": "Your pick deals the most damage (win or lose).",
}
## Why a claim cannot be bet on (see BetOdds.claim_possible).
const IMPOSSIBLE_REASONS: Dictionary = {
	&"last_stand": "Needs 2+ monsters placed (with 1 it is just Victory).",
}

## Odds word thresholds (presentation only; the payout comes from BetOdds).
const LIKELY_MIN: float = 0.65
const EVEN_MIN: float = 0.35
const RISKY_MIN: float = 0.10

const COLOR_LIKELY: Color = Color(0.55, 1, 0.45)
const COLOR_EVEN: Color = Color(1, 0.85, 0.3)
const COLOR_RISKY: Color = Color(1, 0.55, 0.25)
const COLOR_LONGSHOT: Color = Color(1, 0.4, 0.6)

## Display name of `claim` (falls back to the id).
static func name_of(claim: StringName) -> String:
	return NAMES.get(claim, String(claim)) as String

## Plain description of `claim`.
static func description_of(claim: StringName) -> String:
	if claim == &"blitz":
		return "Win in under %d seconds." % roundi(Tuning.BLITZ_TIME)
	return DESCRIPTIONS.get(claim, "") as String

## Short reason shown when `claim` is not possible with `placed_count` monsters.
static func impossible_reason(claim: StringName, placed_count: int) -> String:
	if placed_count <= 0:
		return "Place at least one monster first."
	return IMPOSSIBLE_REASONS.get(claim, "Not possible in this fight.") as String

## Odds as a word plus percent, e.g. "Likely 87%", "Risky 30%", "Longshot <1%".
static func odds_text(p: float) -> String:
	return "%s %s" % [odds_word(p), percent_text(p)]

## "Likely" / "Even" / "Risky" / "Longshot" for probability `p`.
static func odds_word(p: float) -> String:
	if p >= LIKELY_MIN:
		return "Likely"
	if p >= EVEN_MIN:
		return "Even"
	if p >= RISKY_MIN:
		return "Risky"
	return "Longshot"

## Colour matching odds_word(p).
static func odds_color(p: float) -> Color:
	if p >= LIKELY_MIN:
		return COLOR_LIKELY
	if p >= EVEN_MIN:
		return COLOR_EVEN
	if p >= RISKY_MIN:
		return COLOR_RISKY
	return COLOR_LONGSHOT

## Percent text; anything that rounds to 0% reads "<1%".
static func percent_text(p: float) -> String:
	var pct: int = roundi(p * 100.0)
	return "<1%" if pct <= 0 else "%d%%" % pct

## Net gold if a `stake` bet at `mult` wins (same rounding as battle settlement).
static func net_win(stake: int, mult: float) -> int:
	return roundi(stake * mult) - stake
