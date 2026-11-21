class_name FxLibrary
extends RefCounted
## The single lookup for visual effects (pixelfx sprite sheets) and sounds.
##
## Static, no autoload. Sheets are made by `node tools/export_fx.mjs`, sounds by
## `python tools/gen_sfx.py`; the keys here match the file names those two write.
## [codeblock]
## PixelFxPlayer.spawn(self, FxLibrary.event_fx(&"hit"), global_position)
## player.stream = FxLibrary.sfx(&"hit")
## [/codeblock]
## Ability and event sheets are one-shots that free themselves; aura sheets loop.

const FX_DIR: String = "res://assets/fx/"
const SFX_DIR: String = "res://assets/sfx/"

## Ability id (see AbilityData.get_id()) -> one-shot sheet played when the ability triggers.
const ABILITY_FX: Dictionary = {
	&"venom": FX_DIR + "ab_venom.json",
	&"dodge": FX_DIR + "ab_dodge.json",
	&"double_strike": FX_DIR + "ab_double_strike.json",
	&"lifesteal": FX_DIR + "ab_lifesteal.json",
	&"reflect": FX_DIR + "ab_reflect.json",
	&"spore_pulse": FX_DIR + "ab_spore_pulse.json",
	&"regen": FX_DIR + "ab_regen.json",
	&"mend": FX_DIR + "ab_mend.json",
	&"thorns": FX_DIR + "ab_thorns.json",
	&"shield": FX_DIR + "ab_shield.json",
	&"execute": FX_DIR + "ab_execute.json",
	&"cleave": FX_DIR + "ab_cleave.json",
	&"stun": FX_DIR + "ab_stun.json",
	&"rage": FX_DIR + "ab_rage.json",
	&"berserk": FX_DIR + "ab_berserk.json",
	&"war_cry": FX_DIR + "ab_war_cry.json",
	&"vengeance": FX_DIR + "ab_vengeance.json",
	&"snipe": FX_DIR + "ab_snipe.json",
	&"chill": FX_DIR + "ab_chill.json",
	&"corrode": FX_DIR + "ab_corrode.json",
	&"second_wind": FX_DIR + "ab_second_wind.json",
	&"ambush": FX_DIR + "ab_ambush.json",
	&"chain": FX_DIR + "ab_chain.json",
	&"momentum": FX_DIR + "ab_momentum.json",
	&"burn": FX_DIR + "ab_burn.json",
	&"titan": FX_DIR + "ab_titan.json",
	&"phase": FX_DIR + "ab_phase.json",
	&"swarm": FX_DIR + "ab_swarm.json",
}

## Game event -> one-shot sheet.
const EVENT_FX: Dictionary = {
	&"hit": FX_DIR + "hit.json",
	&"crit": FX_DIR + "crit.json",
	&"death": FX_DIR + "death.json",
	&"heal": FX_DIR + "heal.json",
	&"dodge": FX_DIR + "dodge.json",
	&"frenzy": FX_DIR + "frenzy.json",
	&"win_small": FX_DIR + "win_small.json",
	&"win_medium": FX_DIR + "win_medium.json",
	&"win_big": FX_DIR + "win_big.json",
	&"coin": FX_DIR + "coin.json",
	&"purchase": FX_DIR + "purchase.json",
	&"mutate_success": FX_DIR + "mutate_success.json",
	&"mush": FX_DIR + "mush.json",
	&"ultra_reveal": FX_DIR + "ultra_reveal.json",
}

## Ultra body style -> looping sheet played behind the monster.
const AURA_FX: Dictionary = {
	&"crystal": FX_DIR + "aura_crystal.json",
	&"shadow": FX_DIR + "aura_shadow.json",
	&"molten": FX_DIR + "aura_molten.json",
	&"slime": FX_DIR + "aura_slime.json",
	&"gold": FX_DIR + "aura_gold.json",
	&"skeletal": FX_DIR + "aura_skeletal.json",
	&"void": FX_DIR + "aura_void.json",
	&"angelic": FX_DIR + "aura_angelic.json",
}

## Sound key -> wav. The event keys plus attack, click, ability and lose.
const SFX: Dictionary = {
	&"hit": SFX_DIR + "hit.wav",
	&"crit": SFX_DIR + "crit.wav",
	&"death": SFX_DIR + "death.wav",
	&"heal": SFX_DIR + "heal.wav",
	&"dodge": SFX_DIR + "dodge.wav",
	&"frenzy": SFX_DIR + "frenzy.wav",
	&"win_small": SFX_DIR + "win_small.wav",
	&"win_medium": SFX_DIR + "win_medium.wav",
	&"win_big": SFX_DIR + "win_big.wav",
	&"coin": SFX_DIR + "coin.wav",
	&"purchase": SFX_DIR + "purchase.wav",
	&"mutate_success": SFX_DIR + "mutate_success.wav",
	&"mush": SFX_DIR + "mush.wav",
	&"ultra_reveal": SFX_DIR + "ultra_reveal.wav",
	&"attack": SFX_DIR + "attack.wav",
	&"click": SFX_DIR + "click.wav",
	&"ability": SFX_DIR + "ability.wav",
	&"lose": SFX_DIR + "lose.wav",
}

## Loaded streams by key. A key whose file is missing is cached as null, so it is looked up once.
static var _sfx_cache: Dictionary = {}


## Sheet json for an ability id, or "" when the ability has no effect.
static func ability_fx(id: StringName) -> String:
	return String(ABILITY_FX.get(id, ""))


## Sheet json for a game event, or "" when the key is unknown.
static func event_fx(key: StringName) -> String:
	return String(EVENT_FX.get(key, ""))


## Looping sheet json for an ultra body style, or "" when the style has no aura.
static func aura_fx(style: StringName) -> String:
	return String(AURA_FX.get(style, ""))


## The sound for a key, loaded once and cached. Returns null, without an error, when the key is
## unknown or its file is missing.
static func sfx(key: StringName) -> AudioStream:
	if _sfx_cache.has(key):
		return _sfx_cache[key] as AudioStream
	var stream: AudioStream = null
	var path: String = String(SFX.get(key, ""))
	if not path.is_empty() and ResourceLoader.exists(path):
		stream = load(path) as AudioStream
	_sfx_cache[key] = stream
	return stream
