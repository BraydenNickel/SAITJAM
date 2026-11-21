extends Node2D
## QA harness: plays the saved arena with the intro on top, reports match_started, then quits.


func _ready() -> void:
	var intro := $Arena/ArenaIntro
	intro.match_started.connect(_on_match_started)


func _on_match_started() -> void:
	print("ARENA_INTRO: match_started at %.2fs" % (Time.get_ticks_msec() / 1000.0))
	var player: AudioStreamPlayer = $Arena/ArenaIntro/FightMusic
	var wav := player.stream as AudioStreamWAV
	print("ARENA_INTRO: music playing=%s pos=%.2fs length=%.2fs loop_mode=%d loop_end=%d" % [
		player.playing, player.get_playback_position(), wav.get_length(), wav.loop_mode, wav.loop_end])
	await get_tree().create_timer(0.5).timeout
	player.stop()
	player.stream = null
	await get_tree().process_frame
	get_tree().quit()
