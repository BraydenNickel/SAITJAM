class_name MusicPlayer
extends AudioStreamPlayer
## Reusable music player on the "Music" bus, so the settings menu's Music
## slider controls it. Assign `stream` in the Inspector (no music ships yet).
## Autoplay is off; call play_music().

func _ready() -> void:
	bus = GameSettings.BUS_MUSIC

## Starts `track` (or the assigned stream when null). Does nothing if that
## track is already playing, so screens can call it on every _ready.
func play_music(track: AudioStream = null) -> void:
	var next: AudioStream = track if track != null else stream
	if next == null:
		return
	if playing and stream == next:
		return
	stream = next
	play()
