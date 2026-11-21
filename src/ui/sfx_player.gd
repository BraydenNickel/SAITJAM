class_name SfxPlayer
extends Node
## Small pool of AudioStreamPlayer voices for one-shot sounds.
##
## Instance `sfx_player.tscn` in any screen that needs sound, then:
## [codeblock]
## %Sfx.play(&"hit", Tuning.SFX_PITCH_JITTER)
## %Sfx.play_detached(&"click")  # right before a scene change
## [/codeblock]
## Keys are the ones in FxLibrary.SFX. The voices are the AudioStreamPlayer
## children of this node (add or remove them in the editor to resize the pool).
## Volume and the per-key rate limit come from Tuning.

var _voices: Array[AudioStreamPlayer] = []
## Sound key -> Time.get_ticks_msec() of its last play (real time, so the limit
## holds at any Engine.time_scale).
var _last_played: Dictionary = {}


func _ready() -> void:
	for child: Node in get_children():
		var voice: AudioStreamPlayer = child as AudioStreamPlayer
		if voice != null:
			voice.volume_db = Tuning.SFX_VOLUME_DB
			voice.bus = GameSettings.BUS_SFX  # player volume: settings menu
			_voices.append(voice)


## Plays the sound for `key` on a free voice. Does nothing when the key has no
## sound, when the same key played less than Tuning.SFX_MIN_INTERVAL seconds ago
## (real time) or when every voice is busy. `pitch_jitter` randomises the pitch
## by +/- that fraction.
func play(key: StringName, pitch_jitter: float = 0.0) -> void:
	var voice: AudioStreamPlayer = _claim_voice(key)
	if voice == null:
		return
	_start(voice, key, pitch_jitter)


## Like play(), but the sound survives this node being freed: the voice is moved
## to the scene tree root and frees itself when done. Use it for a click that
## triggers a scene change. The pool shrinks by one voice each call.
func play_detached(key: StringName) -> void:
	if not is_inside_tree():
		return
	var voice: AudioStreamPlayer = _claim_voice(key)
	if voice == null:
		return
	_voices.erase(voice)
	remove_child(voice)
	get_tree().root.add_child(voice)
	voice.finished.connect(voice.queue_free)
	_start(voice, key, 0.0)


## A free voice for `key`, or null when the key is unknown, rate-limited or the
## pool is busy. Records the play time.
func _claim_voice(key: StringName) -> AudioStreamPlayer:
	if FxLibrary.sfx(key) == null:
		return null
	var now: int = Time.get_ticks_msec()
	if _last_played.has(key) and now - int(_last_played[key]) < int(Tuning.SFX_MIN_INTERVAL * 1000.0):
		return null
	for voice: AudioStreamPlayer in _voices:
		if not voice.playing:
			_last_played[key] = now
			return voice
	return null


func _start(voice: AudioStreamPlayer, key: StringName, pitch_jitter: float) -> void:
	voice.stream = FxLibrary.sfx(key)
	voice.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter) if pitch_jitter > 0.0 else 1.0
	voice.play()
