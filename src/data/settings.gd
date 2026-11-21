class_name GameSettings
extends RefCounted
## Player settings (audio volumes) stored in user://settings.cfg.
## Volumes are linear 0..1 per audio bus (see res://default_bus_layout.tres).
## Game calls load_settings() + apply() once at startup; the settings menu
## calls set_volume() live and save_settings() when it closes.

## Where settings are saved.
const PATH: String = "user://settings.cfg"
const SECTION: String = "audio"
## Bus names, in the order the settings menu shows them.
const BUS_MASTER: StringName = &"Master"
const BUS_MUSIC: StringName = &"Music"
const BUS_SFX: StringName = &"SFX"
const BUSES: Array[StringName] = [BUS_MASTER, BUS_MUSIC, BUS_SFX]
## Volume used when no settings file exists yet.
const DEFAULT_VOLUME: float = 1.0

## Bus name -> linear volume 0..1.
static var _volumes: Dictionary = {}

## Linear volume (0..1) of `bus`.
static func get_volume(bus: StringName) -> float:
	return float(_volumes.get(bus, DEFAULT_VOLUME))

## Sets the linear volume (clamped to 0..1) of `bus` and applies it at once.
static func set_volume(bus: StringName, linear: float) -> void:
	_volumes[bus] = clampf(linear, 0.0, 1.0)
	_apply_bus(bus)

## Loads volumes from `path`; missing keys or a missing file keep the default.
static func load_settings(path: String = PATH) -> void:
	var cfg: ConfigFile = ConfigFile.new()
	var err: Error = cfg.load(path)
	for bus: StringName in BUSES:
		var v: float = DEFAULT_VOLUME
		if err == OK:
			v = float(cfg.get_value(SECTION, String(bus), DEFAULT_VOLUME))
		_volumes[bus] = clampf(v, 0.0, 1.0)

## Saves the current volumes to `path`. Returns the ConfigFile error code.
static func save_settings(path: String = PATH) -> Error:
	var cfg: ConfigFile = ConfigFile.new()
	for bus: StringName in BUSES:
		cfg.set_value(SECTION, String(bus), get_volume(bus))
	return cfg.save(path)

## Pushes every stored volume to the AudioServer (0 mutes the bus).
static func apply() -> void:
	for bus: StringName in BUSES:
		_apply_bus(bus)

static func _apply_bus(bus: StringName) -> void:
	var idx: int = AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	var v: float = get_volume(bus)
	AudioServer.set_bus_mute(idx, v <= 0.0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))
